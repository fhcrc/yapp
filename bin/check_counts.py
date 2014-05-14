#!/usr/bin/env python

"""Confirm that read mass for each specimen as determined from
seq_info.csv is accounted for in by_specimen*.csv. Counts in seq_info
can be adjusted by values provided in --weights (a csv file with
columns (read_name,group_name,weight)

"""

import argparse
import logging
import csv
import sys
from collections import Counter, defaultdict

log = logging.getLogger(__name__)

def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('seq_info', type=argparse.FileType('r'))
    parser.add_argument('by_specimen', type=argparse.FileType('r'))
    parser.add_argument('--weights', type=argparse.FileType('r'),
                        help="optional weights file to adjust counts in seq_info")
    parser.add_argument('-o', '--output', type=argparse.FileType('w'),
                        default=sys.stdout)
    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)

    seq_info = csv.reader(args.seq_info)
    if args.weights:
        # column 2 (index 1) should correspond to names of sequences in seq_info
        weights = {row[1]: int(row[2]) for row in csv.reader(args.weights)}
        expected = defaultdict(int)
        for seqname, specimen in seq_info:
            expected[specimen] += weights[seqname]
    else:
        expected = Counter(specimen for seqname, specimen in seq_info)

    by_specimen = defaultdict(list)
    for row in csv.DictReader(args.by_specimen):
        by_specimen[row['specimen']].append(int(row['tally']))

    observed = {key: sum(vals) for key, vals in by_specimen.items()}

    # record outcome for comparison of keys here and for each specimen below
    status = [set(expected.keys()) == set(observed.keys())]

    writer = csv.writer(args.output)
    writer.writerow(['specimen', 'expected', 'observed', 'status'])
    for specimen in set(expected.keys() + observed.keys()):
        ex, ob = expected[specimen], observed.get(specimen, 0)
        status.append(ex == ob)
        writer.writerow([specimen, ex, ob, 'ok' if ex == ob else 'ERROR'])

    exit_status = 0 if all(status) else 1
    if exit_status:
        sys.stderr.write('Error: not all counts are as expected\n')

    return exit_status


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))


