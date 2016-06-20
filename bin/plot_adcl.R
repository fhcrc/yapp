#!/usr/bin/env Rscript

if(Sys.getenv("VIRTUAL_ENV") == ""){ stop("An active virtualenv is required") }
source(file.path(Sys.getenv("VIRTUAL_ENV"), "bin", "rvenv"))

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

data <- do.call(rbind, lapply(split(tab, tab$rank), function(r){
  r$cumsum <- cumsum(r$weight)
  r$cumfreq <- r$cumsum/sum(r$weight)
  r
}))
data$rank <- factor(data$rank, ordered=TRUE, levels=ranks)

ff <- xyplot(cumfreq ~ adcl | factor(rank, ordered=TRUE, levels=ranks), data=data,
             ## groups=rank,
             type='l',
             ## auto.key=list(space='right'),
             as.table=TRUE,
             par.settings=theEconomist.theme()
             )
plot(ff)

## distribution by rank
by_rank <- aggregate(weight ~ rank, data, sum)
by_rank$pct <- round(with(by_rank, 100 * weight/sum(weight)), 2)
print(by_rank)

idx <- with(data, rep(seq(length(weight)), weight))
reduped <- data[idx, c('tax_name', 'tax_id', 'rank', 'adcl')]
## reduped$label <- with(reduped, gettextf('%s | %s', tax_name, rank))
## reduped$label <- factor(reduped$label, ordered=TRUE,
##                         levels=with(aggregate(adcl ~ label, reduped, median), label[order(adcl)]))

reduped$label <- factor(with(reduped, gettextf('%s | %s', tax_name, rank)))

labelnums <- as.numeric(reduped$label)
for(spl in split(reduped, cut(labelnums, c(seq(0, max(labelnums), by=60), Inf)))){
  ff <- bwplot(label ~ adcl,
               data=spl,
               par.settings=theEconomist.theme(),
               xlim=c(0, max(reduped$adcl)),
               as.table=TRUE
               )
  plot(ff)
}

dev.off()
