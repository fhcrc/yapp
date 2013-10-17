#!/bin/bash

set -e

if [[ -z $1 ]]; then
    echo "Update a reference package to the Infernal 1.1 format."
    echo "usage: $(basename $0) refpkg [new_refpkg]"
    echo "If new_refpkg is unspecified, creates a new refpkg in cwd with a name based on refpkg"
    exit 1
fi

refpkg="$1"

if [[ -z $2 ]]; then
    new_refpkg=$(basename ${refpkg%.refpkg}).infernal1.1.refpkg
else
    new_refpkg=$2
fi

tempdir=$(mktemp -d ${new_refpkg}_tempXXXXXX)

profile=$(taxit rp $refpkg profile)
new_profile=$tempdir/$(basename ${profile%.cm})_v1.1.cm

set -x

(cmalign -h | grep -q 'INFERNAL 1.1') || (echo "requires infernal v1.1+"; exit 1)

rm -rf $new_refpkg
cp -rp $refpkg $new_refpkg

# convert cmfile
cmconvert $profile > $new_profile

# realign sequences
seqmagick convert --ungap --upper $(taxit rp $refpkg aln_sto) $tempdir/seqs.fasta
cmalign -o $tempdir/alignment.sto --sfile $tempdir/align_scores.txt --noprob --dnaout $new_profile $tempdir/seqs.fasta

# new tree
seqmagick convert $tempdir/alignment.sto $tempdir/alignment.fasta
FastTreeMP -nt -gtr -log $tempdir/tree_stats.txt $tempdir/alignment.fasta > $tempdir/tree.tre

# update refpkg
taxit update $new_refpkg \
    aln_fasta=$tempdir/alignment.fasta \
    aln_sto=$tempdir/alignment.sto \
    profile=$new_profile \
    tree=$tempdir/tree.tre \
    tree_stats=$tempdir/tree_stats.txt

taxit reroot $new_refpkg
rm -r $tempdir
