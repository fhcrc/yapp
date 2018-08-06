#!/bin/bash

source questions/setup
out=${OUTDIR:?}/haemophilus
mkdir -p $out

sing bin/get_reps.py \
     ${REFPKG:?} \
     output/sv_table_long.csv \
     output/merged.fasta \
     --sv-pattern Haemophilus \
     --aln $out/aln-cmalign.fasta \
     --names $out/names.csv \
     --seqs $out/seqs.fasta

test -f $out/aln-muscle.fasta ||
    muscle -in $out/seqs.fasta -out $out/aln-muscle.fasta

trim_to=$(cut -f2 -d, $out/names.csv | grep sv- | sort | head -n1)

av $out/aln-muscle.fasta \
   --trim-to $trim_to \
   --rename-from $out/names.csv \
   -C . \
   -x \
   -n 100 \
   --pdf $out/aln-muscle-av.pdf \
   --fontsize-pdf 7 \
   > $out/aln-muscle-av.txt

tree -f $out

