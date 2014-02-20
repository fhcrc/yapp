#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(lattice, quietly = TRUE))
suppressPackageStartupMessages(library(latticeExtra, quietly = TRUE))

parser <- ArgumentParser()
parser$add_argument('pca_data', metavar='FILE.proj')
parser$add_argument('annotation', help='annotation data', metavar='FILE.csv')
parser$add_argument('-o', '--outfile', help='pdf output', metavar='FILE.pdf',
                    default='plot_lpca.pdf')
parser$add_argument('--fields', help='comma-delimited list of fields to annotate')


args <- parser$parse_args()

specimens <- read.csv(args$annotation)
pca_data <- read.csv(args$pca_data, header=FALSE)
colnames(pca_data) <- c('specimen', gettextf('pc%s', seq(ncol(pca_data) - 1)))

## setdiff(as.character(specimens$specimen), as.character(pca_data$specimen))
## setdiff(as.character(pca_data$specimen), as.character(specimens$specimen))

tab <- merge(pca_data, specimens, by='specimen', all.x=TRUE, all.y=FALSE)
tab$drug <- ifelse(tab$metformin == 'yes', 'metformin', 'no drug')

summary(tab)

pdf(args$outfile)
ff <- xyplot(pc2 ~ pc1 | diet + drug, data=tab,
             groups=paste(tab$drug, tab$diet),
             par.settings=theEconomist.theme(),
             auto.key=list(space='right'),
             grid=TRUE,
             drop.unused=TRUE,
             ## main='diet'
             )
plot(ff)
dev.off()
