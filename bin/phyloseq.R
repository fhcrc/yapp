#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(tidyr, quietly = TRUE))
suppressPackageStartupMessages(library(ape, quietly = TRUE))
suppressPackageStartupMessages(library(phyloseq, quietly = TRUE))

DEBUG <- FALSE
if(DEBUG){ options(error=recover, width=150)}

title_case <- function(x){
  paste0(toupper(substr(x, 1, 1)), tolower(substring(x, 2)))
}

split_names <- function(names){
  sapply(strsplit(names, split=":"), "[", 1)
}

main <- function(arguments){
  parser <- ArgumentParser()
  parser$add_argument('--tree', help='newick format phylogenetic tree of SVs')
  parser$add_argument('--sv-table', help='SV table (long format)')
  parser$add_argument('--lineages', help='table of taxonomic lineages')
  parser$add_argument(
             '--annotation',
             help='specimen annotation with specimen names in column specimen')
  parser$add_argument(
             '--rds', default='phyloseq.rds',
             help='phyloseq object saved as R data - reload with phy <- readRDS(fname)')
  args <- parser$parse_args(arguments)

  ## phylogenetic tree; FastTree seems to truncate names to the first
  ## ":", so we'll need to do the same for the other data sources.
  ## TODO: normalize names in the input

  tre <- ape::read.tree(args$tree)

  # otu table
  sv_tab <- read.csv(args$sv_table, as.is=TRUE)
  otutab <- sv_tab %>%
    select(specimen, name, read_count) %>%
    tidyr::spread(key=specimen, value=read_count, fill=0)
  rownames(otutab) <- split_names(otutab$name)
  otutab$name <- NULL

  ## taxonomic table; the only public method I could find takes a
  ## list of lineages as input, but I can't figure out how to convert
  ## the table of lineages to this form without an error. Not sure if
  ## phyloseq::tax_table() is a private method, but it seems to
  ## provide the intended result.
  lineages <- read.csv(args$lineages, as.is=TRUE, na.strings="")

  ranks <- c("superkingdom",
             "phylum",
             "class",
             "order",
             "family",
             "genus",
             "species_group",
             "species")

  ## restrict to ranks represented among lineages
  ranks <- intersect(ranks, colnames(lineages))

  lintab <- cbind(rep("Root", nrow(lineages)), lineages[,ranks])
  colnames(lintab) <- c("Root", title_case(ranks))
  rownames(lintab) <- split_names(lineages$name)

  stopifnot(setequal(tre$tip.label, rownames(otutab)))
  stopifnot(setequal(tre$tip.label, rownames(lintab)))
  stopifnot(setequal(rownames(otutab), rownames(lintab)))

  phy <- phyloseq(
      phyloseq::otu_table(otutab, taxa_are_rows=TRUE),
      tre,
      phyloseq::tax_table(as.matrix(lintab))
  )

  ## add sample_data if annotation is provided
  if(!is.null(args$annotation)){
    annotation <- read.csv(args$annotation, as.is=TRUE, na.strings="")
    stopifnot("specimen" %in% colnames(annotation))
    rownames(annotation) <- annotation$specimen
    annotation <- annotation[colnames(otutab),]
    sample_data(phy) <- phyloseq::sample_data(annotation)
  }

  saveRDS(phy, file=args$rds)

}

main(commandArgs(trailingOnly=TRUE))
if(DEBUG){debugger()}
warnings()


