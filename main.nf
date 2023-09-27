process cmalign {
  container 'ghcr.io/nhoffman/dada2-nf:2.0.1'
  label 'c5d_2xlarge'

  input:
    path(seqs)
    path(profile)

  output:
    path("query.sto")
    path("cmalign.scores")

  publishDir "${params.output}/", overwrite: true, mode: 'copy'

  """
  cmalign \
  --cpu 20 \
  --dnaout \
  --mxsize 8196 \
  --noprob \
  -o query.sto \
  --sfile cmalign.scores \
  ${profile} ${seqs}
  """
}

process alimerge {
  container 'ghcr.io/nhoffman/dada2-nf:2.0.1'

  input:
    path(query)
    path(ref)

  output:
    path("merged.fasta")

  """
  esl-alimerge --dna --outformat afa -o merged.fasta ${ref} ${query}
  """
}

process clean_merged {
  container 'ghcr.io/nhoffman/dada2-nf:2.0.1'

  input:
    path(merged)

  output:
    path("clean.fasta")

  publishDir "${params.output}/", overwrite: true, mode: 'copy'

  """
  clean_merged.py ${merged} clean.fasta
  """
}

process pplacer {
  container 'ghcr.io/fhcrc/taxtastic:v0.10.1'

  input:
    path(merged)
    path(refpkg)

  output:
    path("dedup.jplace")

  publishDir "${params.output}/", overwrite: true, mode: 'copy'

  """
  pplacer \
  --inform-prior \
  --map-identity \
  --prior-lower 0.01 \
  -c ${refpkg} ${merged} \
  -j 20 \
  -o dedup.jplace \
  -p
  """
}

process classify {
  container 'ghcr.io/fhcrc/taxtastic:v0.10.1'

  input:
    path(placements)
    path(refpkg)
    path(merged)

  output:
    path("classified.db")

  publishDir "${params.output}/", overwrite: true, mode: 'copy'

  """
  rppr prep_db -c ${refpkg} --sqlite classified.db
  guppy classify \
  --classifier hybrid2 \
  --nbc-sequences ${merged} \
  --pp \
  --sqlite classified.db \
  -c ${refpkg} \
  -j 20 \
  ${placements}
  """
}

process classifications {
  container 'ghcr.io/fhcrc/taxtastic:v0.10.1'

  input:
    path(db)

  output:
    path("classifications.csv")

  publishDir "${params.output}/", overwrite: true, mode: 'copy'

  """
  get_classifications.py --classifications classifications.csv ${db}
  """
}

process tables {
  container 'ghcr.io/nhoffman/dada2-nf:2.0.1'

  input:
    path(classifications)
    path(specimen_map)
    path(weights)

  output:
    path("sv_table.csv")
    path("sv_table_long.csv")
    path("taxon_table.csv")
    path("taxon_table_rel.csv")
    path("taxon_table_long.csv")
    path("lineages.csv")
    path("sv_names.txt")
    path("removed.csv")

  publishDir "${params.output}/", overwrite: true, mode: 'copy'

  """
  sv_table.R \
  --min-reads 0 \
  --classif ${classifications} \
  --specimens ${specimen_map} \
  --weights ${weights} \
  --by-sv sv_table.csv \
  --by-sv-long sv_table_long.csv \
  --by-taxon taxon_table.csv \
  --by-taxon-rel taxon_table_rel.csv \
  --by-taxon-long taxon_table_long.csv \
  --lineages lineages.csv \
  --sv-names sv_names.txt \
  --removed removed.csv
  """
}

workflow {
  (query, _) = cmalign(file(params.seqs), file(params.profile))
  merged = clean_merged(alimerge(query, file(params.aln_sto)))
  placements = pplacer(merged, channel.fromPath(params.refpkg))
  db = classify(placements, channel.fromPath(params.refpkg), merged)
  cls = classifications(db)
  (_, sv_table_long,_, _, _, lineages, sv_names, _) = tables(
    cls, file(params.specimen_map), file(params.weights))
}
