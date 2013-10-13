#!/bin/bash

which pplacer
pplacer --version
echo

which cmalign
cmalign -h | grep '#'
echo

pip freeze

echo
env
