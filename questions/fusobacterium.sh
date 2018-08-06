#!/bin/bash

source questions/setup
out=${OUTDIR:?}/fusobacterium
mkdir -p $out

xsv search -s description Fusobacterium ${REFPKG:?}/lonelyfilled.seqinfo.csv | \
    xsv select seqname,description,is_type | \
    xsv sort -s description | xsv table > $out/refs.txt

sing bin/get_reps.py \
     ${REFPKG:?} \
     output/sv_table_long.csv \
     output/merged.fasta \
     --sv-pattern Fusobacterium \
     --aln $out/aln-cmalign.fasta \
     --names $out/names.csv \
     --seqs $out/seqs.fasta

test -f $out/aln-muscle.fasta ||
    muscle -in $out/seqs.fasta -out $out/aln-muscle.fasta

trim_to=$(cut -f2 -d, $out/names.csv | grep sv- | sort | head -n1)

av $out/aln-muscle.fasta \
   --exclude-invariant \
   --fontsize-pdf 6 \
   --lines-per-block 61 \
   --name-max 60 \
   --number-sequences \
   --orientation landscape \
   --simchar . \
   --trim-to $trim_to \
   --rename-from $out/names.csv \
   --pdf $out/aln-muscle-av.pdf \
   > $out/aln-muscle-av.txt

tree -f $out

