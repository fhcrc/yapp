#!/bin/bash

pwd

git status
echo

grep -C3 -E '^refpkg =' SConstruct

git --no-pager log -n 1
echo

which pplacer
pplacer --version
echo

which cmalign
cmalign -h | grep '#'
echo

which vsearch
vsearch --version
echo

which FastTree
FastTree -expert 2>&1 | head -1
echo

pip freeze
