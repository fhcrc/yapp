#!/usr/bin/env python

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

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('jplace')
    parser.add_argument('names', type=argparse.FileType('r'))
    parser.add_argument('-p', '--placements',
                        help="jplace file with subset of placements")
    parser.add_argument('--tog', help="output of 'guppy tog' (xml format)",
                        type=argparse.FileType('w'))
    parser.add_argument('--sing', help="output of 'guppy sing' (xml format)",
                        type=argparse.FileType('w'))
    args = parser.parse_args(arguments)

    names = list(csv.reader(args.names))
    qnames = [(old, new) for seqtype, old, new in names if seqtype == 'q']

    try:
        oldnames, newnames = zip(*qnames)
    except ValueError:
        sys.exit('Warning: no query sequences were specified!')

    # filter jplace
    cmd = ['guppy', 'filter', args.jplace, '-Vr', '-o', args.placements]
    for name in oldnames:
        cmd.extend(['-Ir', name])
    subprocess.check_call(cmd)

    # tog tree
    if args.tog:
        with ntf(suffix='.xml') as treefile:
            cmd = ['guppy', 'tog', '--xml', '-o', treefile.name, args.placements]
            subprocess.check_call(cmd)
            treestr = treefile.read()

        for __, old, new in names:
            treestr = treestr.replace(old, new)

        args.tog.write(treestr)

    # sing tree
    if args.sing:
        with ntf(suffix='.xml') as treefile:
            cmd = ['guppy', 'sing', '--xml', '-o', treefile.name, args.placements]
            subprocess.check_call(cmd)
            treestr = treefile.read()

        for __, old, new in names:
            treestr = treestr.replace(old, new)

        args.sing.write(treestr)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

