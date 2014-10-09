#!/usr/bin/env python

"""Transfer files, preserving the directory hierarchy somewhat.

The directory hierarchy of the path to each file is preserved unless
`stripdirs` is nonzero, in which case the specified number of
directories will be removed from the front of the path.

For example, 'foo/bar/baz.txt' will be copied to 'dest/bar/baz.txt'
given '--dest dest --stripdirs 1' stripdirs == 1.

"""

import argparse
import logging
import sys
import os
import shutil

log = logging.getLogger(__name__)


def copy(fname, dest, stripdirs=0):
    """Copy file `fname` to path `dest`. The directory hierarchy of the
    path to fname is preserved unless `stripdirs` is nonzero, in which
    case the specified number of directories will be removed from the
    front of the path. For example, 'foo/bar/baz.txt' will be copied
    to 'dest/bar/baz.txt' if stripdirs == 1.

    """

    dirpath, filepath = os.path.split(fname)
    destdir = os.path.join(dest, *dirpath.split('/')[stripdirs:])

    try:
        os.makedirs(destdir)
    except OSError:
        pass

    log.info('{} --> {}'.format(fname, destdir))
    shutil.copy(fname, destdir)


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('infiles', nargs='+')
    parser.add_argument('--dest', help='destination directory')
    parser.add_argument('--stripdirs', metavar='N', default=0, type=int,
                        help='strip N parent directories from path of each infile')
    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

    args = get_args(arguments)
    for fname in args.infiles:
        copy(fname, args.dest, args.stripdirs)

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))


