#!/usr/bin/env python

"""
Usage seqmagick extract-ids seqs.fasta | pretend_to_deduplicate.py > dedup_info.csv
"""

import sys
import csv

def main():
    writer = csv.writer(sys.stdout)
    for name in sys.stdin:
        name = name.strip()
        writer.writerow([name, name, 1])


main()
