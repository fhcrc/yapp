#!/usr/bin/env python

"""Extract and annotate selected reference sequences

"""

import argparse
import logging
import csv
import sys
import re

from taxtastic.refpkg import Refpkg

from bioy_pkg.utils import Opener
from bioy_pkg.sequtils import fastalite

log = logging.getLogger(__name__)


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('refpkg')
    parser.add_argument('hits_csv', type=Opener())
    parser.add_argument('merged', type=Opener())
    parser.add_argument('--rank', help='tank of tax_ids')
    parser.add_argument('--tax-id', help='comma-delimited list of taxids to extract')
    parser.add_argument('-o', '--outfile', type=Opener('w'),
                        help='fasta file containing extracted sequences', default=sys.stdout)
    parser.add_argument('-n', '--names', type=Opener('w'),
                        help='csv file mapping original to annotated names')

    return parser.parse_args(arguments)


def safename(text):
    return '_'.join([e for e in re.split(r'[^a-zA-Z0-9]', text) if e])


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    rp = Refpkg(args.refpkg)
    seq_info = {d['seqname']: d for d in csv.DictReader(rp.open_resource('seq_info'))}
    taxonomy = {d['tax_id']: d for d in csv.DictReader(rp.open_resource('taxonomy'))}

    hits = {d['name']: d for d in csv.DictReader(args.hits_csv)}

    seqs = fastalite(args.merged)

    rank = args.rank
    tax_ids = set(args.tax_id.split(','))

    if args.names:
        writer = csv.writer(args.names)

    for seq in seqs:
        keep, name, seqtype = None, None, None
        if seq.id in hits:
            keep = True
            name = '{}|{}'.format(safename(seq.id), hits[seq.id]['abundance'])
            seqtype = 'q'
        elif seq.id in seq_info:
            d = seq_info[seq.id]
            keep = taxonomy[d['tax_id']][rank] in tax_ids
            seqtype = 'r'
            name = '{name}|{seqname}|{accession}|taxid{tax_id}'.format(
                name=safename(d['description']), **d)

        if keep:
            args.outfile.write('>{}\n{}\n'.format(name, seq.seq.upper()))

        if name and args.names:
            writer.writerow([seqtype, seq.id, name])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
