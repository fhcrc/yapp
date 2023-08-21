#!/usr/bin/env python3
import argparse
import bz2
import csv
import io
import jplace
import json
import sys

from Bio import SeqIO


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('merged', type=argparse.FileType('r'))
    parser.add_argument('--blast-details')
    parser.add_argument('--jplace', type=argparse.FileType('r'))
    parser.add_argument('--limit', type=int)
    parser.add_argument('--name')
    parser.add_argument('--seqs', type=argparse.FileType('r'))
    parser.add_argument('--sort-by', default='likelihood')
    parser.add_argument('--specimen')
    parser.add_argument('--stockholm', type=argparse.FileType('r'))
    parser.add_argument(
        '--out', default=sys.stdout, type=argparse.FileType('w'))
    return parser.parse_args()


def main():
    args = get_args()
    names = {}  # {name: confidence}
    if args.blast_details:
        details = csv.DictReader(bz2.open(args.blast_details, 'rt'))
        details = (d for d in details if d['specimen'] == args.specimen)
        details = (d for d in details if d['pident'])
        details = (d for d in details if d['assignment_id'])
        details = sorted(
            details, key=lambda x: float(x['pident']), reverse=True)
        for d in details:
            names[d['sseqid']] = float('-inf')
    if args.name:
        names[args.name] = 0
    if args.stockholm:
        for a in SeqIO.parse(args.stockholm, 'stockholm'):
            names[a.name] = float('-inf')
    if args.jplace:
        jp = json.load(args.jplace)
        tree = next(jplace.JParser(io.StringIO(jp['tree'])).parse())
        pls = {}
        if jp['placements']:
            pls = jp['placements'][0]['p']
            pls = [{f: p[i] for i, f in enumerate(jp['fields'])} for p in pls]
            pls = {p['edge_num']: p for p in pls}
            clades = (c for c in tree.find_clades() if c.edge in pls)
            for c in clades:
                if c.is_terminal():
                    names[c.name] = pls[c.edge][args.sort_by]
    seqs = SeqIO.parse(args.merged, 'fasta')
    seqs = [s for s in seqs if s.name in names]
    if not seqs and args.seqs:
        seqs = SeqIO.parse(args.seqs, 'fasta')
        seqs = [s for s in seqs if s.name in names]
    seqs = sorted(seqs, key=lambda s: names[s.name], reverse=True)
    if args.limit:
        seqs = seqs[:args.limit]
    SeqIO.write(seqs, args.out, 'fasta')


if __name__ == '__main__':
    sys.exit(main())
