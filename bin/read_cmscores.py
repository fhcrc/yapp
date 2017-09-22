#!/usr/bin/env python

"""Read cmalign alignment scores and provide a list of sequences with
a score below some threshold.

"""

from __future__ import print_function
import os
import sys
import argparse


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('infile', help="output of cmalign --sfile", type=argparse.FileType('r'))
    parser.add_argument('-o', '--outfile', help="Output file",
                        default=sys.stdout, type=argparse.FileType('w'))
    parser.add_argument('--min-bit-score', type=int, default=0,
                        help='minimum bit score [default %(default)s]')

    args = parser.parse_args(arguments)

    colnames = ['idx', 'seq_name', 'length', 'cm_from', 'cm_to', 'trunc', 'bit_sc', 'avg_pp',
                'band_calc', 'alignment', 'total', 'mem']

    lines = [dict(zip(colnames, line.split()))
             for line in args.infile if not line.startswith('#')]

    for line in lines:
        if float(line['bit_sc']) < args.min_bit_score:
            args.outfile.write('{seq_name}\n'.format(**line))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

