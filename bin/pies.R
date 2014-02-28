#!/usr/bin/env Rscript

library(argparse, quietly=TRUE)
library(plotrix, quietly=TRUE)
library(plyr, quietly=TRUE)
library(stringr, quietly=TRUE)

palette <- c("#91F5B5", "#F1A5E7", "#FDB364", "#59CDEB",
             "#C7FE6E", "#A8B266", "#F396A6", "#BCE3D2",
             "#BBC1F2", "#F0E54D", "#E3A17F", "#E1F698",
             "#F1CEE1", "#D9FEC4", "#42C384", "#D4D99B",
             "#79CDA3", "#53C1C6", "#43F2BA", "#BFDF62",
             "#F7BADE", "#A5F3E5", "#F0EB84", "#C5B0E9",
             "#FAA28D")

## the palette is sorted by descending discernability

get_device <- function(fname, ...){

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
}

plot_pies <- function(pca_data, classif, levels, subset, pie_cex=1){
  ## 'mgp' The margin line (in 'mex' units) for the axis title, axis
  ##      labels and axis line.  Note that 'mgp[1]' affects 'title'
  ##      whereas 'mgp[2:3]' affect 'axis'.  The default is 'c(3, 1,
  ##      0)'.

  if(missing(subset)){
    subset <- seq(nrow(pca_data))
  }

  par(mar=c(bottom=8, left=4, top=2, right=1) + 0.1,
      mgp=c(2, 1, 0))

  plot(0, xlim=range(pca_data$pc1), ylim=range(pca_data$pc2),
       xlab='First principal component',
       ylab='Second principal component', type='n')

  with(pca_data, {
    radius <- pie_cex * diff(range(pc1))/100
    specimens <- as.character(specimen)
    for(i in seq_along(specimens)){
      if(i %in% subset){
        specimen <- specimens[i]
        dat <- classif[[specimen]]
        if(nrow(dat) == 1){
          draw.circle(pc1[i], pc2[i], col=palette[dat$tax_name], radius=radius)
        }else{
          floating.pie(x=dat$freq, xpos=pc1[i], ypos=pc2[i], col=palette[dat$tax_name], radius=radius)
        }
      }
    }
    legend(x='bottom', fill=palette[seq_along(levels)],
           legend=levels,
           ncol=3,
           bty='n',
           cex=0.75,
           inset=c(0, -0.33),
           xpd=TRUE)
  })

}

parser <- ArgumentParser()
parser$add_argument('pca_data', metavar='FILE.proj')
parser$add_argument('by_specimen', help='classification results', metavar='FILE.csv')
parser$add_argument('outfiles', help='output file', metavar='FILE.pdf',
                    default=c('pies.pdf', 'pies.svg'), nargs = '*')

args <- parser$parse_args()

pca_data <- read.csv(args$pca_data, header=FALSE)
colnames(pca_data) <- c('specimen', gettextf('pc%s', seq(ncol(pca_data) - 1)))

by_specimen <- read.csv(args$by_specimen, colClasses=list(tax_name='character'))
outfiles <- args$outfiles

by_specimen <- read.csv(args$by_specimen, colClasses=list(tax_name='character'))

## ## clean up some classifications
## ## TODO - clean up classifications elsewhere
## replacements <- list(
##     c('Enterobacteriaceae',
##       'Enterobacter|Escherichia|Shigella')
##     )

## for(repl in replacements){
##   by_specimen$tax_name <- with(by_specimen, ifelse(grepl(repl[2], tax_name), repl[1], tax_name))
## }

## aggregate by simplified names
## renamed <- aggregate(freq ~ specimen + tax_name, by_specimen, sum)

renamed <- by_specimen

## order tax_names by decreasing average prevalence and choose the top N
prevalence <- aggregate(freq ~ tax_name, renamed, median)
keep_n <- 15
most_prevalent <- with(prevalence, tax_name[order(freq, decreasing=TRUE)])[1:keep_n]

## split by specimen, order by freq desc, collapse all but tax_names
## in most_prevalent into "other" category
other <- 'other'
levels <- c(most_prevalent, other)

renamed$tax_name[!renamed$tax_name %in% most_prevalent] <- other
freqs <- aggregate(freq ~ specimen + tax_name, renamed, sum)
classif <- lapply(split(freqs, freqs$specimen), function(s){
  s$tax_name <- factor(s$tax_name, levels=levels, ordered=TRUE)
  s[order(s$freq, decreasing=TRUE),]
})
## classtab <- do.call(rbind, classif)
## rownames(classtab) <- NULL

for(o in outfiles) {
  get_device(o)
  plot_pies(pca_data, classif, levels)
  dev.off()
}
