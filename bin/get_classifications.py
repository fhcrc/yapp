#!/usr/bin/env python

"""Produce a table of classifications for each input sequence in the
output of guppy classify

"""

from __future__ import print_function
import sys
import argparse
import sqlite3
from operator import methodcaller
import csv


def dict_factory(cursor, row):
    d = {}
    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d


def concat_name(taxnames, rank, sep='/'):
    """Heuristics for creating a sensible combination of species names."""
    splits = [x.split() for x in taxnames]

    if (rank == 'species'
            and all(len(x) > 1 for x in splits)
            and len(set(s[0] for s in splits)) == 1):
        name = '%s %s' % (splits[0][0],
                          sep.join(sorted('_'.join(s[1:]) for s in splits)))
    else:
        name = sep.join(' '.join(s) for s in splits)

    return name


def getgroup(x):
    first = methodcaller('head', 1)
    out = x.agg({
        'placement_id': first,
        'name': first,
        'rank': first,
        'tax_id': lambda x: ','.join(x.tolist()),
        'likelihood': sum,
    })
    out['tax_name'] = concat_name(
        sorted(set(x['tax_name'].tolist())), x['rank'].tolist()[0])
    return out


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    inputs = parser.add_argument_group('input files')
    inputs.add_argument(
        'placedb', help="output of 'guppy classify' (an sqlite3 database)")

    outputs = parser.add_argument_group('output files')
    outputs.add_argument(
        '-c', '--classifications', default=sys.stdout, type=argparse.FileType('w'),
        help="csv file describing classification of each input (default stdout)")

    args = parser.parse_args(arguments)

    cmd = """
    select placement_id,
           name,
           m.want_rank,
           group_concat(distinct m.tax_id) as tax_id,
           m.rank,
           sum(m.likelihood) as likelihood,
           group_concat(t.tax_name, '^') as tax_name,
           r.rank_order
    from placement_names
    left join multiclass m using(placement_id, name)
    left join taxa t using(tax_id)
    left join ranks r on m.want_rank = r.rank
    group by placement_id, name, want_rank
    order by placement_id, rank_order, tax_name
    """

    fieldnames = ['name', 'want_rank', 'rank', 'tax_id', 'tax_name', 'likelihood']
    writer = csv.DictWriter(args.classifications, fieldnames, extrasaction='ignore')
    writer.writeheader()

    with sqlite3.connect(args.placedb) as conn:
        conn.row_factory = dict_factory
        cur = conn.cursor()
        cur.execute(cmd)
        for row in cur.fetchall():
            writer.writerow(row)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

