#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(RSQLite, quietly = TRUE))
suppressPackageStartupMessages(library(reshape, quietly = TRUE))
suppressPackageStartupMessages(library(lattice, quietly = TRUE))
suppressPackageStartupMessages(library(latticeExtra, quietly = TRUE))
suppressPackageStartupMessages(library(argparse, quietly = TRUE))

get_device <- function(fname, ff, ...){

  print(fname)

  if(grepl('\\.pdf$', fname)){
    device <- pdf
  }else if(grepl('\\.svg$', fname)){
    device <- svg
  }else if(grepl('\\.png$', fname)){
    device <- png
  }else if(grepl('\\.jpg$', fname)){
    device <- jpeg
  }else{
    stop(gettextf('Cannot guess device for %s', fname))
  }

  device(fname, ...)
  plot(ff)
  invisible(dev.off())
}

my.theme <- function(...){
  theme <- ggplot2like(...)
  theme$panel.background$col = 'white'
  theme$axis.line$col = 'grey50'
  theme$reference.line$col = 'grey80'
  theme
}

abbrev <- function(v){
  sapply(strsplit(v, split=' '), function(x){
    gettextf('%s. %s', substr(x[1],1,1), x[2])
  })
}

main <- function(arguments){

  parser <- ArgumentParser()
  parser$add_argument('by_specimen', help='classification results', metavar='FILE.csv')
  parser$add_argument('-a', '--annotation', help='Specimen annotation; must contain a column named "specimen"',
                      metavar='FILE.csv')
  parser$add_argument('-c', '--covariates', metavar='COLNAMES',
                      help='Colon-delimited list of column names in annotation.')
  parser$add_argument('-o', '--output', metavar='FILE.pdf ...',
                      help='output file name with format specified by suffix ["%(default)s"]',
                      default='buildings.pdf', nargs = '*')
  parser$add_argument('-m', '--min-freq', metavar='FLOAT', default=0.01, type='double',
                      help='Taxonomic names below this frequency will be collapsed into "other" [%(default)s]')
  parser$add_argument('-t', '--title', default='Relative abundance of most frequent species')

  args <- parser$parse_args(arguments)
  by_specimen <- read.csv(args$by_specimen)
  annotation <- read.csv(args$annotation, as.is=TRUE)
  min_freq <- args$min_freq
  covariates <- strsplit(args$covariates, ':')[[1]]

  options(width=200)

  tallies <- merge(by_specimen, annotation[,c('specimen', covariates)], by='specimen')

  if(length(covariates) > 1){
    tallies$covariates <- apply(tallies[,covariates], 1, paste, collapse=':')
  }else{
    tallies$covariates <- tallies[[covariates]]
  }

  agg <- aggregate(freq ~ covariates + tax_name, tallies, median)

  # collapse categories below min_freq
  agg$tax_name <- with(agg, ifelse(freq < min_freq, gettextf('(frequency < %s)', min_freq), as.character(tax_name)))
  data <- aggregate(freq ~ covariates + tax_name, agg, sum)

  ## re-normalize so that frequencies sum to 1.0
  total_freqs <- sapply(with(data, split(freq, covariates)), sum)
  data$freq <- with(data, freq/total_freqs[covariates])

  levels <- sort(sapply(with(data, split(freq, tax_name)), mean), decreasing=TRUE)
  data$tax_name <- factor(data$tax_name, levels=names(levels), ordered=TRUE)

  ff <- barchart(tax_name ~ freq | covariates,
                 ## groups=covariates,
                 data=data,
                 ## stack=TRUE,
                 auto.key=TRUE,
                 axis=axis.grid,
                 par.settings=my.theme(),
                 main=args$title,
                 sub=gettextf('covariates: %s', args$covariates)
                 )

  ## ff <- barchart(covariates ~ freq,
  ##                groups=tax_name,
  ##                data=data,
  ##                stack=TRUE,
  ##                auto.key=list(space='right', reverse.rows=TRUE),
  ##                par.settings=my.theme()
  ##                )

  for(fname in args$output){
    get_device(fname, ff)
  }

}

main(commandArgs(trailingOnly=TRUE))
warnings()

