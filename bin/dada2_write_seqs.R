#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
## suppressPackageStartupMessages(library(tidyr, quietly = TRUE))
## suppressPackageStartupMessages(library(plyr, quietly = TRUE))


load_obj <- function(f){
  ## load a single arbitrary object from an .rda file
  env <- new.env()
  nm <- load(f, env)[1]
  env[[nm]]
}

main <- function(arguments){parser <- ArgumentParser()
  parser$add_argument('seq_info', help='csv file itemizing files and specimens')
  parser$add_argument(
             '--seqs', help='fasta file containing sequence variants',
             default='dada2_sv.fasta')
  parser$add_argument(
             '--sv-table', default='dada2_sv_table.csv',
             help='csv file with svs in rows and specimens in columns')
  parser$add_argument(
             '--weights', default='dada2_weights.csv',
             help='csv file with columns sv,sv-specimen,weight')
  parser$add_argument(
             '--specimen-map', default='dada2_specimen_map.csv',
             help='csv file with columns seqname,specimen')
  parser$add_argument(
             '--sv-table-long', default='dada2_sv_table_long.csv',
             help='"long" format csv file with columns specimen,count,sv,representative')
  args <- parser$parse_args(arguments)

  seq_info <- read.csv(args$seq_info, as.is=TRUE)

  infiles <- unlist(sapply(
      unique(seq_info$path),
      function(path){
        Sys.glob(file.path(dirname(path), 'batch_[1-9]/seqtab_nochim.rda'))
      },
      USE.NAMES=FALSE))

  seqtabs <- lapply(infiles, load_obj)
  long <- do.call(rbind, lapply(seqtabs, as.data.frame.table, stringsAsFactors=FALSE))
  colnames(long) <- c('specimen', 'seq', 'count')

  ## remove rows corresponding to sequences that do not occur in a
  ## given specimen
  long <- long[long$count > 0,]

  ## limit to non-controls
  ## specimens <- with(seq_info, specimen[nchar(controls) == 0])

  ## limit to actual specimens (ie, not extra barcodes)
  specimens <- with(seq_info, specimen[nchar(label) > 0])
  long <- long[long$specimen %in% specimens,]

  ## identify unique sequences
  totals <- aggregate(count ~ seq, long, sum)
  totals <- totals[order(totals$count, decreasing=TRUE),]

  ## determine number of characters to zero-pad sv labels, and name
  ## sequence variants so that higher-abundance reads have lower
  ## numbers
  padchars <- ceiling(log10(nrow(totals) + 1))
  totals$sv <- gettextf(paste0('sv-%0', padchars, 'i'), seq(nrow(totals)))

  ## vector of sequences named by sv
  seqs <- with(totals, setNames(seq, sv))

  ## vector of sv labels named by sequence
  seqinv <- with(totals, setNames(sv, seq))

  ## replace sequences with sv names
  long$sv <- seqinv[long$seq]
  long$seq <- NULL

  ## reorder by sv name then count
  long <- long[order(long$sv, -long$count),]

  ## construct a 'representative' identifying a read to serve as a
  ## representative of each sv - this is simply the first seqname
  ## representing each sv
  reps <- with(long, setNames(specimen, sv)[!duplicated(sv)])
  reps <- setNames(paste0(names(reps), ':', reps), names(reps))
  long$representative <- reps[long$sv]

  weights <- with(long,
                  data.frame(
                      representative=reps[sv],
                      seqname=paste0(sv, ':', specimen),
                      count=count
                  ))

  write.table(weights, row.names=FALSE, col.names=FALSE,
              quote=FALSE, sep=',', file=args$weights)

  specimen_map <- with(long,
                       data.frame(
                           seqname=paste0(sv, ':', specimen),
                           specimen=specimen
                       ))

  write.table(specimen_map, row.names=FALSE, col.names=FALSE,
              quote=FALSE, sep=',', file=args$specimen_map)

  mat <- reshape2::acast(long, sv ~ specimen, value.var="count", fill=0)
  ## include a value in the header for the first column
  tab <- cbind(data.frame(sv=rownames(mat)), as.data.frame(mat))
  write.csv(tab, file=args$sv_table, quote=FALSE, row.names=FALSE)

  write.csv(long, file=args$sv_table_long, row.names=FALSE)

  conn <- file(args$seqs)
  ## make sure all sequences names are in `reps`
  stopifnot(!any(is.na(reps[names(seqs)])))
  writeLines(gettextf('>%s\n%s', reps[names(seqs)], seqs), conn)
  close(conn)
}

main(commandArgs(trailingOnly=TRUE))
## invisible(warnings())

