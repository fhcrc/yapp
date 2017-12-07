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


def copy(fname, dest, stripdirs=0, do_copy=True):
    """Copy file `fname` to path `dest`. The directory hierarchy of the
    path to fname is preserved unless `stripdirs` is nonzero, in which
    case the specified number of directories will be removed from the
    front of the path. For example, 'foo/bar/baz.txt' will be copied
    to 'dest/bar/baz.txt' if stripdirs == 1.

    """

    dirpath, filepath = os.path.split(fname)
    destdir = os.path.join(dest, *dirpath.split('/')[stripdirs:])

    log.info('{} --> {}'.format(fname, destdir))

    if do_copy:
        try:
            os.makedirs(destdir)
        except OSError:
            pass

        shutil.copy(fname, destdir)


def get_args(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument('infiles', type=argparse.FileType(),
                        help='file listing files for transfer, one per line')
    parser.add_argument('--dest', help='destination directory [%(default)s]', default='./transfer')
    parser.add_argument('--stripdirs', metavar='N', default=0, type=int,
                        help='strip N parent directories from path of each infile')
    parser.add_argument('-n', '--no-copy', dest='copy', action='store_false', default=True,
                        help='list source and destination paths without copying')
    return parser.parse_args(arguments)


def main(arguments):
    logging.basicConfig(
        level=logging.INFO, format="%(message)s")

    args = get_args(arguments)
    try:
        os.makedirs(args.dest)
    except OSError:
        pass

    for fname in [f.strip() for f in args.infiles if f.strip() and not f.startswith('#')]:
        copy(fname, args.dest, args.stripdirs, do_copy=args.copy)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
