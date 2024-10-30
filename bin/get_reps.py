#!/usr/bin/env python3

"""Extract and annotate selected reference sequences and SVs

Example:

bin/get_reps.py \
    manhart-2018-06-21-1.0.refpkg \
    output/sv_table_long.csv \
    output/merged.fasta \
    --sv-pattern Haemophilus \
    --aln $out/aln-cmalign.fasta \
    --names $out/names.csv \
    --seqs $out/seqs.fasta

"""

import argparse
import logging
import csv
import sys
import re
from operator import itemgetter
from itertools import groupby

from taxtastic.refpkg import Refpkg

from fastalite import Opener, fastalite

log = logging.getLogger(__name__)


def safename(text):
    return '_'.join([e for e in re.split(r'[^a-zA-Z0-9]', text) if e])


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('refpkg')
    parser.add_argument('sv_table_long', type=Opener())
    parser.add_argument('merged_aln', type=Opener())

    # outputs
    parser.add_argument('--seqs', type=Opener('w'),
                        help='fasta file containing unaligned sequences')
    parser.add_argument('--aln', type=Opener('w'),
                        help='fasta file containing aligned sequences',
                        default=sys.stdout)
    parser.add_argument('-n', '--names', type=Opener('w'),
                        help='csv file mapping original to annotated names')

    # patterns
    parser.add_argument('--sv-pattern',
                        help=('regular expression for matching taxonomic names'
                              'of classifications'))
    parser.add_argument('--ref-pattern',
                        help=('regular expression for matching species names'
                              'of ref sequences (use --sv-pattern if missing)'))
    parser.add_argument('--rm-pattern',
                        help='remove sequences with names matching this pattern')

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    rp = Refpkg(args.refpkg)
    seq_info_lines = list(csv.DictReader(rp.open_resource('seq_info')))
    seq_info = {d['seqname']: d for d in seq_info_lines}
    taxonomy = {d['tax_id']: d for d in csv.DictReader(rp.open_resource('taxonomy'))}
    seqs = {seq.id: seq for seq in fastalite(args.merged_aln)}

    rm_pattern = re.compile(r'' + args.rm_pattern) if args.rm_pattern else None

    # identify reference sequences with species names matching a pattern
    ref_pattern = re.compile(r'' + (args.ref_pattern or args.sv_pattern))

    for line in seq_info_lines:
        if not line['species']:
            continue

        species_name = taxonomy[line['species']]['tax_name']
        seqname = line['seqname']

        if not ref_pattern.search(species_name):
            continue

        if rm_pattern and rm_pattern.search(seqname):
            continue

        annotation = '{seqname}|{organism}'.format(**line)
        if line['is_type'] == 'True':
            annotation += '|type'

        seq = seqs[seqname]
        if args.names:
            args.names.write('{},{}\n'.format(seq.id, annotation))
        if args.seqs:
            args.seqs.write('>{}\n{}\n'.format(seq.id, seq.seq.replace('-', '')))
        if args.aln:
            args.aln.write('>{}\n{}\n'.format(seq.id, seq.seq))

    sv_pattern = re.compile(r'' + args.sv_pattern)
    getter = itemgetter('name', 'tax_name')
    sv_table = csv.DictReader(args.sv_table_long)
    for (seqname, tax_name), grp in groupby(sv_table, getter):
        if rm_pattern and rm_pattern.search(seqname):
            continue

        if sv_pattern.search(tax_name):
            nreads = sum(int(row['read_count']) for row in grp)
            annotation = '{}|{}|{}'.format(seqname.split(':')[0], safename(tax_name), nreads)
            seq = seqs[seqname]
            if args.names:
                args.names.write('{},{}\n'.format(seq.id, annotation))
            if args.seqs:
                args.seqs.write('>{}\n{}\n'.format(seq.id, seq.seq.replace('-', '')))
            if args.aln:
                args.aln.write('>{}\n{}\n'.format(seq.id, seq.seq))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
