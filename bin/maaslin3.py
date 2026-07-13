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
PREFIXES = {
    'domain': 'd__', 'phylum': 'p__', 'class': 'c__',
    'order': 'o__', 'family': 'f__', 'genus': 'g__',
    'species': 's__',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('taxon_table_long', help='taxon_table_long.csv')
    parser.add_argument('taxtable', help='taxtable.csv with lineage columns')
    parser.add_argument('-o', '--output', default=sys.stdout,
                        type=argparse.FileType('w'),
                        help='output TSV (default: stdout)')
    parser.add_argument('--silva', action='store_true',
                        help='use Silva lineage format '
                        '(e.g. d__Bacteria;p__Bacillota;...)')
    args = parser.parse_args()

    long = pd.read_csv(args.taxon_table_long)

    taxtable = pd.read_csv(args.taxtable, dtype=str).fillna('')
    id_to_name = taxtable.set_index('tax_id')['tax_name'].to_dict()

    for rank in RANKS:
        taxtable[rank] = taxtable[rank].map(id_to_name)

    # Resolve slash names by looking up the first constituent
    tt_names = set(taxtable['tax_name'])
    slash_map = {}
    for name in long['tax_name'].unique():
        if name not in tt_names and '/' in name:
            first = name.split('/')[0].strip()
            if first in tt_names:
                slash_map[name] = first

    long['_lookup'] = long['tax_name'].map(
        lambda n: slash_map.get(n, n))

    merged = long.merge(
        taxtable[['tax_name'] + RANKS],
        left_on='_lookup', right_on='tax_name',
        how='left', suffixes=('', '_tt'))
    merged['tax_name'] = long['tax_name']

    if args.silva:
        def build_lineage(row, up_to_rank):
            parts = []
            tname = row['tax_name']
            is_slash = '/' in tname
            rank_of_taxon = row.get('rank', '')
            for r in RANKS:
                val = row[r]
                if pd.notna(val) and val:
                    if r == up_to_rank and is_slash \
                            and r == rank_of_taxon:
                        parts.append(PREFIXES[r] + tname)
                    else:
                        parts.append(PREFIXES[r] + val)
                if r == up_to_rank:
                    break
            return ';'.join(parts) if parts else None

    results = []
    rank_of_name = {}
    for rank in RANKS:
        sub = merged[merged[rank].notna()][
            ['specimen', rank, 'read_count']].copy()
        if args.silva:
            sub[rank] = merged.loc[sub.index].apply(
                lambda r: build_lineage(r, rank), axis=1)
            sub = sub[sub[rank].notna()]
        grouped = sub.groupby([rank, 'specimen'])['read_count'].sum()
        grouped.index.names = ['tax_name', 'specimen']
        results.append(grouped)
        for name in grouped.index.get_level_values('tax_name').unique():
            rank_of_name.setdefault(name, rank)

    df = (pd.concat(results)
          .groupby(['tax_name', 'specimen']).sum()
          .reset_index())
    wide = df.pivot_table(
        index='tax_name', columns='specimen',
        values='read_count', fill_value=0)

    if not args.silva:
        wide.insert(0, 'rank', wide.index.map(rank_of_name))

    wide.index.name = 'sample'
    wide.columns.name = None
    wide.to_csv(args.output, sep='\t', float_format='%.0f')


main()
