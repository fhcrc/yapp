#!/usr/bin/env python

"""Rename lineages given input file with columns (tax_name, rank, new_tax_name, new_rank)

"""

from __future__ import print_function
import sys
import argparse
import csv
import json
import re
from collections import OrderedDict

def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('lineages', type=argparse.FileType('r'))
    parser.add_argument('to_rename', type=argparse.FileType('r'))
    parser.add_argument('--ref-lineages', type=argparse.FileType('r'))
    parser.add_argument('-o', '--outfile', help="Output file",
                        default=sys.stdout, type=argparse.FileType('w'))
    parser.add_argument('--logfile', help="document what was renamed",
                        type=argparse.FileType('w'))


    args = parser.parse_args(arguments)

    rename = {}
    for row in csv.DictReader(args.to_rename):
        tax_name, rank, new_tax_name, new_rank = [x.strip() for x in row.values()]
        old = (rank, tax_name)
        new = (new_rank, new_tax_name)
        rename[old] = new

    lineage_reader = csv.DictReader(args.lineages)
    lineages = list(lineage_reader)

    all_lineages = lineages[:]
    if args.ref_lineages:
        all_lineages.extend(list(csv.DictReader(args.ref_lineages)))

    # create a mapping from each (rank, tax_name) to a lineage
    # ending at 'rank'
    tax_names = {}
    for row in all_lineages:
        lineage = list(row.items())[1:]
        for i, (rank, tax_name) in enumerate(lineage):
            if tax_name:
                tax_names[(rank, tax_name)] = OrderedDict(lineage[:(i + 1)])

    # iterate over ranks to rename. If (new_rank, new_tax_name)
    # corresponds to an existing lineage, replace all lineages
    # corresponding to (rank, tax_name) with this one. Otherwise,
    # replace all instances of 'tax_name' using 'new_tax_name',
    # leaving the rest of the lineage as is.
    writer = csv.DictWriter(
        args.outfile, fieldnames=lineage_reader.fieldnames, extrasaction='ignore')
    writer.writeheader()

    if args.logfile:
        logwriter = csv.DictWriter(
            args.logfile, fieldnames=['status'] + lineage_reader.fieldnames, extrasaction='ignore')
        logwriter.writeheader()

    for row in lineages:
        terminal = [(rank, name) for rank, name in row.items() if name][-1]
        if terminal in rename:
            if args.logfile:
                logwriter.writerow(OrderedDict(status='orig', **row))

            new = rename[terminal]
            if new in tax_names:
                row = OrderedDict(name=row['name'], **tax_names[new])
                status = 'renamed'
            elif terminal[0] == new[0]:
                # if ranks are the same, assume we are just replacing the name at this rank
                row[terminal[0]] = new[1]
                status = 'renamed'
            else:
                status = 'not_renamed'

            if args.logfile:
                logwriter.writerow(OrderedDict(status=status, **row))

        writer.writerow(row)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
