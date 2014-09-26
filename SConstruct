"""
Project template for 454 pplacer pipeline.
"""

import os
import sys
import datetime
import ConfigParser
from os import path, environ
from collections import defaultdict

from SCons.Script import (ARGUMENTS, Variables, Decider, SConscript,
      PathVariable, Flatten, Depends, Alias, Help, BoolVariable)

# requirements installed in the virtualenv
from bioscons.fileutils import Targets
from bioscons.slurm import SlurmEnvironment

thisdir = path.basename(os.getcwd())

########################################################################
########################  input data  ##################################
########################################################################

# ugh, yuck. Provide an alternate value for settings using
# 'scons -- other-settings.conf'
settings = sys.argv[-1] if '--' in sys.argv else 'settings.conf'

if not path.exists(settings):
    sys.exit('\nCannot find "{}" '
             '- make a copy of one of settings*.conf and update as necessary'.format(settings))

conf = ConfigParser.SafeConfigParser(allow_no_value=True)
conf.read(settings)

venv = conf.get('DEFAULT', 'virtualenv') or thisdir + '-env'

rdp = conf.get('input', 'rdp')
blast_db = path.join(rdp, 'blast')
blast_info = path.join(rdp, 'seq_info.csv')
blast_taxonomy = path.join(rdp, 'taxonomy.csv')

refpkg = conf.get('input', 'refpkg')

datadir = conf.get('input', 'datadir')
seqs = conf.get('input', 'seqs')
seq_info = conf.get('input', 'seq_info')
labels = conf.get('input', 'labels')
weights = conf.get('input', 'weights')

outdir = conf.get('output', 'outdir')
transfer_dir = conf.get('output', 'transfer_dir')
_timestamp = datetime.date.strftime(datetime.date.today(), '%Y-%m-%d')

########################################################################
#########################  end input data  #############################
########################################################################

# check timestamps before calculating md5 checksums
Decider('MD5-timestamp')

# declare variables for the environment
vars = Variables(None, ARGUMENTS)

vars.Add(BoolVariable('mock', 'Run pipeline with a small subset of input seqs', False))
vars.Add(PathVariable('out', 'Path to output directory',
                      outdir, PathVariable.PathIsDirCreate))

if transfer_dir:
    transfer_to = path.join(transfer_dir, '{}-{}'.format(_timestamp, thisdir))
    vars.Add('transfer_to',
             'Target directory for transferred data (using "transfer" target)',
             default=transfer_to)
else:
    transfer_to = None

vars.Add(PathVariable('refpkg', 'Reference package', refpkg, PathVariable))

# slurm settings
vars.Add(BoolVariable('use_cluster', 'Dispatch jobs to cluster', True))
vars.Add('nproc', 'Number of concurrent processes', default=20)
vars.Add('small_queue', 'slurm queue for jobs with few CPUs', default='campus')
vars.Add('large_queue', 'slurm queue for jobs with many CPUs', default='full')

# Provides access to options prior to instantiation of env object
# below; it's better to access variables through the env object.
varargs = dict({opt.key: opt.default for opt in vars.options}, **vars.args)
truevals = {True, 'yes', 'y', 'True', 'true', 't'}
mock = varargs['mock'] in truevals
nproc = int(varargs['nproc'])
small_queue = varargs['small_queue']
large_queue = varargs['large_queue']
refpkg = varargs['refpkg']

use_cluster = conf.get('DEFAULT', 'use_cluster') in truevals
named = conf.get('DEFAULT', 'named') in truevals

# Configure a virtualenv and environment
if not path.exists(venv):
    sys.exit('Please specify a virtualenv in settings.conf or '
             'create one using \'bin/bootstrap.sh\'.')
elif not ('VIRTUAL_ENV' in environ and \
        environ['VIRTUAL_ENV'].endswith(path.basename(venv))):
    sys.exit('--> run \nsource {}/bin/activate'.format(venv))

# Explicitly define PATH, giving preference to local executables; it's
# best to use absolute paths for non-local executables rather than add
# paths here to avoid accidental introduction of external
# dependencies.
env = SlurmEnvironment(
    ENV = dict(
        os.environ,
        PATH=':'.join(['bin', path.join(venv, 'bin'), '/usr/local/bin', '/usr/bin', '/bin']),
        SLURM_ACCOUNT='fredricks_d'),
    variables = vars,
    use_cluster=use_cluster,
    slurm_queue=small_queue,
    shell='bash'
)

# store file signatures in a separate .sconsign file in each
# directory; see http://www.scons.org/doc/HTML/scons-user/a11726.html
# env.SConsignFile(None)
Help(vars.GenerateHelpText(env))
targets = Targets()

# downsample if mock
if mock:
    env['out'] = env.subst('${out}-mock')
    seqs, seq_info = env.Local(
        target=['$out/sample.fasta', '$out/sample.seq_info.csv'],
        source=[seqs, seq_info],
        action='downsample -N 10 $SOURCES $TARGETS'
    )

if weights:
    dedup_info, dedup_fa = weights, seqs
else:
    dedup_info, dedup_fa, = env.Command(
        target=['$out/dedup_info.csv', '$out/dedup.fasta'],
        source=[seqs, seq_info],
        action=('deduplicate_sequences.py '
                '${SOURCES[0]} --split-map ${SOURCES[1]} '
                '--deduplicated-sequences-file ${TARGETS[0]} ${TARGETS[1]}')
        )

merged, scores = env.Command(
    target=['$out/dedup_merged.fasta.gz', '$out/dedup_cmscores.txt.gz'],
    source=[refpkg, dedup_fa],
    action=('refpkg_align $SOURCES $TARGETS $nproc'),
    ncores=nproc,
    slurm_queue=large_queue
)

dedup_jplace, = env.Command(
    target='$out/dedup.jplace',
    source=[refpkg, merged],
    action=('pplacer -p --inform-prior --prior-lower 0.01 --map-identity '
            # '--no-pre-mask '
            '-c $SOURCES -o $TARGET -j $nproc'),
    ncores=nproc,
    slurm_queue=large_queue
    )

# reduplicate
placefile, = env.Command(
    target='$out/redup.jplace.gz',
    source=[dedup_info, dedup_jplace],
    action='guppy redup -m -o $TARGET -d ${SOURCES[0]} ${SOURCES[1]}'
)

nbc_sequences = merged

# length pca
proj, trans, xml = env.Command(
    target=['$out/lpca.{}'.format(sfx) for sfx in ['proj', 'trans', 'xml']],
    source=[placefile, seq_info, refpkg],
    action=('guppy lpca ${SOURCES[0]}:${SOURCES[1]} -c ${SOURCES[2]} --out-dir $out --prefix lpca')
    )

# calculate ADCL
adcl, = env.Command(
    target='$out/adcl.csv.gz',
    source=placefile,
    action=('(echo name,adcl,weight && guppy adcl --no-collapse $SOURCE -o /dev/stdout) | '
            'gzip > $TARGET')
    )

for_transfer = ['settings.conf']

# run other analyses
# SConscript('SConscript-getseqs', [
#     'classified',
#     'classify_db',
#     'dedup_fa',
#     'dedup_info',
#     'env',
#     'transfer_to'
# ])

if named:
    SConscript('SConscript-classify', [
        'adcl',
        'dedup_info',
        'dedup_jplace',
        'env',
        'for_transfer',
        'labels',
        'nbc_sequences',
        'nproc',
        'refpkg',
        'seq_info',
        'targets',
        'weights',
    ])

# save some info about executables
version_info, = env.Local(
    target='$out/version_info.txt',
    source=None,
    action='version_info.sh > $TARGET'
)
Depends(version_info, ['bin/version_info.sh', for_transfer])
for_transfer.append(version_info)

# copy a subset of the results elsewhere
transfer = env.Local(
    target = '$transfer_to/project_status.txt',
    source = for_transfer,
    action = (
        'git diff-index --quiet HEAD || '
        'echo "error: there are uncommitted changes" && '
        'mkdir -p $transfer_to && '
        '(pwd && git --no-pager log -n1) > $TARGET && '
        'cp $SOURCES $transfer_to '
    )
)

Alias('transfer', transfer)

# end analysis
targets.update(locals().values())

# identify extraneous files
targets.show_extras(env['out'])
