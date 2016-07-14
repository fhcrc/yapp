#!/bin/bash

out=questions/$(basename ${0%.sh})
mkdir -p $out

bin/get_reps.py \
    data/urogenital_named-2015-08-24.refpkg \
    output-gethits/hits.db \
    output/dedup_merged.fasta.gz \
    --seqs $out/combined.aln.fasta \
    --names $out/combined_names.csv \
    --hits $out/hits.csv \
    --rank species \
    --tax-id 187101 168808

bin/filter_jplace.py \
    output/dedup.jplace \
    $out/combined_names.csv \
    --placements $out/filtered.jplace \
    --tree $out/tree.xml
