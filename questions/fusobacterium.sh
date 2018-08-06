#!/bin/bash

source questions/setup
out=${OUTDIR:?}/fusobacterium
mkdir -p $out

xsv search -s description Fusobacterium manhart-2018-06-21-1.0.refpkg/lonelyfilled.seqinfo.csv | \
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

av $out/aln-muscle.fasta \
   -R 'sv-0089|Fusobacterium_equinum|85803' \
   --rename-from $out/names.csv \
   -C . -x -n 100 -L 200 > $out/aln-muscle-av.txt

av $out/aln-cmalign.fasta \
   -R 'sv-0089|Fusobacterium_equinum|85803' \
   --rename-from $out/names.csv \
   -C . -x -n 100 -L 200 > $out/aln-cmalign-av.txt

sing bin/get_reps.py \
     manhart-2018-06-21-1.0.refpkg \
     output/sv_table_long.csv \
     output/merged.fasta \
     --sv-pattern Fusobacterium \
     --rm-pattern 'sv-2868|sv-2723|PYGH01000023_1_1369|NZ_CP022123_1493675_1495222' \
     --aln $out/aln-cmalign-cleaned.fasta \
     --names $out/names-cleaned.csv \
     --seqs $out/seqs-cleaned.fasta

test -f $out/aln-muscle-cleaned.fasta ||
    muscle -in $out/seqs-cleaned.fasta -out $out/aln-muscle-cleaned.fasta

av $out/aln-muscle-cleaned.fasta \
   -R 'sv-0089|Fusobacterium_equinum|85803' \
   --rename-from $out/names-cleaned.csv \
   -C . -x -n 100 -L 60 --number-sequences \
   --pdf $out/aln-muscle-cleaned-av.pdf \
   --fontsize-pdf 7 \
   > $out/aln-muscle-cleaned-av.txt

python -m fastalite names $out/aln-muscle-cleaned.fasta > ord-cleaned.txt

av $out/aln-cmalign-cleaned.fasta \
   -R 'sv-0089|Fusobacterium_equinum|85803' \
   --rename-from $out/names-cleaned.csv \
   --sort-by-name ord-cleaned.txt \
   -C . -x -n 100 -L 60 --number-sequences \
   --pdf $out/aln-cmalign-cleaned-av.pdf \
   --fontsize-pdf 7 \
    > $out/aln-cmalign-cleaned-av.txt

tree -f $out

