#!/usr/bin/env Rscript

if(Sys.getenv("VIRTUAL_ENV") == ""){ stop("An active virtualenv is required") }
source(file.path(Sys.getenv('VIRTUAL_ENV'), 'bin', 'rvenv'))

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(RSQLite, quietly = TRUE))
suppressPackageStartupMessages(library(lattice, quietly = TRUE))
suppressPackageStartupMessages(library(latticeExtra, quietly = TRUE))

parser <- ArgumentParser()
parser$add_argument('placements_db')
parser$add_argument('-o', '--outfile', default='plot_adcl.pdf')

args <- parser$parse_args()

con <- dbConnect(dbDriver("SQLite"), dbname=args$placements_db)

ranks <- dbGetQuery(con, 'select * from ranks order by rank_order desc')$rank

pdf(args$outfile, width=8.5, height=11)

cmd <- "
select t.tax_name, mc.*, a.adcl, a.weight
from multiclass_concat mc
join adcl a using(name)
join taxa t using(tax_id)
where want_rank = 'species'
order by rank, adcl
"

tab <- dbGetQuery(con, cmd)

## aggregate by OTU
tab$otu <- sapply(strsplit(tab$name, split=':'), '[', 1)

data <- aggregate(weight ~ otu + tax_name + want_rank + tax_id + rank + likelihood + adcl, tab, sum)
data$label <- factor(with(data, gettextf('%s | %s', tax_name, rank)))
data$abundance <- cut(log10(data$weight), breaks=seq(1, ceiling(log10(max(data$weight)))))

## distribution by rank
by_rank <- aggregate(weight ~ rank, data, sum)
by_rank$pct <- round(with(by_rank, 100 * weight/sum(weight)), 2)
print(by_rank)

keep <- unique(with(data, tax_name[adcl > 0.05 & weight > 100]))
data <- data[data$tax_name %in% keep,]

labelnums <- as.numeric(data$label)
for(spl in split(data, cut(labelnums, c(seq(0, max(labelnums), by=50), Inf)))){
  ff <- stripplot(label ~ adcl,
                  groups=abundance,
                  auto.key=list(title='log10(weight)'),
                  data=spl,
                  ## par.settings=theEconomist.theme(),
                  xlim=c(-0.05, max(data$adcl)),
                  as.table=TRUE,
                  jitter=TRUE
                  )
  plot(ff)
}

dev.off()
