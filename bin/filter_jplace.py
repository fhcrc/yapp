#!/usr/bin/env python3

"""Extract placements, write a 'tog' tree, and annotate names

"""

import os
import sys
import argparse
from tempfile import NamedTemporaryFile
import csv
import subprocess


def ntf(*args, **kwargs):
    tmpdir = kwargs.get('dir')
    kwargs['delete'] = kwargs['delete'] if 'delete' in kwargs else (tmpdir is None)

    if tmpdir is not None:
        try:
            os.makedirs(tmpdir)
        except OSError:
            pass

    return NamedTemporaryFile(*args, **kwargs)


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('jplace')
    parser.add_argument('names', type=argparse.FileType('r'),
                        help='csvfile with rows "oldname,newname"')
    parser.add_argument('-p', '--placements',
                        help="jplace file with subset of placements")
    parser.add_argument('--tog', help="output of 'guppy tog' (xml format)")
    parser.add_argument('--sing', help="output of 'guppy sing' (xml format)")
    parser.add_argument('--guppy', default='guppy',
                        help='path to the guppy executable [%(default)s]')
    args = parser.parse_args(arguments)

    try:
        __, names = list(zip(*csv.reader(args.names)))
    except ValueError:
        sys.exit('Warning: no query sequences were specified!')

    # filter jplace
    cmd = [args.guppy, 'filter', args.jplace, '-Vr', '-o', args.placements]
    for name in names:
        # escape pipes in regular expression
        cmd.extend(['-Ir', name.replace('|', r'\|')])

    subprocess.check_call(cmd)

    # tog tree
    if args.tog:
        cmd = [args.guppy, 'tog', '--xml', '-o', args.tog, args.placements]
        subprocess.check_call(cmd)

    # sing tree
    if args.sing:
        cmd = [args.guppy, 'sing', '--xml', '-o', args.sing, args.placements]
        subprocess.check_call(cmd)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
