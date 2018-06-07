#!/usr/bin/env python

"""Replace lineages based on classifications or individual SVs

Input file has the columns:

  (tax_name, rank, sv, new_tax_name, new_rank)

If sv is present, the lineages for the indicated SVs will be replaced
with lineages provided in one of the input files (and tax_name and
rank are ignored). Otherwise, all instances of (tax_name, rank) are
replaced with (new_tax_name, rank).

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

    rename_sv = {}
    rename_taxon = {}
    for row in csv.DictReader(args.to_rename):
        tax_name, rank, sv, new_tax_name, new_rank = [x.strip() for x in row.values()]
        new = (new_rank, new_tax_name)
        if sv:
            rename_sv[sv] = new
        else:
            rename_taxon[(rank, tax_name)] = new

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
        orig = row.copy()
        sv = row['name']
        terminal = [(rank, name) for rank, name in row.items() if name][-1]

        if sv in rename_sv:
            new = rename_sv[sv]
            row = OrderedDict(name=row['name'], **tax_names[new])
            status = 'replaced lineage by SV'
        elif terminal in rename_taxon:
            new = rename_taxon[terminal]
            if new in tax_names:
                row = OrderedDict(name=row['name'], **tax_names[new])
                status = 'replaced lineage by tax name'
            elif terminal[0] == new[0]:
                # if ranks are the same, assume we are just replacing the name at this rank
                row[terminal[0]] = new[1]
                status = 'renamed tax name'
        else:
            status = None

        if status and args.logfile:
            logwriter.writerow(OrderedDict(status='orig', **orig))
            logwriter.writerow(OrderedDict(status=status, **row))

        writer.writerow(row)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
