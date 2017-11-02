#!/usr/bin/env python

"""Produce a table of classifications for each input sequence in the
output of guppy classify

"""

from __future__ import print_function
import sys
import argparse
import sqlite3
from operator import methodcaller

import pandas as pd


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
    inputs.add_argument('placedb', help="output of 'guppy classify' (an sqlite3 database)")

    outputs = parser.add_argument_group('output files')
    outputs.add_argument(
        '-c', '--classifications', default=sys.stdout,
        help="csv file describing classification of each input (default stdout)")

    parser.add_argument('-r', '--rank', default='species',
                        help="desired rank of classification [%(default)s]")

    args = parser.parse_args(arguments)

    cmd = """
    select m.placement_id, m.name, m.tax_id, m.rank, m.likelihood,
           t.tax_name, r.rank_order
    from multiclass m
    join taxa t using(tax_id)
    join ranks r on t.rank = r.rank
    where want_rank = ?
    order by placement_id, name, tax_name
    """

    with sqlite3.connect(args.placedb) as conn:
        classif = pd.read_sql_query(cmd, conn, params=(args.rank,))

    grouped = classif.groupby(['placement_id', 'name'])
    tab = grouped.apply(getgroup)
    columns = ['name', 'rank', 'tax_id', 'tax_name', 'likelihood', 'placement_id']
    tab[columns].sort_values('name').to_csv(args.classifications, index=False)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

