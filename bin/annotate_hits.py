#!/usr/bin/env python

"""Annotate search results

"""

import argparse
import logging
import csv
import sys
import sqlite3
import subprocess
import re
from collections import defaultdict
from operator import itemgetter
from itertools import imap, ifilter, islice

import pandas as pd

log = logging.getLogger(__name__)


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('blastout')
    parser.add_argument('seq_info')
    parser.add_argument('-o', '--outfile', type=argparse.FileType('w'),
                        default=sys.stdout)
    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
    args = get_args(arguments)

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


    with open(args.seq_info) as f:
        reader = csv.DictReader(f)
        info_headers = reader.fieldnames[:]
        info = {r['seqname']: r for r in reader}

    out_headers = [
        'query',
        'target',
        'description',
        'tax_id',
        'pct_id',
        'aln_len',
        'mismatches',
        'gap_opens',
        'ambig_count',
        ]

    writer = csv.DictWriter(args.outfile, fieldnames=out_headers, extrasaction='ignore')
    writer.writeheader()

    with open(args.blastout) as f:
        reader = csv.DictReader(f, fieldnames=blast_headers, delimiter='\t')
        for row in reader:
            writer.writerow(dict(row, **info[row['target']]))

    # hits = pd.io.parsers.read_csv(
    #     args.blastout, header=None, names=headers, sep='\t')
    # hits.set_index('seqname', inplace=True)

    # info = pd.io.parsers.read_csv(args.seq_info)
    # info.set_index('seqname', inplace=True)

    # data = hits.join(info)
    # print data.head()

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
