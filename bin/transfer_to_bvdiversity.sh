#!/bin/bash

set -e

if ! git diff-index --quiet HEAD; then
    echo "Error: git repo is dirty - commit and try again"
    echo
    git status
    exit 1
fi

dirname=${1-$(date "+%Y-%m-%d")-$(basename $(pwd))}

dest_dir=/fh/fast/fredricks_d/bvdiversity/$dirname

mkdir -p "$dest_dir"

for fn in output*/for_transfer.txt; do
    bin/transfer.py $fn --dest $dest_dir
done
