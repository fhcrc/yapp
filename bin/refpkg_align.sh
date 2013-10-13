#!/bin/bash +x

set -e

refpkg=$1
fasta=$2
merged=$3
scores=$4

ref_sto=$(taxit rp $refpkg aln_sto)
profile=$(taxit rp $refpkg profile)

sto=$(mktemp -u).sto

cmalign -o $sto --sfile $scores \
    --noprob --dnaout \
    $profile $fasta | grep -E '^#'

esl-alimerge --dna -o $merged $ref_sto $sto
rm $sto
