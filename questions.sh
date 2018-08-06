#!/bin/bash

export REFPKG=manhart-2018-06-21-1.0.refpkg
export OUTDIR=questions-output-2018-06-21-refpkg

for fn in questions/*.sh; do
    $fn
done
