#!/usr/bin/env python

"""Identify controls and extract corresponding sequences

"""

import sys
import argparse
import logging

import pandas as pd

log = logging

def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('sample_info')
    parser.add_argument('specimen_map')
    parser.add_argument('weights')

    parser.add_argument('--hits')
    parser.add_argument('--ref-info')

    parser.add_argument('--tallies',
                        help='csv file containing tallies seeds in each specimen')

    args = parser.parse_args(arguments)

    sample_info = pd.read_csv(args.sample_info)
    specimen_map = pd.read_csv(args.specimen_map, names=['seqname', 'specimen'])
    weights = pd.read_csv(args.weights, names=['seed', 'seqname', 'weight'],
                          dtype={'weight': int})

    tab = pd.merge(weights, specimen_map, on='seqname')
    tab = pd.merge(tab, sample_info, on='specimen')

    controls = tab[tab['controls'].notnull()].sort_values(by='weight', ascending=False)
    seeds = controls['seed'].drop_duplicates()

    in_controls = tab[tab['seed'].isin(controls['seed'])].copy()

    # M03100:75:000000000-AJ8KR:1:1101:8291:2175:154
    tallies = pd.pivot_table(in_controls,
                             values='weight', index='seed', columns='specimen')
    # add a column for merging with blast hits
    tallies['seed'] = tallies.index

    if args.hits and args.ref_info:
        hits = pd.read_csv(args.hits)
        ref_info = pd.read_csv(args.ref_info, dtype={'tax_id': str})
        blast = pd.merge(hits[['query', 'target', 'pct_id']],
                         ref_info[['seqname', 'description']],
                         left_on='target', right_on='seqname', how='left',
                         sort=False)

        blast.drop(['seqname'], axis=1, inplace=True)
        tab = pd.merge(blast, tallies, left_on='query', right_on='seed',
                       how='right', sort=False)

    tab['seed'] = tab['seed'].astype('category', categories=seeds, ordered=True)
    tab.sort_values(by='seed', inplace=True)
    tab.drop(['seed'], axis=1, inplace=True)

    if args.tallies:
        tab.to_csv(args.tallies, float_format='%.0f', index=False)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

