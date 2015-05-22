#!/bin/bash

set -e

if ! git diff-index --quiet HEAD; then
    echo "Error: git repo is dirty - commit and try again"
    echo
    git status
    exit 1
fi

dest_dir=/fh/fast/fredricks_d/bvdiversity/$(date "+%Y-%m-%d")-$(basename $(pwd))

(git --no-pager log -n1; git status) > $dest_dir/project_status.txt
bin/transfer.py output/for_transfer.txt --dest $dest_dir