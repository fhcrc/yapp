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
    parser.add_argument('--rank', help='tank of tax_ids')
    parser.add_argument('--tax-id', help='comma-delimited list of taxids to extract')
    parser.add_argument('-o', '--outfile', type=Opener('w'),
                        help='fasta file containing extracted sequences', default=sys.stdout)

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
    seqs = fastalite(rp.open_resource('aln_fasta'))

    rank = args.rank
    tax_ids = set(args.tax_id.split(','))

    for seq in seqs:
        d = seq_info[seq.id]
        if taxonomy[d['tax_id']][rank] in tax_ids:
            name = '{name}|{seqname}|{accession}|tax_id:{tax_id}'.format(
                name=safename(d['description']), **d)
            args.outfile.write('>{}\n{}\n'.format(name, seq.seq.replace('-', '').upper()))

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
