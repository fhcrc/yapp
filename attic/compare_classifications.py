#!/usr/bin/env python
"""
Produce comparison of two classifications on a sequence by sequence basis
"""

import argparse
import logging
import sqlite3
import csv
import sys

log = logging.getLogger(__name__)


def compute_diffs(base_database, args):
    curs = base_database.cursor()
    curs.execute("ATTACH '{0}' as db1".format(args.db1))
    curs.execute("ATTACH '{0}' as db2".format(args.db2))
    query =  "SELECT "
    if args.specimen_map:
        query += "specimen, "
    query += """mc1.name,
                COALESCE(t1.tax_name, "unclassified") db1_tax_name,
                COALESCE(t2.tax_name, "unclassified") db2_tax_name,
                COALESCE(t1.rank, "unclassified") db1_tax_rank,
                COALESCE(t2.rank, "unclassified") db2_tax_rank,
                COALESCE(mc1.tax_id, "unclassified") db1_tax_id,
                COALESCE(mc2.tax_id, "unclassified") db2_tax_id
        FROM    db1.multiclass_concat mc1
                JOIN db2.multiclass_concat mc2 USING (name) """

    if args.specimen_map:
        query += "JOIN specimens USING (name) "

    query += """
                LEFT JOIN db1.taxa t1 ON mc1.tax_id = t1.tax_id
                LEFT JOIN db2.taxa t2 ON mc2.tax_id = t2.tax_id
        WHERE   mc1.want_rank = ?
                AND mc2.want_rank = ?
        """
    if args.different_only:
        query += "AND mc1.tax_id != mc2.tax_id"
    log.info('Executing query')
    curs.execute(query, (args.want_rank, args.want_rank))
    return curs


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('db1')
    parser.add_argument('db2')
    parser.add_argument('-r', '--want-rank', default="species")
    parser.add_argument('-n', '--names', help="column labels to identify db1 and db2 [%(default)s]",
                        default='db1,db2')
    parser.add_argument('-s', '--specimen-map', type=argparse.FileType('r'),
        help="Optional... we'll print specimen out if you specify this")
    parser.add_argument('-a', '--all-comps', action="store_false", dest="different_only", default=True,
        help="Print out classifications for all sequences, even if the same")
    parser.add_argument('output', type=argparse.FileType('w'))
    return parser.parse_args()


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args()

    database = sqlite3.connect(":memory:")
    # database.row_factory = lambda cursor, row: {col[0]: row[i]
    #                                             for i, col in enumerate(cursor.description)}

    if args.specimen_map:
        log.info('populating specimens table from specimen map')
        curs = database.cursor()
        curs.execute("CREATE TEMPORARY TABLE specimens (name, specimen, PRIMARY KEY (name, specimen))")
        with args.specimen_map:
            reader = csv.reader(args.specimen_map)
            curs.executemany("INSERT INTO specimens VALUES (?, ?)", reader)

    results = compute_diffs(database, args)

    # names = dict(zip(['db1', 'db2'], args.names.split(',')))
    # header = [h.format(**names) for h in ['comparison', 'sequence', '{db1}_tax_name', '{db2}_tax_name',
    #                                       '{db1}_rank', '{db2}_rank', '{db1}_tax_id', '{db2}_tax_id']]

    header = ['comparison', 'sequence', 'db1_tax_name', 'db2_tax_name',
              'db1_rank', 'db2_rank', 'db1_tax_id', 'db2_tax_id']
    if args.specimen_map:
        header.insert(1, 'specimen')

    output = csv.writer(args.output)
    output.writerow(header)
    output.writerows([args.names] + list(r) for r in results)

if __name__ == '__main__':
    main()


