#!/usr/bin/env python3

"""Create a list of seqtab files, optionally filtering by project

"""

from os import path, walk
import argparse
import logging
import csv
import sys
import re
from operator import itemgetter
from itertools import groupby
from glob import glob

log = logging.getLogger(__name__)

def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('infiles', nargs='+')
    parser.add_argument('--projects', nargs='*')

    parser.add_argument('-s', '--seqtabs', type=argparse.FileType('w'),
                        help='list of seqtab files, one per line')
    parser.add_argument('-i', '--sample-info', type=argparse.FileType('w'),
                        help='concatenated seq info files')

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    projects = set(args.projects) if args.projects else set()

    if args.sample_info:
        writer = csv.DictWriter(
            args.sample_info,
            fieldnames=['sampleid', 'sample_name', 'project', 'batch', 'controls'])
        writer.writeheader()

    for fname in args.infiles:
        outdir = path.dirname(path.abspath(fname))
        with open(fname) as f:
            reader = csv.DictReader(f)
            for row in reader:
                if projects and row['project'] not in projects:
                    continue
                seqtab = path.join(outdir, 'dada', row['sampleid'], 'seqtab.csv')
                assert path.exists(seqtab)

                if args.sample_info:
                    writer.writerow(row)
                if args.seqtabs:
                    args.seqtabs.write(seqtab + '\n')


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
