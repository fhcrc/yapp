#!/bin/bash

git status
echo

git --no-pager log -n 1
echo

which pplacer
pplacer --version
echo

which cmalign
cmalign -h | grep '#'
echo

pip freeze
