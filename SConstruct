"""
Project template for miseq pplacer pipeline.

usage::

  scons [scons-args] -- settings.conf [user-args]
"""

import os
import sys
import argparse
from os import path, environ
from pkg_resources import parse_version

import SCons
from SCons.Script import (Variables, Decider, AlwaysBuild, Flatten, Depends,
                          AllowSubstExceptions, Copy)

# requirements installed in the virtualenv
from bioscons.fileutils import Targets
from bioscons.slurm import SlurmEnvironment

import common

########################################################################
########################  input data  ##################################
#######################################################################

user_args, conf = common.get_conf('settings.conf')
settings = user_args[0]

thisdir = path.basename(os.getcwd())

# Ensure that we are using a virtualenv, and that we are using the one
# specified in the config if provided.
venv = path.abspath(conf['DEFAULT'].get('virtualenv') or 'yapp-env')

if not path.exists(venv):
    sys.exit('virtualenv {} does not exist; try\n'
             '--> bin/setup.sh'.format(venv))
elif 'VIRTUAL_ENV' not in environ:
    sys.exit('virtual env {venv} is not active; try\n'
             '--> source {venv}/bin/activate'.format(venv=venv))
elif environ['VIRTUAL_ENV'] != venv:
    sys.exit('expected virtualenv {} but {} is active'.format(
        venv, environ['VIRTUAL_ENV']))

# TODO: move to bioscons
min_scons_version = '3.0.1'
if parse_version(SCons.__version__) < parse_version(min_scons_version):
    sys.exit('requires scons version {} (found {})'.format(min_scons_version, SCons.__version__))

# define parser and parse arguments following '--'
parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument(
    'config', help="configuration file [%(default)s]",
    nargs='*', default=settings)
parser.add_argument(
    '--outdir', help='output directory [%(default)s]',
    default=conf['output'].get('outdir', 'output'))
parser.add_argument(
    '--nproc', type=int, default=20,
    help='number of processes for parallel tasks')

scons_args = parser.add_argument_group('scons options')
scons_args.add_argument(
    '--sconsign-in-outdir', action='store_true', default=False,
    help="""store file signatures in a separate
    .sconsign file in the output directory""")

slurm_args = parser.add_argument_group('slurm options')
slurm_args.add_argument(
    '--use-slurm', action='store_true', default=False)
slurm_args.add_argument(
    '--slurm-account', help='provide a value for environment variable SLURM_ACCOUNT')

args = parser.parse_args(user_args)

# required inputs (config file only)
input = conf['input']
refpkg = input['refpkg']
seqs = input['seqs']
specimen_map = input['specimen_map']
weights = input['weights']
labels = input['labels']

refs = conf['refs']
ref_taxonomy = refs.get('ref_taxonomy')
ref_info = refs.get('ref_info')

# for sv_table.R
min_reads = int(input.get('min_reads')) if input.get('min_reads') else 0
taxdb = input.get('taxdb')
to_rename = input.get('to_rename')
to_remove = input.get('to_remove')

singularity = conf['singularity'].get('singularity', 'singularity')
deenurp_img = conf['singularity']['deenurp']
dada2_img = conf['singularity']['dada2']
binds = [os.path.abspath(pth)
         for pth in conf['singularity']['binds'].strip().splitlines()]

outdir = args.outdir

########################################################################
#########################  end input data  #############################
########################################################################

# check timestamps before calculating md5 checksums
Decider('MD5-timestamp')

# declare variables for the environment
vars = Variables()
vars.Add('out', None, args.outdir)
vars.Add('nproc', None, args.nproc)
vars.Add('venv', None, venv)

# Explicitly define PATH, giving preference to local executables; it's
# best to use absolute paths for non-local executables rather than add
# paths here to avoid accidental introduction of external
# dependencies.
env = SlurmEnvironment(
    ENV=dict(
        os.environ,
        PATH=':'.join(['bin', path.join(venv, 'bin'),
                       '/usr/local/bin', '/usr/bin', '/bin']),
        SLURM_ACCOUNT='fredricks_d',
        OMP_NUM_THREADS=args.nproc),
    variables=vars,
    use_cluster=args.use_slurm,
    # slurm_queue=small_queue,
    SHELL='bash',
    cwd=os.getcwd(),
    singularity=singularity,
    binds=' '.join('-B {}'.format(pth) for pth in ['$cwd'] + binds),
    deenurp_img=('$singularity exec $binds --pwd $cwd {}'.format(deenurp_img)),
    dada2_img=('$singularity exec $binds --pwd $cwd {}'.format(dada2_img)),
    min_reads=min_reads,
)

# see http://www.scons.org/doc/HTML/scons-user/a11726.html
if args.sconsign_in_outdir:
    env.SConsignFile(None)

# Requires that all construction variable names exist.
AllowSubstExceptions()

# keep track of output files
targets = Targets()

# begin analysis
for_transfer = [settings]

profile = common.taxit_rp(refpkg, 'profile', img=deenurp_img, singularity=singularity)
ref_sto = common.taxit_rp(refpkg, 'aln_sto', img=deenurp_img, singularity=singularity)

# filter non-16s reads with cmsearch
seqs_16s, seqs_not16s, cmsearch_scores = env.Command(
    target=['$out/seqs-16s.fasta',
            '$out/seqs-not16s.fasta',
            '$out/cmsearch_scores.txt'],
    source=[seqs, 'data/RRNA_16S_BACTERIA.calibrated.cm'],
    action=(
        '$deenurp_img '
        'bin/cmfilter.py $SOURCES '
        '--outfile ${TARGETS[0]} '
        '--discarded ${TARGETS[1]} '
        '--scores ${TARGETS[2]} '
        '--min-evalue 0.01 '
        '--cpu $nproc '
    ))

# align input seqs with cmalign
query_sto, cmalign_scores = env.Command(
    target=['$out/query.sto', '$out/cmalign.scores'],
    source=[seqs_16s, profile],
    # ncores=args.nproc,
    # timelimit=30,
    # slurm_args = '--mem=130000',
    # slurm_queue=large_queue,
    action=(
        '$deenurp_img '
        'cmalign '
        '--cpu $nproc '
        '--mxsize 8196 '
        '--noprob '
        '--dnaout '
        '-o ${TARGETS[0]} '  # alignment in stockholm format
        '--sfile ${TARGETS[1]} '  # scores
        '${SOURCES[1]} '  # alignment profile
        '${SOURCES[0]} '  # input fasta file
        '| grep -E "^#"'  # limit stdout to commented lines
    ))

# merge reference and query seqs
merged, = env.Command(
    target='$out/merged.fasta',
    source=[ref_sto, query_sto],
    action=('$deenurp_img esl-alimerge --dna --outformat afa -o ${TARGET}.temp $SOURCES && '
            'clean_merged.py ${TARGET}.temp ${TARGET} && '
            'rm ${TARGET}.temp')
)

dedup_jplace, = env.Command(
    target='$out/dedup.jplace',
    source=[refpkg, merged],
    action=('$deenurp_img pplacer -p --inform-prior --prior-lower 0.01 --map-identity '
            '-c $SOURCES -o $TARGET -j $nproc'),
    # ncores=nproc,
    # slurm_queue=large_queue
)

# classify placements. Note that we are providing the deduplicated
# placefile, so mapping of reads to specimens and assignment of
# weights must be done elsewhere.
classify_db, = env.Command(
    target='$out/classified.db',
    source=[dedup_jplace, refpkg, merged],
    action=('rm -f $TARGET && '
            '$deenurp_img rppr prep_db -c ${SOURCES[1]} --sqlite $TARGET && '
            '$deenurp_img guppy classify '
            '--pp --classifier hybrid2 '  # TODO: specify pplacer settings in config
            '-j $nproc '
            '${SOURCES[0]} '  # placefile
            '-c ${SOURCES[1]} '
            '--nbc-sequences ${SOURCES[2]} '
            '--sqlite $TARGET ')
)

# write classifications of individual sequence variants at all ranks
# to a csv file
classtab_orig, = env.Command(
    target='$out/classifications.csv',
    source=classify_db,
    action='$deenurp_img bin/get_classifications.py $SOURCE -c $TARGET'
)
Depends(classtab_orig, 'bin/get_classifications.py')
for_transfer.append(classtab_orig)

if to_rename and taxdb:
    renamefile = env.Command(
        target='$out/to_rename.csv',
        source=to_rename,
        action='in2csv $SOURCE > $TARGET'
    )
    for_transfer.append(renamefile)

    classtab, = env.Command(
        target='$out/classifications_renamed.csv',
        source=[classify_db, taxdb, renamefile],
        action=('$deenurp_img bin/get_classifications.py ${SOURCES[0]} '
                '--taxdb ${SOURCES[1]} '
                '--to-rename ${SOURCES[2]} '
                '-c $TARGET')
    )
    Depends(classtab, 'bin/get_classifications.py')
    for_transfer.append(classtab)

    # compare original with renamed classifications
    compared = env.Command(
        target='$out/classifications_compared.csv',
        source=[classtab_orig, classtab],
        action='$dada2_img bin/compare_classifications.R $SOURCES -o $TARGET'
    )
    for_transfer.append(compared)
    Depends(compared, 'bin/compare_classifications.R')
else:
    classtab = classtab_orig

# Prepare an SV table. Also apply filters for sequence variants,
# organisms, and specimens.
if to_remove:
    removefile = env.Command(
        target='$out/to_remove.csv',
        source=to_remove,
        action='in2csv $SOURCE > $TARGET')
    for_transfer.append(to_remove)
else:
    removefile = None

sv_table, sv_table_long, taxtab, taxtab_rel, taxtab_long, lineages, sv_names, removed = env.Command(
    target=[
        '$out/sv_table.csv',         # 0
        '$out/sv_table_long.csv',    # 1
        '$out/taxon_table.csv',      # 2
        '$out/taxon_table_rel.csv',  # 3
        '$out/taxon_table_long.csv', # 4
        '$out/lineages.csv',         # 5
        '$out/sv_names.txt',         # 6
        '$out/removed.csv',          # 7
    ],
    source=[classtab, specimen_map, weights] + ([removefile] if removefile else []),
    action=('$dada2_img '
            'Rscript bin/sv_table.R '
            '--min-reads $min_reads '
            '--classif ${SOURCES[0]} '
            '--specimens ${SOURCES[1]} '
            '--weights ${SOURCES[2]} '
            '--by-sv ${TARGETS[0]} '
            '--by-sv-long ${TARGETS[1]} '
            '--by-taxon ${TARGETS[2]} '
            '--by-taxon-rel ${TARGETS[3]} '
            '--by-taxon-long ${TARGETS[4]} '
            '--lineages ${TARGETS[5]} '
            '--sv-names ${TARGETS[6]} '
            '--removed ${TARGETS[7]} ') +
    ('--remove-taxa ${SOURCES[3]}' if to_remove else '')
)
Depends(sv_table, 'bin/sv_table.R')
for_transfer.extend([sv_table, taxtab, taxtab_rel, removed])

if labels:
    for table in [sv_table, taxtab]:
        labeled_table = env.Command(
            target=str(table).replace('.csv', '_labeled.csv'),
            source=[table, labels],
            action='label_taxon_table.py $SOURCES -o $TARGET --omit path,project'
        )
        for_transfer.append(labeled_table)

# extract alignment of reads represented in output
sv_align = env.Command(
    target='$out/sv_aln.fasta',
    source=[sv_names, merged],
    action=('$deenurp_img seqmagick convert '
            '--include-from-file ${SOURCES[0]} --squeeze ${SOURCES[1]} $TARGET')
)

# phylogenetic tree
# specify OMP_NUM_THREADS=$ncores in environment
tree = env.Command(
    target='$out/sv.tre',
    source=sv_align,
    action='$deenurp_img FastTreeMP -nt -gtr $SOURCE > $TARGET'
)

# create a phyloseq object
phyloseq_sources = [tree, sv_table_long, lineages]
phyloseq_action = (
    '$dada2_img Rscript bin/phyloseq.R '
    '--tree ${SOURCES[0]} '
    '--sv-table ${SOURCES[1]} '
    '--lineages ${SOURCES[2]} '
    '--rds $TARGET ')

if labels:
    phyloseq_sources.append(labels)
    phyloseq_action += '--annotation ${SOURCES[3]} '

phyloseq_rda = env.Command(
    target='$out/phyloseq.rds',
    source=phyloseq_sources,
    action=phyloseq_action
)
Depends(phyloseq_rda, 'bin/phyloseq.R')
for_transfer.append(phyloseq_rda)

# reduplicate the placefile
placefile, = env.Command(
    target='$out/redup.jplace.gz',
    source=[weights, dedup_jplace],
    action=('$deenurp_img guppy redup -m -o $TARGET '
            '-d ${SOURCES[0]} ${SOURCES[1]}')
)

# capture status of this project
settings_copy = env.Command(
    target='$out/settings.conf',
    source=settings,
    action=Copy('$TARGET', '$SOURCE')
)
for_transfer.append(settings_copy)

version_info = env.Command(
    target='$out/version_info.txt',
    source=None,
    action=('('
            'date; echo; '
            'pwd; echo; '
            'git status; echo; '
            'git --no-pager log -n 1 '
            ')'
            '> $TARGET')
)
AlwaysBuild(version_info)
for_transfer.append(version_info)

# write a list of files to transfer
for_transfer_txt = env.Local(
    target='$out/for_transfer.txt',
    source=Flatten(for_transfer),
    action=common.list_files
)
Depends(for_transfer_txt, for_transfer)

# end analysis
targets.update(locals().values())

# identify extraneous files
targets.show_extras(env['out'])
