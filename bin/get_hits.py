#!/usr/bin/env python

"""Extract an annotated table of hits and sequences for a given tax_id

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

from bioy_pkg.utils import Opener
from bioy_pkg.sequtils import fastalite, fasta_tempfile

log = logging.getLogger(__name__)

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


def dict_factory(cursor, row):
    return {col[0]: row[i] for i, col in enumerate(cursor.description)}


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('tax_id', help='taxid of sequences to retrieve')
    parser.add_argument('--hits-db', help='sqlite database of classifications, '
                        'blast output and annotation')
    parser.add_argument('--hits', type=argparse.FileType('w'),
                        help='combined annotation (csv)', default=sys.stdout)

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    conn = sqlite3.connect(args.hits_db)
    # conn.row_factory = sqlite3.Row
    conn.row_factory = dict_factory

    cur = conn.cursor()

    cmd = """
    select
    c.name,
    c.abundance,
    c.tax_name as classif_name,
    c.rank,
    i.*,
    h.pct_id

    from classif c
    join hits h on c.name = h.query
    join ref_info i on h.target = i.seqname
    where c.tax_id = ?
    """

    cur.execute(cmd, (args.tax_id,))
    fieldnames = [x[0] for x in cur.description]

    writer = csv.DictWriter(args.hits, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(cur.fetchall())



if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
