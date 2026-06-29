#!/usr/bin/env python3
"""Build MaAsLin3 hierarchical feature table from taxon_table_long.csv.

Outputs raw read counts. MaAsLin3 normalizes internally via the normalization
parameter (default: TSS — divides each feature by the sample total to give
relative abundances). Example R usage:

    maaslin3(
        input_data = "maaslin3_input.tsv",
        input_metadata = "metadata.tsv",
        output = "output/",
        normalization = "TSS",
        transform = "LOG"
    )
"""

import argparse
import sys
import pandas as pd

RANKS = ['domain', 'phylum', 'class', 'order', 'family', 'genus', 'species']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('taxon_table_long', help='taxon_table_long.csv')
    parser.add_argument('taxtable', help='taxtable.csv with lineage columns')
    parser.add_argument('-o', '--output', default=sys.stdout,
                        type=argparse.FileType('w'),
                        help='output TSV (default: stdout)')
    args = parser.parse_args()

    long = pd.read_csv(args.taxon_table_long)

    taxtable = pd.read_csv(args.taxtable, dtype=str).fillna('')
    id_to_name = taxtable.set_index('tax_id')['tax_name'].to_dict()

    for rank in RANKS:
        taxtable[rank] = taxtable[rank].map(id_to_name)

    merged = long.merge(
        taxtable[['tax_name'] + RANKS], on='tax_name', how='left')

    results = []
    for rank in RANKS:
        sub = merged[merged[rank].notna()][['specimen', rank, 'read_count']]
        grouped = sub.groupby([rank, 'specimen'])['read_count'].sum()
        grouped.index.names = ['tax_name', 'specimen']
        results.append(grouped)

    df = (pd.concat(results)
          .groupby(['tax_name', 'specimen']).sum()
          .reset_index())
    wide = df.pivot_table(
        index='tax_name', columns='specimen',
        values='read_count', fill_value=0)
    wide.index.name = 'sample'
    wide.columns.name = None
    wide.to_csv(args.output, sep='\t', float_format='%.0f')


main()
