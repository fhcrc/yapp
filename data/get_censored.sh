#!/bin/bash

in2csv data/control_tallies_allspecimens-SS_TF_2016-03-31.xlsx | \
    csvgrep -c censor -m y | \
    csvcut -c query | \
    tail -n+2 > data/censored.txt
