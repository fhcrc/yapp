#!/bin/bash +x

set -e

refpkg=$1
fasta=$2   # .fasta.bz2
merged=$3  # .fasta.bz2
scores=$4  # .txt

ref_sto=$(taxit rp $refpkg aln_sto)
profile=$(taxit rp $refpkg profile)

sto=$(mktemp -u).sto

cmalign -o $sto --sfile $scores \
    --noprob --dnaout --informat FASTA \
    $profile <(bzcat $fasta) | grep -E '^#'

esl-alimerge --dna --outformat afa $ref_sto $sto | bzip2 > $merged
rm $sto
