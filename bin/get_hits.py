#!/usr/bin/env python

"""Extract an annotated table of hits and sequences for a given tax_id

"""

import argparse
import logging
import csv
import sys
import sqlite3
from itertools import ifilter, islice

from bioy_pkg.utils import Opener
from bioy_pkg.sequtils import fastalite

log = logging.getLogger(__name__)


def dict_factory(cursor, row):
    return {col[0]: row[i] for i, col in enumerate(cursor.description)}


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('tax_id', help='taxid of sequences to retrieve')
    parser.add_argument('--hits-db', help='sqlite database of classifications, '
                        'blast output and annotation')
    parser.add_argument('--seqs-in', type=Opener(),
                        help='combined annotation (csv)', default=sys.stdout)

    parser.add_argument('--hits', type=Opener('w'),
                        help='annotation (csv)', default=sys.stdout)
    parser.add_argument('--seqs-out', type=Opener('w'),
                        help='annotated sequences (csv)', default=sys.stdout)
    parser.add_argument('--max-hits', type=int,
                        help='maximum number of seqs to write')

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    conn = sqlite3.connect(args.hits_db)
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
    left join hits h on c.name = h.query
    left join ref_info i on h.target = i.seqname
    where c.tax_id = ?
    order by abundance desc
    """

    cur.execute(cmd, (args.tax_id,))
    fieldnames = [x[0] for x in cur.description]
    results = cur.fetchall()
    hits = {d['name']: d for d in results}

    writer = csv.DictWriter(args.hits, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(results)

    seqs = fastalite(args.seqs_in)
    for seq in islice(ifilter(lambda seq: seq.id in hits, seqs), args.max_hits):
        args.seqs_out.write('>{name}_{abundance}\n{seq}\n'.format(
            name=seq.id.replace(':', '.'),  # FastTree doesn't like colons
            abundance=hits[seq.id]['abundance'],
            seq=seq.seq))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
