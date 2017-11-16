#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(tidyr, quietly = TRUE))

main <- function(arguments){
  parser <- ArgumentParser()
  parser$add_argument('-c', '--classif')
  parser$add_argument('-s', '--specimens')
  parser$add_argument('-w', '--weights')
  ## parser$add_argument('--labels')
  parser$add_argument(
             '--rename',
             help='csv file with current name in first column, new name in second')
  parser$add_argument('--remove-taxa', help='csv file with column "tax_name"')

  ## outputs
  parser$add_argument('--by-sv')
  parser$add_argument('--by-sv-long')
  parser$add_argument('--by-taxon')
  parser$add_argument('--by-taxon-long')
  parser$add_argument('--lineages')

  ## parser$add_argument('--min-reads', type='integer', default=0)
  args <- parser$parse_args(arguments)

  classif <- read.csv(args$classif, as.is=TRUE)
  specimens <- read.csv(args$specimens, as.is=TRUE, header=FALSE,
                        col.names=c('seqname', 'specimen'))
  weights <- read.csv(args$weights, as.is=TRUE, header=FALSE,
                      col.names=c('name', 'seqname', 'read_count'))

  if(is.null(args$remove_taxa)){
    remove_taxa <- character()
  }else{
    remove_taxa <- read.csv(args$remove_taxa, as.is=TRUE)$tax_name
  }

  ## ranks in order, root first
  ranks <- classif %>%
    select(rank, rank_order) %>%
    group_by(rank, rank_order) %>%
    arrange(rank_order) %>%
    unique %>%
    "[["('rank')

  lineages <- classif %>%
    select(name, rank, tax_name) %>%
    mutate(rank=factor(rank, levels=ranks)) %>%
    unique %>%
    tidyr::spread(key=rank, value=tax_name)

  by_sv <- classif %>%
    filter(want_rank == 'species') %>%
    filter(!tax_name %in% remove_taxa) %>%
    full_join(weights, by='name') %>%
    full_join(specimens, by='seqname') %>%
    select(specimen, name, rank, tax_name, read_count)

  ## rename tax_names if specified
  ## TODO: do this in classif so that tax_tbl reflects same changes
  if(!is.null(args$rename)){
    rename <- read.csv(args$rename, as.is=TRUE)
    new_name <- setNames(trimws(rename[[2]]), trimws(rename[[1]]))
    labeled$tax_name_orig <- labeled$tax_name
    labeled$tax_name <- with(
        by_sv,
        ifelse(is.na(new_names[tax_name]), tax_name, new_names[tax_name]))

    cat('renamed tax_names:\n')
    print(with(
        by_sv,
        unique(labeled[tax_name != tax_name_orig, c('tax_name_orig', 'tax_name')])))
  }

  by_sv_wide <- by_sv %>%
    select(specimen, name, tax_name, read_count) %>%
    tidyr::spread(key=specimen, value=read_count, fill=0)

  by_tax_name <- by_sv %>%
    select(specimen, rank, tax_name, read_count) %>%
    group_by(specimen, tax_name, rank) %>%
    summarize(read_count=sum(read_count)) %>%
    filter(!is.na(tax_name)) %>%
    ungroup

  ## order tax names by overall abundance
  tax_names <- by_tax_name %>%
    group_by(tax_name) %>%
    summarize(total_count=sum(read_count)) %>%
    arrange(desc(total_count)) %>%
    "[["('tax_name') %>%
    as.character

  by_tax_name_wide <- by_tax_name %>%
    mutate(tax_name=factor(tax_name, levels=tax_names)) %>%
    select(specimen, tax_name, read_count) %>%
    tidyr::spread(key=specimen, value=read_count, fill=0)

  write_csv <- function(obj, var, ...){
    if(!is.null(args[[var]])){
      write.csv(obj, file=args[[var]], ...)
    }}

  write_csv(by_sv_wide, 'by_sv', row.names=FALSE)
  write_csv(by_sv, 'by_sv_long', row.names=FALSE)

  write_csv(by_tax_name_wide, 'by_taxon', row.names=FALSE)
  write_csv(arrange(by_tax_name, tax_name, desc(read_count)),
            'by_taxon_long', row.names=FALSE)

  write_csv(lineages, 'lineages', row.names=FALSE, na='')
}

main(commandArgs(trailingOnly=TRUE))
warnings()
## invisible(warnings())

