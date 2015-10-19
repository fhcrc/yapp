#!/usr/bin/env python

"""Extract placement details from a .jplace file

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
    parser.add_argument('-d', '--details', help="table of placement details",
                        type=argparse.FileType('w'))
    parser.add_argument('-n', '--names', help="table of read names and placement ids",
                        type=argparse.FileType('w'))

    args = parser.parse_args(arguments)

    data = json.load(args.jplace)

    if args.details:
        details = csv.writer(args.details)
        details.writerow(['pnum'] + data['fields'])

    if args.names:
        pnames = csv.writer(args.names)
        pnames.writerow(['pnum', 'name', 'weight'])

    for i, p in enumerate(data['placements']):
        if args.names:
            pnames.writerows([i, name, weight] for name, weight in p['nm'])
        if args.details:
            details.writerows([i] + row for row in p['p'])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

