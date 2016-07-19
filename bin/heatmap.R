#!/usr/bin/env Rscript

if(Sys.getenv("VIRTUAL_ENV") == ""){
  stop("An active virtualenv is required")
}
source(file.path(Sys.getenv('VIRTUAL_ENV'), 'bin', 'rvenv'))

required <- c('argparse', 'data.table', 'ape',
              'tidyr', 'lattice', 'latticeExtra')

invisible(sapply(required, function(lib){
  library(lib, character.only=TRUE, quietly=TRUE)}))

my.theme <- function(...){
  theme <- ggplot2like(...)
  theme$panel.background$col = 'white'
  theme$axis.line$col = 'grey50'
  theme$reference.line$col = 'grey80'
  theme
}

main <- function(arguments){
  parser <- ArgumentParser()
  parser$add_argument(
      'by_specimen', help='classification results', metavar='FILE.csv')
  parser$add_argument(
      'treefile', help='output of guppy squash', metavar='FILE.tre')
  parser$add_argument(
      '-a', '--annotation', metavar='FILE.csv',
      help='Specimen annotation; must contain a column named "specimen"')
  parser$add_argument(
      '-c', '--covariates', metavar='COLNAMES',
      help='Colon-delimited list of column names in annotation.')
  parser$add_argument(
      '-o', '--outfile', metavar='FILE.pdf ...', default='heatmap.pdf', nargs = '*',
      help='output file name with format specified by suffix ["%(default)s"]')
  parser$add_argument(
      '-m', '--min-rank-abundance', metavar='FLOAT', default=30, type='integer',
      help='Taxonomic names below this rank abundance will be collapsed into "other" [%(default)s]')
  parser$add_argument('-t', '--title',
                      default='Relative abundance of most frequent species')
  args <- parser$parse_args(arguments)

  tre <- ape::read.tree(args$treefile)
  ## make tree ultrametric
  ## see http://bodegaphylo.wikispot.org/ii._tree_basics
  hc = as.hclust(chronopl(tre, lambda=0.1))
  dend <- as.dendrogram(hc)
  tree_order <- labels(dend)

  annotation <- read.csv(args$annotation, as.is=TRUE)

  tallies <- data.table::fread(
      args$by_specimen, colClasses=c(tax_id='character'))
  tallies <- tallies[tallies$specimen %in% annotation$specimen,]

  ## order organisms by rank and limit to top N
  tallies <- do.call(rbind,
                     lapply(split(tallies, tallies$specimen), function(specimen){
                       specimen$rank_order <- order(specimen$tally, decreasing=TRUE)
                       specimen
                     }))
  ranks <- aggregate(rank_order ~ tax_name, tallies, median)
  ranks <- ranks[order(ranks$rank_order),]
  keep <- head(ranks$tax_name, args$min_rank_abundance)
  collapsed <- '(other low abundance organisms)'
  tallies$tax_name <- with(tallies, ifelse(tax_name %in% keep, tax_name, collapsed))

  ## collapse '(other)'
  data <- aggregate(tally ~ specimen + tax_name, tallies, sum)

  ## calculate relative abundances for each specimen
  totals <- aggregate(tally ~ specimen, data, sum)
  matches <- match(data$specimen, totals$specimen)
  data$abundance <- data$tally/totals$tally[matches]

  ## ensure that abundances sum to (approximately) 1 in each specimen
  stopifnot(all(sapply(with(data, split(abundance, specimen)),
                       function(x){all.equal(sum(x), 1)})))

  ## order organisms by abundance, putting collapsed category last
  data$tax_name <- factor(data$tax_name, levels=c(keep, collapsed), ordered=TRUE)

  ## place specimens in tree order
  data$specimen <- factor(data$specimen, levels=tree_order, ordered=TRUE)

  ## place annotation in tree order
  annotation <- annotation[charmatch(tree_order, annotation$specimen),]
  stopifnot(all(annotation$specimen == tree_order))

  wide <- spread(data[,c('specimen', 'tax_name', 'abundance')],
                 key=specimen, value=abundance, fill=0)
  mat <- as.matrix(wide[,-1])

  mat <- rbind(
      mat,
      with(annotation, ifelse(category == 'symptomatic', 1, 0))
  )
  rownames(mat) <- c(as.character(wide$tax_name), 'symptoms')

  pdf(args$outfile, width=11, height=8.5)
  ## see http://stackoverflow.com/questions/6673162/reproducing-lattice-dendrogram-graph-with-ggplot2
  ff <- levelplot(t(mat),
                  panel=function(...){
                    panel.levelplot(
                        ...,
                        colorkey=list(space='right')
                    )
                    panel.abline(h=nrow(mat) - 0.5, ...)
                  },
                  ## scales=list(x=list(at=NULL)),
                  scales=list(x=list(rot=90, cex=0.5, alternating=3)),
                  aspect="fill",
                  legend=list(top=list(fun=latticeExtra::dendrogramGrob,
                                       args=list(
                                           x=dend,
                                           add=list(
                                               rect=with(annotation,
                                                         list(
                                                             fill=ifelse(category == 'symptomatic',
                                                                         'black', 'white')))
                                           ),
                                           side='top',
                                           size=5))
                              ),
                  xlab='specimen',
                  ylab='organism',
                  par.settings=my.theme()
                  )
  plot(ff)

  invisible(dev.off())

}

main(commandArgs(trailingOnly=TRUE))
## invisible(warnings())

