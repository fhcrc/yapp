"""
Project template for miseq pplacer pipeline.

usage::

  scons [scons-args] -- settings.conf [user-args]
"""

import os
import sys
import configparser
import argparse
import subprocess
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

# arguments after "--" are ignored by scons
user_args = sys.argv[1 + sys.argv.index('--'):] if '--' in sys.argv else []

# we'd like to use some default values from the config file as we set
# up the command line options, but we also want to be able to specify
# the config file from the command line. This makes things a bit
# convoluted at first.
settings_default = 'settings.conf'
if user_args and path.exists(user_args[0]):
    settings = user_args[0]
elif path.exists(settings_default):
    settings = settings_default
else:
    sys.exit('A configuration file must be provided, either as '
             'the first argument after "--", or named "{}" '
             'in this directory'.format(settings_default))

conf = configparser.SafeConfigParser(allow_no_value=True)
conf.read(settings)

thisdir = path.basename(os.getcwd())

# Ensure that we are using a virtualenv, and that we are using the one
# specified in the config if provided.
venv = path.abspath(conf['DEFAULT'].get('virtualenv') or 'py3-env')

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
    nargs='*', default=settings_default)
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
labels = input['labels']
weights = input['weights']

singularity = conf['singularity'].get('singularity', 'singularity')
deenurp_img = conf['singularity']['deenurp']
dada2_img = conf['singularity']['dada2']

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
    deenurp_img=('$singularity exec -B $cwd --pwd $cwd {}'.format(deenurp_img)),
    dada2_img=('$singularity exec -B $cwd --pwd $cwd {}'.format(dada2_img)),
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

# align input seqs with cmalign
query_sto, cmalign_scores = env.Command(
    target=['$out/query.sto', '$out/cmalign.scores'],
    source=[seqs, profile],
    # ncores=args.nproc,
    # timelimit=30,
    # slurm_args = '--mem=130000',
    # slurm_queue=large_queue,
    action=(
        '$deenurp_img '
        'cmalign --cpu $nproc --noprob --dnaout '
        # '--mxsize 8196 '
        '-o ${TARGETS[0]} '  # alignment in stockholm format
        '--sfile ${TARGETS[1]} '  # scores
        '${SOURCES[1]} '  # alignment profile
        '${SOURCES[0]} | grep -E "^#"'  # the input fasta file
    ))

# merge reference and query seqs
merged, = env.Command(
    target='$out/merged.fasta',
    source=[ref_sto, query_sto],
    action=('$deenurp_img esl-alimerge --dna --outformat afa -o $TARGET $SOURCES')
)

# reformat and filter (remove non-16S and any other specified SVs)
merged_filtered, seqs_filtered = env.Command(
    target=['$out/merged_16s_aln.fasta', '$out/16s.fasta'],
    source=[merged, cmalign_scores],
    action=('filter_merged.py $SOURCES '
            '--filtered-aln ${TARGETS[0]} '
            '--filtered ${TARGETS[1]} '
            '--min-bit-score 0')
)
Depends(merged_filtered, 'bin/filter_merged.py')
for_transfer.append(seqs_filtered)

dedup_jplace, = env.Command(
    target='$out/dedup.jplace',
    source=[refpkg, merged_filtered],
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
    source=[dedup_jplace, refpkg, merged_filtered],
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
classtab, = env.Command(
    target='$out/classifications.csv',
    source=classify_db,
    action='bin/get_classifications.py $SOURCE -c $TARGET'
)
Depends(classtab, 'bin/get_classifications.py')
for_transfer.append(classtab)

# Prepare an SV table. Also apply filters for sequence variants,
# organisms, and specimens.
sv_table, sv_table_long, taxtab, taxtab_long, lineages, sv_names = env.Command(
    target=[
        '$out/sv_table.csv',
        '$out/sv_table_long.csv',
        '$out/taxon_table.csv',
        '$out/taxon_table_long.csv',
        '$out/lineages.csv',
        '$out/sv_names.txt',
    ],
    source=[classtab, specimen_map, weights],
    action=('$dada2_img Rscript bin/sv_table.R '
            '--classif ${SOURCES[0]} '
            '--specimens ${SOURCES[1]} '
            '--weights ${SOURCES[2]} '
            '--by-sv ${TARGETS[0]} '
            '--by-sv-long ${TARGETS[1]} '
            '--by-taxon ${TARGETS[2]} '
            '--by-taxon-long ${TARGETS[3]} '
            '--lineages ${TARGETS[4]} '
            '--sv-names ${TARGETS[5]} '
            # '--include-unclassified '
            )
)
Depends(sv_table, 'bin/sv_table.R')
for_transfer.extend([sv_table_long, taxtab_long])

for table in [sv_table, taxtab]:
    labeled_table = env.Command(
        target=str(table).replace('.csv', '_labeled.csv'),
        source=[table, 'dada2/sample_info.csv'],
        action='label_taxon_table.py $SOURCES -o $TARGET --omit path,project'
    )
    for_transfer.append(labeled_table)

# extract alignment of reads represented in output
sv_align = env.Command(
    target='$out/sv_aln.fasta',
    source=[sv_names, merged_filtered],
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
phyloseq_rda = env.Command(
    target='$out/phyloseq.rds',
    source=[tree, sv_table_long, lineages],
    action=(
        '$dada2_img Rscript bin/phyloseq.R '
        '--tree ${SOURCES[0]} '
        '--sv-table ${SOURCES[1]} '
        '--lineages ${SOURCES[2]} '
        '--rds $TARGET '
    ))
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
