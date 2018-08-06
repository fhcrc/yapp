#!/bin/bash

source questions/setup
out=${OUTDIR:?}/klebsiella
mkdir -p $out

sing bin/get_reps.py \
     ${REFPKG:?} \
     output/sv_table_long.csv \
     output/merged.fasta \
     --sv-pattern Klebsiella \
     --aln $out/aln-cmalign.fasta \
     --names $out/names.csv \
     --seqs $out/seqs.fasta

test -f $out/aln-muscle.fasta ||
    muscle -in $out/seqs.fasta -out $out/aln-muscle.fasta

av $out/aln-muscle.fasta \
   -R 'sv-0303|Klebsiella_oxytoca|12499' \
   --rename-from $out/names.csv \
   -C . -x -n 100 \
   --pdf $out/aln-muscle-av.pdf \
   --fontsize-pdf 8 \
   > $out/aln-muscle-av.txt

tree -f $out

