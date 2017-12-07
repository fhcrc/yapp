#!/usr/bin/env python

"""Annotate a wide-format taxon table given some labels

"""

import argparse
import logging
import csv
import sys

log = logging.getLogger(__name__)


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('table', type=argparse.FileType('r'))
    parser.add_argument(
        'labels', type=argparse.FileType('r'),
        help=('csv file in which values in column "specimen" '
              'correspond to column labels in SV table'))
    parser.add_argument('-o', '--outfile', type=argparse.FileType('w'), default=sys.stdout)
    parser.add_argument(
        '--omit',
        help='omit labels in this column-delimited list of column names')
    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    table_reader = csv.DictReader(args.table)
    label_reader = csv.DictReader(args.labels)
    labels = {row['specimen']: row for row in label_reader}

    ignore = set(['specimen'] + (args.omit.split(',') if args.omit else []))

    writer = csv.DictWriter(args.outfile, fieldnames=table_reader.fieldnames)
    writer.writeheader()
    for label_name in label_reader.fieldnames:
        if label_name in ignore:
            continue

        row = {colname: labels.get(colname, {}).get(label_name)
               for colname in table_reader.fieldnames}
        row[table_reader.fieldnames[0]] = label_name
        writer.writerow(row)

    writer.writerows(table_reader)





if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
