#!/usr/bin/env python

"""Convert blast6out to csv with headers

"""

import argparse
import csv
import sys

from fastalite import Opener

blast_headers = [
    'query',
    'target',
    'pct_id',
    'aln_len',
    'mismatches',
    'gap_opens',
    'q_start',
    'q_end',
    't_start',
    't_end',
    'evalue',
    'bitscore',
]


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('blast6out', type=Opener(), help='blast output')
    parser.add_argument('-o', '--outfile', type=argparse.FileType('w'))

    return parser.parse_args(arguments)


def main(arguments):
    args = get_args(arguments)
    reader = csv.DictReader(args.blast6out, fieldnames=blast_headers, delimiter='\t')
    writer = csv.DictWriter(args.outfile, fieldnames=blast_headers)
    writer.writeheader()
    writer.writerows(reader)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
