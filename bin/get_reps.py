#!/usr/bin/env python

"""Extract and annotate selected reference sequences

"""

import argparse
import logging
import csv
import sys
import re
import sqlite3
import pprint

from taxtastic.refpkg import Refpkg

from bioy_pkg.utils import Opener
from bioy_pkg.sequtils import fastalite

log = logging.getLogger(__name__)


def dict_factory(cursor, row):
    return {col[0]: row[i] for i, col in enumerate(cursor.description)}


def get_hits(conn, tax_ids, min_mass=1, limit=None):
    """Returns fieldnames, rows. tax_ids is a list of string, each of
    which is a tax_id or comma-delimited list of tax_ids, eg ['123',
    '123,456']. An exact match will be performed on each element.

    """

    assert isinstance(tax_ids, list)

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
    where
    abundance >= ?
    and
    """

    cmd += ' or '.join(['c.tax_id = ?'] * len(tax_ids))
    cmd += ' order by abundance desc'

    args = [min_mass] + tax_ids

    if limit:
        cmd += ' limit ?'
        args.append(limit)

    cur.execute(cmd, tuple(args))
    fieldnames = [x[0] for x in cur.description]
    results = cur.fetchall()

    return fieldnames, results


def safename(text):
    return '_'.join([e for e in re.split(r'[^a-zA-Z0-9]', text) if e])


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('refpkg')
    parser.add_argument('hits_db', help='sqlite database of classifications, '
                        'blast output and annotation')
    parser.add_argument('merged_aln', type=Opener())
    parser.add_argument('--seqs', type=Opener('w'),
                        help='fasta file containing extracted sequences', default=sys.stdout)
    parser.add_argument('--hits', type=Opener('w'),
                        help='annotation (csv)')
    parser.add_argument('-n', '--names', type=Opener('w'),
                        help='csv file mapping original to annotated names')
    parser.add_argument('--rank', help='rank of tax_ids')
    parser.add_argument('--tax-id', nargs='+',
                        help=('comma-delimited list of taxids to extract; '
                              'may provide more than one, eg "--tax-id 1234 1234,5678"'))
    parser.add_argument('--min-mass', type=int, default=1,
                        help='include only reads with this minimum mass [%(default)s]')
    parser.add_argument('--limit', type=int, default=100,
                        help='maximum number of seqs to write [%(default)s]')

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    rp = Refpkg(args.refpkg)
    seq_info = {d['seqname']: d for d in csv.DictReader(rp.open_resource('seq_info'))}
    taxonomy = {d['tax_id']: d for d in csv.DictReader(rp.open_resource('taxonomy'))}

    conn = sqlite3.connect(args.hits_db)
    conn.row_factory = dict_factory

    fieldnames, rows = get_hits(conn, args.tax_id,
                                min_mass=args.min_mass, limit=args.limit)

    if args.hits:
        writer = csv.DictWriter(args.hits, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    hits = {d['name']: d for d in rows}
    seqs = fastalite(args.merged_aln)

    rank = args.rank
    # set of individual tax_ids
    tax_ids = reduce(set.union, map(set, (t.split(',') for t in args.tax_id)))

    if args.names:
        writer = csv.writer(args.names)

    for seq in seqs:
        keep, name, seqtype = None, None, None
        if seq.id in hits:
            keep = True
            name = '{id}|{abundance}|{classif_name}'.format(
                id=safename(seq.id),
                abundance=hits[seq.id]['abundance'],
                classif_name=safename(hits[seq.id]['classif_name']))
            seqtype = 'q'
        elif seq.id in seq_info:
            d = seq_info[seq.id]
            keep = taxonomy[d['tax_id']][rank] in tax_ids
            seqtype = 'r'

            name = '{safename}|{seqname}|{accession}|taxid{tax_id}'.format(
                safename=safename(d['description']), **d)

        if keep:
            args.seqs.write('>{}\n{}\n'.format(name, seq.seq.upper()))

        if name and args.names:
            writer.writerow([seqtype, seq.id, name])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
