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
from itertools import groupby

import pandas as pd

pd.set_option('display.max_rows', 500)
pd.set_option('display.max_columns', 500)
pd.set_option('display.width', 1000)

from fastalite import Opener, fastalite

log = logging.getLogger(__name__)


def safename(text):
    return '_'.join([e for e in re.split(r'[^a-zA-Z0-9]+', text) if e])


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

    os.mkdir(args.outdir)

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

        ref_names[row['seqname']] = row['safename']

    # for each rank after species and up to genus, get all child
    # species for the corresponding list of reference seqs
    ranks = taxonomy_reader.fieldnames[taxonomy_reader.fieldnames.index('root'):]
    include_ranks = ranks[ranks.index('genus'):ranks.index('species')]
    taxonomy_rows.sort(key=itemgetter(*ranks))
    for rank in include_ranks:
        for tax_id, lineages in groupby(taxonomy_rows, key=itemgetter(rank)):
            child_species = {lineage['species'] for lineage in lineages} - {''}
            tax_reps[tax_id] = reduce(
                set.union, [set()] + [set(tax_reps[species]) for species in child_species])

    # get blast hits TODO: could probably consolidate the whole
    # process of creating hits.db and all_hits.csv into this script,
    # but or now, jus read and filter all_hits.csv
    hits = pd.read_csv(args.hits)

    # sv_table_long provides classification results for each SV
    sv_tab = pd.read_csv(args.sv_table_long)
    sv_groups = sv_tab.groupby(['name', 'rank', 'tax_name', 'tax_id'])
    # need to reset the multi-index to access 'tax_name' individually
    sv_sums = sv_groups.agg({'read_count': 'sum'}).reset_index().sort_values(
        ['tax_name', 'read_count'], ascending=[True, False])

    # names with additional annotation for renaming sequences in
    # alignments and trees
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

    Seq = namedtuple('Seq', ['id', 'seq'])
    seqs = {seq.id: Seq(ref_names[seq.id], seq.seq)
            for seq in fastalite(args.merged_aln)}

    # iterate over each classification and write outputs
    for (rank, tax_name, tax_id), tab in sv_sums.groupby(['rank', 'tax_name', 'tax_id']):
        if tax_id != '1313,257758,28037':
            continue

        # create an output directory
        outdir = os.path.join(args.outdir, rank, safename(tax_name))
        try:
            os.makedirs(outdir)
        except OSError:
            pass

        # hits for this set of SV's
        hits.loc[hits['classif_name'] == tax_name].to_csv(os.path.join(outdir, 'hits.csv'))

        # alignments for these SVs as well as relevant ref seqs
        refs = reduce(
            set.union,
            (set(tax_reps[t]) if t in tax_reps else set() for t in tax_id.split(',')))
        svs = set(tab['name'])

        # TODO: write seqs with ids in refs and svs. Ordering?

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
