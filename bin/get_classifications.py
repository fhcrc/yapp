#!/usr/bin/env python

"""A simple python script template.

"""

from __future__ import print_function
import os
import sys
import argparse
import sqlite3
from itertools import groupby
from operator import itemgetter

# import pandas

def concat_name(taxnames, rank, sep='/'):
    """Heuristics for creating a sensible combination of species names."""
    splits = [x.split() for x in taxnames]

    if (rank == 'species'
            and all(len(x) > 1 for x in splits)
            and len(set(s[0] for s in splits)) == 1):
        name = '%s %s' % (splits[0][0],
                          sep.join(sorted('_'.join(s[1:]) for s in splits)))
    else:
        name = sep.join('_'.join(s) for s in splits)

    return name


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('placedb', help="output of 'guppy classify' (an sqlite3 database)")
    parser.add_argument('-r', '--rank', default='species',
                        help="desired rank of classification [%(species)s]")
    parser.add_argument('-o', '--outfile', help="Output file",
                        default=sys.stdout, type=argparse.FileType('w'))

    args = parser.parse_args(arguments)

    conn = sqlite3.connect(args.placedb)
    # conn.row_factory = dict_factory
    cur = conn.cursor()
    cmd = """
    select m.placement_id, m.name, m.tax_id, m.rank, m.likelihood,
           t.tax_name, r.rank_order
    from multiclass m
    join taxa t using(tax_id)
    join ranks r on t.rank = r.rank
    where want_rank = ?
    order by placement_id, name
    """

    cur.execute(cmd, (args.rank,))
    rows = cur.fetchall()

    # grouping depends on sort order in sql statement
    for (pid, name), grp in groupby(rows, itemgetter(0, 1)):
        __, __, tax_ids, ranks, likelihoods, tax_names, rank_orders = zip(*grp)
        assert len(set(ranks)) == 1

        row = dict(
            placement_id=pid,
            name=name,
            tax_id=','.join(tax_ids),
            tax_name=concat_name(sorted(set(tax_names)), ranks[0]),
            likelihood=sum(likelihoods),
        )

        print(row)

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

