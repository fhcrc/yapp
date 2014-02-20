#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(RSQLite, quietly = TRUE))
suppressPackageStartupMessages(library(lattice, quietly = TRUE))
suppressPackageStartupMessages(library(latticeExtra, quietly = TRUE))

parser <- ArgumentParser()
parser$add_argument('pca_data', metavar='FILE.proj')
parser$add_argument(
    'specimen_db', help='sqlite db containing patient and specimen data',
    metavar='FILE.db')

args <- parser$parse_args()

con <- dbConnect(dbDriver("SQLite"), dbname=args$specimen_db)
cmd <- "
select specimen, specimen_number, collection_date, patient_code,
dob, sex, is_cf, cf_mutation
from barcode_map
join barcodes using(specimen_number)
join specimens using(specimen_number)
join patients using(patient_code)
where orientation='combined'
and ntc=0 and exclude=0
order by patient_code, collection_date
"

specimens <- dbGetQuery(con, cmd)

pca_data <- read.csv(args$pca_data, header=FALSE)
colnames(pca_data) <- c('specimen', gettextf('pc%s', seq(ncol(pca_data) - 1)))

## setdiff(as.character(specimens$specimen), as.character(pca_data$specimen))
## setdiff(as.character(pca_data$specimen), as.character(specimens$specimen))

tab <- merge(pca_data, specimens, by='specimen', all.x=FALSE, all.y=TRUE)
tab <- within(tab, {
  is_cf <- factor(ifelse(is_cf == 1, 'yes', 'no'))
  cf_mutation <- factor(cf_mutation)
  patient_code <- factor(gettextf('pat%02i', patient_code))
})

summary(tab)

xlim <- c(-0.5, 0.25)
ylim <- c(-0.16, 0.10)

pdf('lpca.pdf')
ff <- xyplot(pc2 ~ pc1, data=tab,
             groups=is_cf,
             par.settings=theEconomist.theme(),
             xlim=xlim, ylim=ylim,
             auto.key=list(space='right'),
             main='CF status'
             )
plot(ff)

for(patient in split(tab, tab$patient_code)){
  if(nrow(patient) > 4){
    ff <- xyplot(pc2 ~ pc1, data=patient,
                 type='b',
                 par.settings=theEconomist.theme(),
                 xlim=xlim, ylim=ylim,
                 auto.key=list(space='right'),
                 main=as.character(patient$patient_code[1]),
                 sub=gettextf('has CF: %s', patient$is_cf)
                 )
    plot(ff)
  }
}

dev.off()
