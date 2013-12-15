#!/usr/bin/env Rscript

library(argparse)
library(plotrix)
library(plyr)
library(stringr)

#####

filter.taxa <- function(df, max.taxa=3, min.ratio=0.05) {
  max.taxa <- min(nrow(df), max.taxa)
  ordered <- df[order(-df$tally)[1:max.taxa],]

  total.tally <- sum(ordered$tally)
  filtered <- NULL
  for (i in 1:nrow(ordered)) {
    row <- ordered[i,]
    if ((row$tally / total.tally) >= min.ratio) {
      filtered <- rbind(filtered, row)
    }
  }

  filtered
}

plot.taxa.pie <- function(x, taxa, size=1) {
  par(mar=c(12, 4, 2, 1) + 0.1)
  plot(0, xlim=range(x$pc1), ylim=range(x$pc2), xlab='First principal component', ylab='Second principal component', type='n')

  r = diff(range(x$pc1)) / (100 / size)
  for (i in 1:nrow(x)) {
    row <- x[i, ]

    t <- subset(taxa, specimen == row$specimen)
    if (nrow(t) == 0) {
      next
    }
    else if (nrow(t) == 1) {
      draw.circle(row$pc1, row$pc2, col=t[1,'color'], radius=r)
    } else {
      floating.pie(x=t$tally, xpos=row$pc1, ypos=row$pc2, col=t$color, radius=r)
    }
  }
  legend(x='bottom', fill=palette, legend=taxa.names, ncol=4, inset=c(0, -0.25), xpd=TRUE)
}

#####

parser <- ArgumentParser()
parser$add_argument('--input-dir')
parser$add_argument('--big-rectangle')
parser$add_argument('--size', type='double', default=0.75)
parser$add_argument('--invert-x', action='append')
parser$add_argument('--invert-y', action='append')

##args <- parser$parse_args(c('--input-dir', 'output/cf_named', '--big-rectangle', 'cf_named/groupBySpecimen.genus.csv'))
args <- parser$parse_args()

#####

csv <- list.files(path=args$input_dir, pattern='*.proj', full.names=TRUE)
df <- NULL

for (i in 1:length(csv)) {
  tokens <- str_match(csv[i], '([^/]+?)\\.proj')
  algorithm <- as.factor(tokens[2])

  csv.df <- read.csv(csv[i], header=TRUE, as.is=TRUE)
  csv.df$algorithm <- algorithm

  if (algorithm %in% args$invert_x) {
    csv.df$pc1 <- -csv.df$pc1
  }

  if (algorithm %in% args$invert_y) {
    csv.df$pc2 <- -csv.df$pc2
  }

  df <- rbind(df, csv.df)
}

bigrect <- read.csv(args$big_rectangle, header=TRUE)

#####

palette <- c("#91F5B5", "#F1A5E7", "#FDB364", "#59CDEB",
             "#C7FE6E", "#A8B266", "#F396A6", "#BCE3D2",
             "#BBC1F2", "#F0E54D", "#E3A17F", "#E1F698",
             "#F1CEE1", "#D9FEC4", "#42C384", "#D4D99B",
             "#79CDA3", "#53C1C6", "#43F2BA", "#BFDF62",
             "#F7BADE", "#A5F3E5", "#F0EB84", "#C5B0E9",
             "#FAA28D")

## the palette is sorted by descending discernability, so let's sort the taxa
## by descending abundance

taxa <- ddply(bigrect, ~ specimen, filter.taxa, max.taxa=3, min.ratio=0.10)
taxa.totals <- arrange(ddply(taxa, .(tax_name), summarize, total=sum(tally)), desc(total))
taxa.names <- taxa.totals$tax_name

palette <- palette[1:length(taxa.names)]
taxon.colors <- data.frame(tax_name=taxa.names, color=palette, stringsAsFactors=FALSE)
taxa <- merge(taxa, taxon.colors)

## pdf(file.path(args$input_dir, 'epca-pie.pdf'), paper='USr', width=0, height=0)
## plot.taxa.pie(subset(df, algorithm == 'epca'), taxa, size=args$size)
## title('Relative genera abundance per specimen (edge PCA)')
## dev.off()

## pdf(file.path(args$input_dir, 'lpca-pie.pdf'), paper='USr', width=0, height=0)
## plot.taxa.pie(subset(df, algorithm == 'lpca'), taxa, size=args$size)
## title('Relative genera abundance per specimen (length PCA)')
## dev.off()

svg(file.path(args$input_dir, 'epca-pie.svg'), width=16, height=12)
plot.taxa.pie(subset(df, algorithm == 'epca'), taxa, size=args$size)
title('Relative genera abundance per specimen (edge PCA)')
dev.off()

svg(file.path(args$input_dir, 'lpca-pie.svg'), width=16, height=12)
plot.taxa.pie(subset(df, algorithm == 'lpca'), taxa, size=args$size)
title('Relative genera abundance per specimen (length PCA)')
dev.off()
