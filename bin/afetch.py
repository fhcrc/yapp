#!/usr/bin/env python3
import argparse
from fastalite import fastalite
import sys


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        'ali', type=argparse.FileType('r'), help="Input fasta alignment")
    parser.add_argument(
        'names', type=argparse.FileType('r'), help="sequence names text file")
    parser.add_argument(
        '--out',
        default=sys.stdout,
        metavar='FILE',
        type=argparse.FileType('w'))
    args = parser.parse_args(arguments)
    gapped = []
    names = (n.strip() for n in args.names)
    names = set(n for n in names if n)
    ali = (f for f in fastalite(args.ali) if f.id in names)
    for f in ali:
        if not gapped:
            gapped = [True] * len(f.seq)
        for i, b in enumerate(f.seq):
            if b != '-':
                gapped[i] = False
    args.ali.seek(0)
    ali = (f for f in fastalite(args.ali) if f.id in names)
    for f in ali:
        seq = (b for i, b in enumerate(f.seq) if not gapped[i])
        args.out.write('>{}\n{}\n'.format(f.description, ''.join(seq)))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
