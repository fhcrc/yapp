#!/usr/bin/env python3
"""Convert taxon_table_long.csv to MaAsLin3-compatible wide format."""

import argparse
import pandas
import sys


def main():
    parser = argparse.ArgumentParser(
        description='Convert taxon_table_long.csv to MaAsLin3 wide format')
    parser.add_argument('table_long', help='Path to taxon_table_long.csv')
    parser.add_argument(
        '--index-column',
        default='specimen',
        type=str,
        help='Column to index on')
    parser.add_argument(
        '-o', '--output',
        default=sys.stdout,
        help='Output TSV file (default: maaslin3_data.txt)')
    args = parser.parse_args()
    table_long = pandas.read_csv(args.table_long)
    wide = table_long.pivot_table(
        index=args.index_column,
        columns='tax_name',
        values='read_count',
        aggfunc='sum',
        fill_value=0,
    )
    wide.index.name = 'sample_id'
    wide.columns.name = None
    wide.to_csv(args.output, sep='\t')


if __name__ == '__main__':
    main()
