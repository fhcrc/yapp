#!/bin/bash -x

set -e

# venv for dev branch
# bin/bootstrap.sh --venv 20140123-dev-env --pplacer-version dev

# venv for 318 branch
# bin/bootstrap.sh --venv 20140123-318-env --pplacer-version 318-placement-specific-mask

mkdir -p data

proj=/shared/silo_researcher/Fredricks_D/bvdiversity/combine_projects/output/projects/cultivation
cut -f2 -d, $proj/seq_info.csv | sort | uniq -c | sort -n | sed -n 20,23p | tr -s ' ' | cut -d' ' -f 3 > data/specimens.txt

csvgrep -f data/specimens.txt -c specimen $proj/labels.csv > data/labels.csv

bin/subsample $proj/seqs.fasta $proj/seq_info.csv data/specimens.txt data/seqs.fasta data/seq_info.csv

# raxml tree
salloc -n 12 raxml.py $(taxit rp data/urogenital-named-20130610.infernal1.1.refpkg aln_fasta) data/ug-raxml.tre --stats data/ug-raxml.stats --threads 12

cp -r data/urogenital-named-20130610.infernal1.1.refpkg data/urogenital-named-20130610.infernal1.1-raxml.refpkg
taxit update data/urogenital-named-20130610.infernal1.1-raxml.refpkg tree=data/ug-raxml.tre tree_stats=data/ug-raxml.stats

rppr check -c data/urogenital-named-20130610.infernal1.1-raxml.refpkg
