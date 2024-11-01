#!/usr/bin/env python3

"""Reformat and filter output of esl-alimerge

"""

from __future__ import print_function
import sys
import argparse
import re

from fastalite import fastalite, Opener


def read_scores(fobj, min_bit_score=0):
    headers = """idx seq_name length cm_from cm_to trunc bit_sc avg_pp
    band_calc alignment total mem""".split()

    seq_name_ix = headers.index('seq_name')
    bit_sc_ix = headers.index('bit_sc')

    for line in fobj:
        if line.startswith('#') or not line.strip():
            continue
        vals = line.split()
        yield (vals[seq_name_ix], float(vals[bit_sc_ix]))


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    inputs = parser.add_argument_group('input files')
    inputs.add_argument('merged', type=Opener('r'))
    inputs.add_argument('scores', type=Opener('r'))

    outputs = parser.add_argument_group('output files')
    outputs.add_argument(
        '--filtered-aln', type=Opener('w'),
        help='filtered sequence alignment, including refs')
    outputs.add_argument(
        '--filtered', type=Opener('w'),
        help='filtered, unaligned query seqs without refs')

    parser.add_argument('--min-bit-score', default=0, type=float)

    args = parser.parse_args(arguments)

    q_scores = dict(read_scores(args.scores))
    seqs = fastalite(args.merged)
    for seq in seqs:
        # filter only query seqs
        if seq.id in q_scores:
            if q_scores[seq.id] < args.min_bit_score:
                print('removing {} bit score {}'.format(seq.id, q_scores[seq.id]))
                continue
            args.filtered.write('>{}\n{}\n'.format(
                seq.id, re.sub(r'[^A-Z]', '', seq.seq.upper())))

        args.filtered_aln.write('>{}\n{}\n'.format(
            seq.id, seq.seq.replace('.', '-').upper()))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
