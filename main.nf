import groovy.json.JsonSlurper

process cmalign {
  memory "32 GB"
  cpus 16

  input:
    path(seqs)
    path(profile)

  output:
    path("query.sto")
    path("cmalign.scores")

  publishDir "${params.output}/", overwrite: true, mode: "copy"

  """
  cmalign \
  --cpu 16 \
  --dnaout \
  --mxsize 8196 \
  --noprob \
  -o query.sto \
  --sfile cmalign.scores \
  ${profile} ${seqs}
  """
}

process alimerge {
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
  container "ghcr.io/nhoffman/dada2-nf:2.0.1"

  input:
    path(merged)

  output:
    path("clean.fasta")

  publishDir "${params.output}/", overwrite: true, mode: "copy"

  """
  clean_merged.py ${merged} clean.fasta
  """
}

process pplacer {
  input:
    path(merged)
    path(refpkg)

  output:
    path("dedup.jplace")

  publishDir "${params.output}/", overwrite: true, mode: "copy"

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
  input:
    path(placements)
    path(refpkg)
    path(merged)

  output:
    path("classified.db")

  publishDir "${params.output}/", overwrite: true, mode: "copy"

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
  input:
    path(db)

  output:
    path("classifications.csv")

  publishDir "${params.output}/", overwrite: true, mode: "copy"

  """
  get_classifications.py --classifications classifications.csv ${db}
  """
}

process tables {
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

  publishDir "${params.output}/", overwrite: true, mode: "copy"

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
  def jsonSlurper = new JsonSlurper()
  refpkg = jsonSlurper.parse(file(params.refpkg + "/CONTENTS.json"))
  if (params.containsKey("profile")) {
    profile = file(params.profile)
  } else {
    profile = file(params.refpkg + "/" + refpkg.files.profile)
  }
  if (params.containsKey("aln_sto")) {
    aln_sto = file(params.aln_sto)
  } else {
    aln_sto = file(params.refpkg + "/" + refpkg.files.aln_sto)
  }
  (query, _) = cmalign(file(params.seqs), profile)
  merged = clean_merged(alimerge(query, aln_sto))
  placements = pplacer(merged, channel.fromPath(params.refpkg))
  db = classify(placements, channel.fromPath(params.refpkg), merged)
  cls = classifications(db)
  (_, sv_table_long,_, _, _, lineages, sv_names, _) = tables(
    cls, file(params.specimen_map), file(params.weights))
}
