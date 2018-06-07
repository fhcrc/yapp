#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(tidyr, quietly = TRUE))

## options(error=recover, width=150)

main <- function(arguments){
  parser <- ArgumentParser()
  parser$add_argument('orig')
  parser$add_argument('renamed')
  parser$add_argument('-o', '--output')
  args <- parser$parse_args(arguments)

  orig <- read.csv(args$orig, as.is=TRUE)
  renamed <- read.csv(args$renamed, as.is=TRUE)

  compared <- full_join(
    orig, renamed, by=c("name", "want_rank"), suffix=c(".orig", ".renamed")) %>%
    filter(is.na(tax_name.orig) | is.na(tax_name.renamed) | tax_name.orig != tax_name.renamed)

  write.csv(compared, file=args$output, row.names=FALSE, na="")
}

main(commandArgs(trailingOnly=TRUE))
## debugger()
## warnings()


