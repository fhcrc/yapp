#!/usr/bin/env python

"""View placement details in .jplace file

"""

import sys
import argparse
import csv
import json


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('jplace', help=".jplace file", type=argparse.FileType('r'))
    parser.add_argument('-p', '--placements', help="table of placement details",
                        type=argparse.FileType('w'), default=sys.stdout)
    parser.add_argument('-n', '--names', help="read names to display", nargs='*')

    args = parser.parse_args(arguments)

    data = json.load(args.jplace)

    placements = csv.writer(args.placements)
    placements.writerow(['name', 'weight'] + data['fields'])

    show = set(args.names) if args.names else set()

    for p in data['placements']:
        for name, weight in p['nm']:
            if show and name not in show:
                continue
            placements.writerows([name, weight] + row for row in p['p'])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

