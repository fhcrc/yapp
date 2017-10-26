#!/bin/bash

set -e

to_dir=/fh/fast/fredricks_d/bvdiversity/$(date "+%Y-%m-%d")-$(basename $(pwd))

source $(dirname $0)/argparse.bash || exit 1
argparse "$@" <<EOF || exit 1
parser.add_argument('--from-dir', default="output")
parser.add_argument('--to-dir', default="$to_dir")
parser.add_argument('-n', '--dry-run', action="store_true")
EOF

echo "from directory: $FROM_DIR"
echo "to directory: $TO_DIR"
if [[ $DRY_RUN ]]; then
    bin/transfer.py "$FROM_DIR/for_transfer.txt" --dest "$TO_DIR" -n
    exit
fi

if ! git diff-index --quiet HEAD; then
    echo "Error: git repo is dirty - commit and try again"
    echo
    git status
    exit 1
fi

mkdir -p "$TO_DIR"
(git --no-pager log -n1; git status) > "$TO_DIR/project_status.txt"
bin/transfer.py "$FROM_DIR/for_transfer.txt" --dest "$TO_DIR"

