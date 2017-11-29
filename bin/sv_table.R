#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(tidyr, quietly = TRUE))

options(error=recover)

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
  parser$add_argument('--sv-names')

  ## other options
  parser$add_argument(
             '--include-unclassified', action='store_true', default=FALSE,
             help='include tallies of reads not represented in --classif')

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

  options(width=200)

  if(args$include_unclassified){
    sv_names <- unique(weights$name)
    missing <- setdiff(sv_names, classif$name)

    unclassified <- split(classif, classif$name)[[1]]
    for(col in colnames(unclassified)[c(-1, -2)]){
      unclassified[[col]] <- unclassified[1,col]
    }

    for(name in missing){
      unclassified$name <- name
      classif <- rbind(classif, unclassified)
    }

    stopifnot(setdiff(sv_names, classif$name) == 0)
  }

  ## ranks in order, root first
  ranks <- classif %>%
    select(rank, rank_order) %>%
    group_by(rank, rank_order) %>%
    arrange(rank_order) %>%
    unique %>%
    "[["('rank')

  ## rename tax_names if specified
  if(!is.null(args$rename)){
    rename <- read.csv(args$rename, as.is=TRUE)
    new_name <- setNames(trimws(rename[[2]]), trimws(rename[[1]]))
    classif$tax_name_orig <- classif$tax_name
    classif$tax_name <- with(
        by_sv,
        ifelse(is.na(new_names[tax_name]), tax_name, new_names[tax_name]))

    cat('renamed tax_names:\n')
    print(with(
        by_sv,
        unique(classif[tax_name != tax_name_orig, c('tax_name_orig', 'tax_name')])))

    classif$tax_name_orig <- NULL
  }

  ## some tax_names are not unique and must be distinguished by rank.
  taxtab <- classif %>% select(tax_name, rank) %>% unique %>% '[['('tax_name') %>% table
  not_unique <- names(taxtab[taxtab > 1])

  classif <- classif %>%
    mutate(tax_name=ifelse(
               tax_name %in% not_unique, gettextf('%s (%s)', tax_name, rank), tax_name
           ))

  lineages <- classif %>%
    select(name, rank, tax_name) %>%
    mutate(rank=factor(rank, levels=ranks)) %>%
    unique %>%
    tidyr::spread(key=rank, value=tax_name)

  ## note that left join excludes SVs without classifications unless
  ## they have been added to classif above
  by_sv <- classif %>%
    filter(want_rank %in% 'species') %>%
    filter(!tax_name %in% remove_taxa) %>%
    left_join(weights, by='name') %>%
    left_join(specimens, by='seqname') %>%
    select(specimen, name, rank, tax_name, read_count)

  stopifnot(!any(duplicated(by_sv)))

  by_sv_wide <- by_sv %>%
    select(specimen, name, tax_name, read_count) %>%
    tidyr::spread(key=specimen, value=read_count, fill=0)

  by_tax_name <- by_sv %>%
    select(specimen, rank, tax_name, read_count) %>%
    group_by(specimen, tax_name, rank) %>%
    summarize(read_count=sum(read_count)) %>%
    filter(!is.na(tax_name)) %>%
    ungroup

  ## save(weights, specimens, by_sv, classif, by_tax_name, file='stuff.rda')

  ## order tax names by overall abundance
  tax_names <- by_tax_name %>%
    group_by(tax_name, rank) %>%
    summarize(total_count=sum(read_count)) %>%
    arrange(desc(total_count)) %>%
    "[["('tax_name') %>%
    as.character

  by_tax_name_wide <- by_tax_name %>%
    mutate(tax_name=factor(tax_name, levels=tax_names)) %>%
    select(specimen, tax_name, read_count) %>%
    unique %>%
    tidyr::spread(key=specimen, value=read_count, fill=0)

  total_weight <- sum(weights$read_count)
  by_sv_weight <- sum(by_sv$read_count)
  by_tax_name_weight <- sum(by_tax_name$read_count)
  cat(gettextf('total: %s\nby_sv: %s\nby_tax_name: %s\n',
               total_weight, by_sv_weight, by_tax_name_weight))
  stopifnot(by_sv_weight == by_tax_name_weight)

  if(args$include_unclassified){
    stopifnot(by_sv_weight == total_weight)
    stopifnot(by_tax_name_weight == total_weight)
  }else{
    stopifnot(by_sv_weight <= total_weight)
    stopifnot(by_tax_name_weight <= total_weight)
  }

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

  if(!is.null(args$sv_names)){
    write.table(by_sv_wide[, 1, drop=FALSE], file=args$sv_names,
                row.names=FALSE, col.names=FALSE, quote=FALSE)
  }

}

main(commandArgs(trailingOnly=TRUE))
## debugger()
warnings()


