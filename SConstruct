"""
Project template for Fredricks lab 454 pipeline.
"""

import os
import glob
import sqlite3
import sys
import datetime

from itertools import chain
from os import path
from os.path import join

# note that we're using scons installed to the virtualenv
from SCons.Script import ARGUMENTS, Variables, Decider, File, Dir

# Configure a virtualenv and environment
virtualenv = ARGUMENTS.get('virtualenv', path.basename(os.getcwd()) + '-env')

# provides label for data transferred to bvdiversity share
transfer_date = ARGUMENTS.get(
    'transfer_date', datetime.date.strftime(datetime.date.today(), '%Y-%m-%d'))

if not path.exists(virtualenv):
    sys.exit('--> run \bbin/setup.sh')
elif not ('VIRTUAL_ENV' in os.environ and os.environ['VIRTUAL_ENV'].endswith(virtualenv)):
    sys.exit('--> run \nsource {}/bin/activate'.format(virtualenv))

# requirements installed in the virtualenv
from bioscons.fileutils import Targets, rename
from bioscons.slurm import SlurmEnvironment

# check timestamps before calculating md5 checksums
# see http://www.scons.org/doc/production/HTML/scons-user.html#AEN929
Decider('MD5-timestamp')

# declare variables for the environment
nproc = ARGUMENTS.get('nproc', 12)
vars = Variables()

vars.Add(PathVariable('out', 'Path to output directory',
                      'output', PathVariable.PathIsDirCreate))
vars.Add('nproc', default=nproc)

# explicitly define execution PATH, giving preference to local executables
PATH = ':'.join([
    'bin',
    path.join(virtualenv, 'bin'),
    # '/home/nhoffman/local/bin',
    # '/app/bin',
    # '/home/matsengrp/local/bin',
    '/usr/local/bin', '/usr/bin', '/bin'])

env = SlurmEnvironment(
    ENV = dict(os.environ, PATH=PATH),
    variables = vars,
    use_cluster=True,
    shell='bash'
)

targets = Targets()

# input data and dependencies
mg_refset = '/shared/silo_researcher/Matsen_F/MatsenGrp/micro_refset'
rdp_plus = path.join(mg_refset, 'rdp_plus/rdp_10_31_plus.v1.1')

blast_db = path.join(rdp_plus, 'blast')
blast_info = path.join(rdp_plus, 'seq_info.csv')
blast_taxonomy = path.join(rdp_plus, 'taxonomy.csv')

refpkg = path.join(mg_refset, 'reproductive-denovo-named', 'output',
                   '20130610/refset/urogenital-named-20130610.refpkg')
cmfile = join(refpkg, 'bacteria16S_508_mod5.cm')

datadir = ('/shared/silo_researcher/Fredricks_D/bvdiversity/'
           'combine_projects/output/projects/cultivation')
filtered = path.join(datadir, 'seqs.fasta')
seq_info = path.join(datadir, 'seq_info.csv')
labels = path.join(datadir, 'labels.csv')

# downsample for development
filtered, = env.Local(
    target='$out/sample.fasta',
    source=filtered,
    action='seqmagick convert --sample 1000 $SOURCE $TARGET'
    )

# dedup
dedup_info, dedup_fa, = env.Command(
    target=['$out/dedup_info.csv', '$out/dedup_fasta.csv'],
    source=[filtered, seq_info],
    action=('deduplicate_sequences.py '
            '${SOURCES[0]} --split-map ${SOURCES[1]} '
            '--deduplicated-sequences-file ${TARGETS[0]} ${TARGETS[1]}')
    )

scores, merged = env.SAlloc(
    target=['$out/dedup_merged.txt', '$out/dedup_merged.sto'],
    source=[refpkg, dedup_fa],
    action=('refpkg_align.py align '
            '--use-mpi ' if ncores > 1 else ''
            '$SOURCES --stdout $TARGETS')
)

dedup_jplace, = env.SRun(
    target='$out/dedup.jplace',
    source=[refpkg, merged],
    action=('pplacer -p --inform-prior --prior-lower 0.01 --map-identity '
            '-c $SOURCES -o $TARGET -j $nproc'),
    ncores=nproc
    )

placefile, = env.Local(
    target='$out/redup.jplace',
    source=[dedup_info, dedup_jplace],
    action='guppy redup -m -o $TARGET -d ${SOURCES[0]} ${SOURCES[1]}',
    ncores=nproc)

classify_db, = env.SRun(
    target='$out/placements.db',
    source=[refpkg, placefile, merged],
    action=('sh -c "rppr prep_db -c ${SOURCES[0]} --sqlite $TARGET && '
            'guppy classify --pp -c ${SOURCES[0]} --sqlite $TARGET ${SOURCES[1]} '
            '  --classifier hybrid2 --nbc-sequences ${SOURCES[2]} -j $nproc && '
            'multiclass_concat.py $TARGET"' % ncores)
)

for_transfer = []
for rank in ['phylum','class', 'order', 'family', 'genus', 'species']:
    e = env.Clone()
    e['rank'] = rank
    bytaxon, byspecimen, groupbyspecimen = e.Local(
        target=['$out/byTaxon.${rank}.csv', '$out/bySpecimen.${rank}.csv',
                '$out/groupBySpecimen.${rank}.csv'],
        source=Flatten([specimens, labels, classify_db]),
        action=('classif_rect.py --want-rank ${rank} --specimen-map '
                '${SOURCES[0]} --metadata ${SOURCES[1]} ${SOURCES[2]} $TARGETS'))

    decorated_groupbyspecimen, = e.Local(
        target='$out/decoratedGroupBySpecimen.${rank}.csv',
        source=[groupbyspecimen, labels],
        action='csvjoin $SOURCES -c specimen >$TARGET')

    for_transfer.extend([bytaxon, byspecimen, groupbyspecimen,
                         decorated_groupbyspecimen])


dest = '/shared/silo_researcher/Fredricks_D/bvdiversity/{}-miseq_pilot'.format(transfer_date)
transfer = env.Command(
    target = path.join(dest, 'project_status.txt'),
    source = for_transfer,
    action = (# 'git diff --exit-code --name-status || '
        'git diff-index --quiet HEAD || '
        'echo "error: there are uncommitted changes" && '
        'mkdir -p %(dest)s && '
        '(pwd && git --no-pager log -n1) > $TARGET && '
        'cp $SOURCES %(dest)s '
    ) % {'dest':dest},
    use_cluster = False
    )

Alias('transfer', [transfer, more_transfers])

# end analysis
targets.update(locals().values())

# identify extraneous files
targets.show_extras(env['out'])
