#!/bin/bash

which pplacer
pplacer --version
echo

which cmalign
cmalign -h | grep '#'
echo

echo 'biosocns'
python -c 'import bioscons; print bioscons.__version__'

echo 'bioy'
python -c 'import bioy_pkg; print bioy_pkg.__version__'

echo
env
