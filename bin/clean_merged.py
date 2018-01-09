#!/usr/bin/env python

"""Clean up output of esl-alimerge

"""

from __future__ import print_function
import sys
import argparse

from fastalite import fastalite, Opener


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    inputs = parser.add_argument_group('input files')
    inputs.add_argument('merged', type=Opener('r'))

    outputs = parser.add_argument_group('output files')
    outputs.add_argument(
        'cleaned', type=Opener('w'),
        help='filtered sequence alignment, including refs')

    args = parser.parse_args(arguments)

    seqs = fastalite(args.merged)
    for seq in seqs:
        args.cleaned.write('>{}\n{}\n'.format(
            seq.id, seq.seq.replace('.', '-').upper()))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
