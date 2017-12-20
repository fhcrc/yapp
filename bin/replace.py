#!/usr/bin/env python

"""Replace all occurrences of OLD with NEW in infile given csv file of OLD,NEW

"""

from __future__ import print_function
import sys
import argparse
import csv
import json
import re


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('infile', help="jplace file", type=argparse.FileType('r'))
    parser.add_argument('mapfile', help="csv file mapping OLD to NEW ",
                        type=argparse.FileType('r'))
    parser.add_argument('-o', '--outfile', help="Output file",
                        default=sys.stdout, type=argparse.FileType('w'))

    args = parser.parse_args(arguments)

    replacements = dict(csv.reader(args.mapfile))
    data = json.load(args.infile)

    # replacements in tree
    def repl(matchobj):
        match = matchobj.group(0)
        return match[0] + replacements[match[1:-1]] + match[-1]

    tree = data['tree']
    data['tree'] = re.sub(r'[(,]([A-Z_0-9-]+):', repl, tree, flags=re.I)

    # replacements among placements names
    placements = data['placements'].copy()
    for placement in placements:
        placement['nm'] = [[replacements[label], count] for label, count in placement['nm']]

    data['placements'] = placements
    json.dump(data, args.outfile, indent=2)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
