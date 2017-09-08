#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(argparse, quietly = TRUE))
suppressPackageStartupMessages(library(rmarkdown, quietly = TRUE))

main <- function(arguments){
  parser <- ArgumentParser()
  parser$add_argument('infile')
  parser$add_argument('-o', '--outfile')
  parser$add_argument('-f', '--format', choices=c('html', 'pdf', 'all'),
                      default='html', help='output format [default %(default)s]')
  parser$add_argument('-e', '--extra-args',
                      help='quoted string of ignored extra arguments')
  args <- parser$parse_args(arguments)

  format <- if(args$format == 'all'){
              'all'
            }else{
              gettextf('%s_document', args$format)
            }

  rmarkdown::render(
      args$infile,
      output_file=args$outfile,
      output_format=format)

}

main(commandArgs(trailingOnly=TRUE))
## invisible(warnings())


