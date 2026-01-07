#!/usr/bin/env python3

"""
Creates a tsv file that can be used with KronaTools ktImportText

https://github.com/marbl/Krona/wiki/Importing-text-and-XML-data

Example usage:

krona.py taxon_table_long.csv reference/package/taxtable.csv output/
"""

import argparse
import csv
import itertools
import os
import sys


def main(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'taxon_table_long',
        help='csv with columns: specimen,tax_name,rank,read_count',
        type=argparse.FileType('r')
        )
    parser.add_argument(
        'taxtable',
        type=argparse.FileType('r')
        )
    parser.add_argument(
        '--drop-no-rank',
        action='store_true',
        help='Drop "no rank" taxonomies'
        )
    parser.add_argument('outdir')
    args = parser.parse_args(arguments)
    taxtable = csv.DictReader(args.taxtable)
    header = taxtable.fieldnames
    ranks = header[header.index('root'):]
    if args.drop_no_rank:
        ranks = [r for r in ranks if not r.endswith('_')]
    taxtable = {t['tax_id']: t for t in taxtable}
    names = {}
    for row in taxtable.values():
        name_row = []
        for r in ranks:
            name_row.append(taxtable[row[r]]['tax_name'] if row[r] else '')
        names[row['tax_name']] = name_row
    taxon_table_long = csv.DictReader(args.taxon_table_long)
    taxon_table_long = sorted(taxon_table_long, key=lambda x: x['specimen'])
    taxon_table_long = itertools.groupby(
        taxon_table_long,
        key=lambda x: x['specimen']
        )
    os.makedirs(args.outdir, exist_ok=True)
    for specimen, rows in taxon_table_long:
        with open(os.path.join(args.outdir, specimen + '.tsv'), 'w') as flo:
            for r in rows:
                tax_name = r['tax_name'].split('/')[0]
                out = csv.writer(flo, delimiter='\t')
                lineage = names[tax_name].copy()
                lineage[lineage.index(tax_name)] = r['tax_name']
                out.writerow([r['read_count']] + lineage)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
