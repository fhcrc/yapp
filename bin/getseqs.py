#!/usr/bin/env python

"""Get sequences by classification.

"""

import argparse
import logging
import csv
import sys
import sqlite3
import subprocess
import pprint
import re
from os import path
from collections import Counter, defaultdict
from operator import itemgetter
from itertools import imap, ifilter

from bioy_pkg.utils import Opener
from bioy_pkg.sequtils import fastalite, fasta_tempfile, UCLUST_HEADERS

log = logging.getLogger(__name__)


def parse_uc(infile):
    """
    Return a dict {centroid_name: [list_of_read_names]}
    """

    centroids = defaultdict(list)
    fields = itemgetter('type', 'query_label', 'target_label')
    rows = csv.DictReader(infile, delimiter = '\t', fieldnames = UCLUST_HEADERS)

    for row_type, seqname, centroid in imap(fields, rows):
        if row_type == 'S':
            centroids[seqname].append(seqname)
        elif row_type == 'H':
            centroids[centroid].append(seqname)

    return dict(centroids)


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('placements', help='database of placements')
    parser.add_argument('seqs', type=Opener(),
                        help='fasta file containing sequences')
    parser.add_argument('--weights', type=Opener(),
                        help='optional weights for sequences in `seqs`')
    parser.add_argument('-o', '--output', type=argparse.FileType('w'),
                        default=sys.stdout, help='output file for sequences')

    parser.add_argument('--tax-name', help='taxonomic name of sequences to retrieve')
    parser.add_argument('--tax-id', help='taxid of sequences to retrieve')
    parser.add_argument('--uc-id', help='cluster threshold [%(default)s]', default=0.985,
                        type=float)
    parser.add_argument('--min-weight', help='minimum cluster weight [%(default)s]', default=10,
                        type=int)

    parser.add_argument('--usearch', default='usearch6', help='usearch executable')

    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)

    # gotta have usearch
    try:
        subprocess.check_output(['which', args.usearch])
    except subprocess.CalledProcessError, e:
        sys.exit(e)

    seqs = {seq.id: seq for seq in fastalite(args.seqs)}

    con = sqlite3.connect(args.placements)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    cmd = """
    select * from multiclass_concat join taxa using(tax_id)
    """

    if args.tax_name:
        cmd += "where tax_name = ? "
        val = args.tax_name
    elif args.tax_id:
        cmd += "where tax_is = ? "
        val = args.tax_id
    else:
        print "Error: must specify at least one of --tax-name or --tax-id"
        sys.exit(1)

    # cmd += 'limit 10'

    cur.execute(cmd, (val,))
    seq_info = {row['name']: row for row in cur.fetchall()}

    assert len(seq_info) > 0

    # get all sequences from the query that are present in the fasta
    # (some may not be present if the input is deduped, for example)
    with fasta_tempfile(ifilter(None, (seqs.get(name) for name in seq_info))) as fasta:
        uc_cmd = [args.usearch, '-cluster_fast', fasta,
                  '-uc', '/dev/stdout', '-id', str(args.uc_id), '-quiet']

        print ' '.join(uc_cmd)
        p = subprocess.Popen(uc_cmd, stdout=subprocess.PIPE)
        stdout, stderr = p.communicate()
        centroids = parse_uc(stdout.splitlines())

    # use weights to correct masses if provided
    if args.weights:
        weights = {centroid: int(weight) for centroid, _, weight in csv.reader(args.weights)}
        cluster_sizes = [(sum(weights[name] for name in names), k) for k, names in centroids.items()]
    else:
        cluster_sizes = [(len(names), k) for k, names in centroids.items()]

    for size, centroid in sorted(cluster_sizes, reverse=True):

        safe_name = re.sub(r'[^a-zA-Z0-9]+', '_', seq_info[centroid]['tax_name'])

        if size >= args.min_weight:
            args.output.write('>{tax_name}|{size}|{name}\n{seq}\n'.format(
                name=centroid,
                tax_name=safe_name,
                size=size,
                seq=seqs[centroid].seq
            ))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))


