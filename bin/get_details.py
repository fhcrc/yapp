#!/usr/bin/env python

"""Extract and annotate selected reference sequences

"""

import os
import argparse
import logging
import csv
import sys
import re
import sqlite3
import pprint
from functools import reduce
from collections import defaultdict, namedtuple
from operator import itemgetter
from itertools import groupby, islice
from multiprocessing import Pool

import pandas as pd

pd.set_option('display.max_rows', 500)
pd.set_option('display.max_columns', 500)
pd.set_option('display.width', 1000)

from fastalite import Opener, fastalite

log = logging.getLogger(__name__)
Seq = namedtuple('Seq', ['id', 'seq'])


def safename(text):
    return '_'.join([e for e in re.split(r'[^a-zA-Z0-9]+', text) if e])


def squeeze(seqs):
    """
    Remove gap columns from sequences in ``seqs``
    """
    df = pd.DataFrame.from_records([list(seq.seq) for seq in seqs])
    gapcols = df.apply(lambda col: set(col) == {'-'}, axis=0)
    df = df.loc[:, ~gapcols]
    for seq, seqstr in zip(seqs, df.apply(''.join, axis=1)):
        yield Seq(seq.id, seqstr)


def make_outputs(rank, tax_name, tax_id, sv_tab,
                 # invariant args
                 outdir, seqdict, hits, tax_reps):
    log.info('{} {}'.format(rank, tax_name))

    # create an output directory
    outdir = os.path.join(outdir, rank, safename(tax_name))
    try:
        os.makedirs(outdir)
    except OSError:
        pass

    # hits for this set of SV's
    hits.loc[hits['classif_name'] == tax_name].to_csv(
        os.path.join(outdir, 'hits.csv'))

    # alignments for these SVs as well as relevant ref seqs
    seqnames = (list(sv_tab['name']) +
                [name for t in tax_id.split(',') for name in tax_reps[t]])
    seqs = [seqdict[name] for name in seqnames]

    with open(os.path.join(outdir, 'aln.fasta'), 'w') as f:
        for seq in squeeze(seqs):
            f.write('>{seq.id}\n{seq.seq}\n'.format(seq=seq))

    return outdir


def get_args(arguments):
    parser = argparse.ArgumentParser()
    inputs = parser.add_argument_group('inputs')
    inputs.add_argument('sv_table_long')
    inputs.add_argument('--seq-info', type=Opener())
    inputs.add_argument('--taxonomy', type=Opener())
    inputs.add_argument('--hits', type=Opener())
    inputs.add_argument('--merged-aln', type=Opener())

    outputs = parser.add_argument_group('outputs')
    outputs.add_argument('-d', '--outdir', default='details',
                         help='name of output directory [%(default)s]')

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)

    try:
        os.makedirs(args.outdir)
    except OSError:
        pass

    # organize reference sequences
    taxonomy_reader = csv.DictReader(args.taxonomy)
    taxonomy_rows = list(taxonomy_reader)
    taxonomy = {d['tax_id']: d for d in taxonomy_rows}

    # seq_info returns a dict containing annotation for a single
    # reference sequence
    seq_info = {}

    # tax_reps will return a set of ref seqs given a tax_id for ranks
    # between genus and species
    tax_reps = defaultdict(list)

    # populate tax_reps[species_id] with a list of reference sequence
    # names
    ref_names = {}
    for row in csv.DictReader(args.seq_info):
        # get the species-level tax_name and tax_id
        tax_id = row['tax_id']
        species_id = taxonomy[tax_id]['species']
        species_name = taxonomy[species_id]['tax_name']
        row['safename'] = '{safename}|{seqname}|taxid_{tax_id}'.format(
            safename=safename(species_name), **row)
        seq_info[row['seqname']] = row
        tax_reps[species_id].append(row['seqname'])

        # original name --> annotated name
        ref_names[row['seqname']] = row['safename']

    # for each rank after species and up to genus, populate tax_reps
    # with child species for the corresponding list of reference seqs
    ranks = taxonomy_reader.fieldnames[taxonomy_reader.fieldnames.index('root'):]
    include_ranks = ranks[ranks.index('genus'):ranks.index('species')]
    taxonomy_rows.sort(key=itemgetter(*ranks))
    for rank in include_ranks:
        for tax_id, lineages in groupby(taxonomy_rows, key=itemgetter(rank)):
            child_species = {lineage['species'] for lineage in lineages} - {''}
            tax_reps[tax_id] = reduce(
                set.union, [set()] + [set(tax_reps[species])
                                      for species in child_species])

    # read blast hits TODO: could probably consolidate the whole
    # process of creating hits.db and all_hits.csv into this script,
    # but for now, just read and filter all_hits.csv
    hits = pd.read_csv(args.hits)

    # sv_table_long provides classification results for each SV
    sv_tab = pd.read_csv(args.sv_table_long)
    sv_groups = sv_tab.groupby(['name', 'rank', 'tax_name', 'tax_id'])
    # need to reset the multi-index to access 'tax_name' individually
    sv_sums = sv_groups.agg({'read_count': 'sum'}).reset_index().sort_values(
        ['tax_name', 'read_count'], ascending=[True, False])

    # extend ref_names with annotated names for SVs
    sv_names = dict(zip(
        sv_sums['name'],
        sv_sums.apply(
        lambda row: '{safename}|{name}|{read_count}'.format(
            name=row['name'],
            safename=safename(row.tax_name),
            read_count=row.read_count
        ), axis=1)
    ))
    ref_names.update(sv_names)

    # retrieve a Seq with annotated name using original name
    seqdict = {seq.id: Seq(ref_names[seq.id], seq.seq)
               for seq in fastalite(args.merged_aln)}

    with Pool(processes=20) as pool:
        # assemble arguments for each taxon
        argmap = ((rank, tax_name, tax_id, tab, args.outdir, seqdict, hits, tax_reps)
                  for (rank, tax_name, tax_id), tab
                  in sv_sums.groupby(['rank', 'tax_name', 'tax_id']))

        result = pool.starmap_async(make_outputs, islice(argmap, None))
        result.get()

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
