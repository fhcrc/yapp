#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(lattice, quietly = TRUE))
suppressPackageStartupMessages(library(latticeExtra, quietly = TRUE))
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(tidyr, quietly = TRUE))

main <- function(arguments){
  parser <- ArgumentParser()
  parser$add_argument('--classifications')
  parser$add_argument('--labels')
  parser$add_argument(
             '--rename',
             help='csv file with columns "current_classification","new_classification"')
  parser$add_argument('--remove', help='csv file with column "current_classification"')
  parser$add_argument('--min-reads', type='integer', default=0)
  parser$add_argument('--long')
  parser$add_argument('--wide')
  args <- parser$parse_args(arguments)

  classif <- read.csv(args$classifications, as.is=TRUE)
  labels <- read.csv(args$labels, as.is=TRUE)
  rename <- read.csv(args$rename, as.is=TRUE)
  remove <- read.csv(args$remove, as.is=TRUE)

  labels <- labels[labels$project == 'CRC Variability' & grepl('^R', labels$label),
                   c('specimen', 'label')]

  ## confirm labels are unique
  stopifnot(all(table(labels$label) == 1))

  labeled <- merge(
      labels, classif, by='specimen', all.x=TRUE, all.y=FALSE
  )[,c('specimen', 'label', 'tax_name', 'tally')]
  labeled$label <- factor(labeled$label)

  cat('specimens with no classified reads:\n')
  missing <- labeled[is.na(labeled$tax_name),]
  print(missing)

  ## replace names
  new_names <- with(
      rename,
      setNames(trimws(new_classification), trimws(current_classification)))
  labeled$organism <- with(
      labeled,
      ifelse(is.na(new_names[tax_name]), tax_name, new_names[tax_name]))

  cat('renamed organisms:\n')
  print(with(
      labeled,
      unique(labeled[tax_name != organism, c('tax_name', 'organism')])))

  ## aggregate tallies, removing specified organisms
  ## https://sesync-ci.github.io/data-manipulation-in-R-lesson/2016/07/26/#grouping-and-aggregation
  tallies <- labeled %>%
    dplyr::filter(!tax_name %in% trimws(remove$current_classification)) %>%
    dplyr::group_by(label, organism) %>%
    dplyr::summarize(tally=sum(tally)) %>%
    dplyr::arrange(label, desc(tally))

  tallies$grp <- gsub('_A[1,2]$', '', as.character(tallies$label))

  reps <- tallies %>%
    group_by(grp, organism) %>%
    summarize(max_tally=max(tally))

  ## remove values < min_reads when neither replicate meets that
  ## threshold.
  merged <- merge(reps, tallies, by=c('grp', 'organism'), all.x=TRUE)
  merged <- merged %>%
    dplyr::filter(max_tally >= args$min_reads) %>%
    "["(,c('label', 'organism', 'tally')) %>%
    dplyr::arrange(label, desc(tally))

  save(labeled, tallies, reps, merged, file='labeled.rda')

  write.csv(merged, file=args$long, row.names=FALSE)

  ## wide format tallies
  ## order organisms by total abundance
  ord <- merged %>%
    dplyr::group_by(organism) %>%
    dplyr::summarize(tally=sum(tally)) %>%
    dplyr::arrange(desc(tally))

  merged$organism <- factor(merged$organism, levels=ord$organism)
  wide <- tidyr::spread(merged, key=label, value=tally, fill=0, drop=FALSE)

  ## omit organisms represented by zero reads after filtering
  wide <- wide[rowSums(wide[,-1]) > 0,]

  stopifnot(all(missing$label %in% colnames(wide)))
  write.csv(wide, file=args$wide, row.names=FALSE)
}

main(commandArgs(trailingOnly=TRUE))
invisible(warnings())

