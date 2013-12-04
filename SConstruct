"""
Project template for 454 pplacer pipeline.
"""

import os
import sys
import datetime
from os import path, environ

from SCons.Script import ARGUMENTS, Variables, Decider, Environment, \
    PathVariable, Flatten, Depends, Alias, Help, BoolVariable

########################################################################
########################  input data  ##################################
########################################################################

refpkg = '/media/lvdata2/ion_cfstudy/cf_refset/cf.named.1.2.refpkg'

ion_pipeline = '/media/lvdata2/ion_cfstudy/ion_pipeline'
datadir = path.join(ion_pipeline, 'output-20131120-10k')
filtered = path.join(datadir, 'denoised_full.fasta')
seq_info = path.join(datadir, 'denoised_map_full.csv')
labels = path.join(datadir, 'labels.csv')

_timestamp = datetime.date.strftime(datetime.date.today(), '%Y-%m-%d')
transfer_dir = ion_pipeline

########################################################################
#########################  end input data  #############################
########################################################################

# check timestamps before calculating md5 checksums
Decider('MD5-timestamp')

# declare variables for the environment
thisdir = path.basename(os.getcwd())
vars = Variables(None, ARGUMENTS)

vars.Add(BoolVariable('mock', 'Run pipleine with a small subset of input seqs',
                      False))
vars.Add(PathVariable('out', 'Path to output directory',
                      'output', PathVariable.PathIsDirCreate))
vars.Add('nproc', 'Number of concurrent processes', default=12)
vars.Add('transfer_to',
         'Target directory for transferred data (using "transfer" target)',
         default=path.join(transfer_dir, '{}-{}'.format(_timestamp, thisdir)))
vars.Add(PathVariable('virtualenv', 'Location of virtualenv', '../ion_cfstudy-env',
                      PathVariable.PathAccept))

# Provides access to options prior to instantiation of env object
# below; it's better to access variables through the env object.
varargs = dict({opt.key: opt.default for opt in vars.options}, **vars.args)
venv = varargs['virtualenv']
mock = varargs['mock'] in {'yes', 'y', 'true'}
nproc = varargs['nproc']

# Configure a virtualenv and environment
if not path.exists(venv):
    sys.exit('--> run \nbin/bootstrap.sh')
elif not ('VIRTUAL_ENV' in environ
        and environ['VIRTUAL_ENV'].endswith(path.basename(venv))):
    sys.exit('--> run \nsource {}/bin/activate'.format(venv))

# requirements installed in the virtualenv
from bioscons.fileutils import Targets

# Explicitly define PATH, giving preference to local executables; it's
# best to use absolute paths for non-local executables rather than add
# paths here to avoid accidental introduction of external
# dependencies.
env = Environment(
    ENV = dict(
        os.environ,
        PATH=':'.join([
            'bin',
            path.join(venv, 'bin'),
            # '/home/nhoffman/local/bin',
            # '/app/bin',
            # '/home/matsengrp/local/bin',
            '/usr/local/bin', '/usr/bin', '/bin'])),
    variables = vars,
    SHELL = 'bash'
)

if mock:
    env['out'] = env.subst('${out}-mock')

Help(vars.GenerateHelpText(env))

targets = Targets()

# downsample if mock
if mock:
    filtered, = env.Command(
        target='$out/sample.fasta',
        source=filtered,
        action='seqmagick convert --sample 1000 $SOURCE $TARGET'
        )

# TODO - use esl-sfetch to split input sequences and iterate over deduplicate... pplacer; then concatenate placefiles and redup

dedup_info, dedup_fa, = env.Command(
    target=['$out/dedup_info.csv', '$out/dedup.fasta'],
    source=[filtered, seq_info],
    action=('deduplicate_sequences.py '
            '${SOURCES[0]} --split-map ${SOURCES[1]} '
            '--deduplicated-sequences-file ${TARGETS[0]} ${TARGETS[1]}')
    )

merged, scores = env.Command(
    target=['$out/dedup_merged.sto', '$out/dedup_cmscores.txt'],
    source=[refpkg, dedup_fa],
    action=('refpkg_align.sh $SOURCES $TARGETS'),
    ncores=nproc
)

dedup_jplace, = env.Command(
    target='$out/dedup.jplace',
    source=[refpkg, merged],
    action=('pplacer -p --inform-prior --prior-lower 0.01 --map-identity '
            # '--no-pre-mask '
            '-c $SOURCES -o $TARGET -j $nproc'),
    ncores=nproc
    )

placefile, = env.Command(
    target='$out/redup.jplace',
    source=[dedup_info, dedup_jplace],
    action='guppy redup -m -o $TARGET -d ${SOURCES[0]} ${SOURCES[1]}',
    ncores=nproc)

classify_db, = env.Command(
    target='$out/placements.db',
    source=[refpkg, placefile, merged],
    action=('rppr prep_db -c ${SOURCES[0]} --sqlite $TARGET && '
            'guppy classify --pp -c ${SOURCES[0]} --sqlite $TARGET ${SOURCES[1]} '
            '  --classifier hybrid2 --nbc-sequences ${SOURCES[2]} -j ${nproc} && '
            'multiclass_concat.py $TARGET')
)

for_transfer = []

# perform classification at each major rank
for rank in ['phylum', 'class', 'order', 'family', 'genus', 'species']:
    e = env.Clone()
    e['rank'] = rank
    bytaxon, byspecimen, groupbyspecimen = e.Command(
        target=['$out/byTaxon.${rank}.csv', '$out/bySpecimen.${rank}.csv',
                '$out/groupBySpecimen.${rank}.csv'],
        source=Flatten([seq_info, labels, classify_db]),
        action=('classif_rect.py --want-rank ${rank} --specimen-map '
                '${SOURCES[0]} --metadata ${SOURCES[1]} ${SOURCES[2]} $TARGETS'))

    decorated_groupbyspecimen, = e.Command(
        target='$out/decoratedGroupBySpecimen.${rank}.csv',
        source=[groupbyspecimen, labels],
        action='csvjoin $SOURCES -c specimen >$TARGET')

    for_transfer.extend([bytaxon, byspecimen, groupbyspecimen,
                         decorated_groupbyspecimen])

# save some info about executables
version_info, = env.Command(
    target='$out/version_info.txt',
    source=None,
    action='version_info.sh > $TARGET'
)
Depends(version_info, ['bin/version_info.sh', for_transfer])
for_transfer.append(version_info)

# copy a subset of the results elsewhere
transfer = env.Command(
    target = '$transfer_to/project_status.txt',
    source = for_transfer,
    action = (
        'git diff-index --quiet HEAD || '
        'echo "error: there are uncommitted changes" && '
        'mkdir -p %(transfer_to)s && '
        '(pwd && git --no-pager log -n1) > $TARGET && '
        'cp $SOURCES $transfer_to '
    )
)

Alias('transfer', transfer)

# end analysis
targets.update(locals().values())

# identify extraneous files
targets.show_extras(env['out'])
