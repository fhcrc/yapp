#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(RSQLite, quietly = TRUE))
suppressPackageStartupMessages(library(lattice, quietly = TRUE))
suppressPackageStartupMessages(library(latticeExtra, quietly = TRUE))

parser <- ArgumentParser()
parser$add_argument('pca_data', metavar='FILE.proj')
parser$add_argument(
    '--labels', help='specimen annotations; must have one column named "specimen" corresponding to the first column of pca_data',
    metavar='FILE.csv')
parser$add_argument('-o', '--outfile', metavar='FILE.{pdf,svg}')

args <- parser$parse_args()

specimens <- read.csv(args$labels, colClasses=c(specimen='character'))

pca_data <- read.csv(args$pca_data, header=FALSE)
colnames(pca_data) <- c('specimen', gettextf('pc%s', seq(ncol(pca_data) - 1)))
pca_data$specimen <- as.character(pca_data$specimen)


## setdiff(as.character(specimens$specimen), as.character(pca_data$specimen))
## setdiff(as.character(pca_data$specimen), as.character(specimens$specimen))

tab <- merge(pca_data, specimens, by='specimen', all.x=FALSE, all.y=TRUE)
tab <- within(tab, {
  antibiotic <- factor(ifelse(antibiotic == '', 'none', as.character(antibiotic)))
})

summary(tab)

pdf(args$outfile)
ff <- xyplot(pc2 ~ pc1,
             data=tab,
             par.settings=theEconomist.theme(),
             auto.key=list(space='right'),
             main='Length PCA'
             )
plot(ff)

ff <- xyplot(pc2 ~ pc1 | strain,
             groups=antibiotic,
             data=tab,
             par.settings=theEconomist.theme(),
             auto.key=list(space='right'),
             main='Length PCA'
             )
plot(ff)

ff <- xyplot(pc2 ~ pc1 | antibiotic,
             groups=strain,
             data=tab,
             par.settings=theEconomist.theme(),
             auto.key=list(space='right'),
             main='Length PCA'
             )
plot(ff)




## col_classes <- sapply(tab, class)
## for(colname in setdiff(colnames(specimens), 'specimen')){
##   if(col_classes[colname] %in% c('character', 'factor')){
##     tab$covariate <- tab[[colname]]
##     ff <- xyplot(pc2 ~ pc1,
##                  groups=covariate,
##                  data=tab,
##                  par.settings=theEconomist.theme(),
##                  ## xlim=xlim,
##                  ## ylim=ylim,
##                  auto.key=list(space='right'),
##                  main=colname
##                  )
##     plot(ff)
##   }
## }

dev.off()
