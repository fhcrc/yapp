#!/usr/bin/env python

"""Calculate a distance matrix from a sequence alignment using
FastTree, and optionally a transform into x, y coordinates using
multidimentional scaling.

"""

import sys
import argparse
import logging

import pandas as pd
from deenurp import outliers
from Bio import SeqIO

logging.basicConfig(
    file=sys.stdout,
    format='%(levelname)s %(module)s %(lineno)s %(message)s',
    level=logging.WARNING)

log = logging


def check_count(fname, count):
    with open(fname) as f:
        seqs = SeqIO.parse(f, 'fasta')
        for i, seq in enumerate(seqs, 1):
            if i == count:
                break
        if i < count:
            log.error('Error: {} contains '
                      'fewer than {} sequences'.format(fname, count))
            return 1


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('infile', help='Sequence alignment in fasta format')
    parser.add_argument('-d', '--distmat', help='output distance matrix')
    parser.add_argument('-m', '--mds-coords',
                        help='coordinates resulting from multidimensional scaling')
    parser.add_argument('-c', '--check-count', type=int, metavar='N',
                        help='exit with status 1 if there are fewer than N sequences')

    args = parser.parse_args(arguments)

    if args.check_count:
        check_count(args.infile, args.check_count)

    taxa, distmat = outliers.fasttree_dists(args.infile)

    if args.distmat:
        df = pd.DataFrame(distmat, index=taxa)
        df.to_csv(args.distmat, header=False)

    if args.mds_coords:
        coords = outliers.mds(distmat, taxa)
        coords.to_csv(args.mds_coords, index=False)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

