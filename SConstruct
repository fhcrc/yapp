"""
Project template for 454 pplacer pipeline.
"""

import os
import sys
import datetime
import ConfigParser
from os import path, environ

from SCons.Script import ARGUMENTS, Variables, Decider, \
    PathVariable, Flatten, Depends, Alias, Help, BoolVariable

########################################################################
########################  input data  ##################################
########################################################################

conf = ConfigParser.SafeConfigParser(allow_no_value=True)
conf.read('settings.conf')

rdp = conf.get('input', 'rdp')
blast_db = path.join(rdp, 'blast')
blast_info = path.join(rdp, 'seq_info.csv')
blast_taxonomy = path.join(rdp, 'taxonomy.csv')

refpkg = conf.get('input', 'refpkg')

datadir = conf.get('input', 'datadir')
seqs = conf.get('input', 'seqs')
maps = conf.get('input', 'maps')
weights = conf.get('input', 'weights')
labels = conf.get('input', 'labels')

transfer_dir = conf.get('output', 'transfer_dir')
_timestamp = datetime.date.strftime(datetime.date.today(), '%Y-%m-%d')

########################################################################
#########################  end input data  #############################
########################################################################

# check timestamps before calculating md5 checksums
Decider('MD5-timestamp')

# declare variables for the environment
thisdir = path.basename(os.getcwd())
vars = Variables(None, ARGUMENTS)

vars.Add(BoolVariable('mock', 'Run pipleine with a small subset of input seqs', False))
vars.Add(BoolVariable('use_cluster', 'Dispatch jobs to cluster', False))
vars.Add(PathVariable('out', 'Path to output directory',
                      'output', PathVariable.PathIsDirCreate))
vars.Add('nproc', 'Number of concurrent processes', default=32)
vars.Add('transfer_to',
         'Target directory for transferred data (using "transfer" target)',
         default=path.join(transfer_dir, '{}-{}'.format(_timestamp, thisdir)))
vars.Add(PathVariable('virtualenv', 'Name of virtualenv', thisdir + '-env',
                      PathVariable.PathAccept))
vars.Add(PathVariable('refpkg', 'Reference package', refpkg, PathVariable))

# Provides access to options prior to instantiation of env object
# below; it's better to access variables through the env object.
varargs = dict({opt.key: opt.default for opt in vars.options}, **vars.args)
truevals = {True, 'yes', 'y', 'True', 'true', 't'}
venv = varargs['virtualenv']
mock = varargs['mock'] in truevals
nproc = varargs['nproc']
use_cluster = varargs['use_cluster'] in truevals
refpkg = varargs['refpkg']

# Configure a virtualenv and environment
if not path.exists(venv):
    sys.exit('--> run \nbin/bootstrap.sh')
elif not ('VIRTUAL_ENV' in environ and environ['VIRTUAL_ENV'].endswith(venv)):
    sys.exit('--> run \nsource {}/bin/activate'.format(venv))

# requirements installed in the virtualenv
from bioscons.fileutils import Targets
from bioscons.slurm import SlurmEnvironment

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
    shell='bash'
)

# store file signatures in a separate .sconsign file in each
# directory; see http://www.scons.org/doc/HTML/scons-user/a11726.html
env.SConsignFile(None)
Help(vars.GenerateHelpText(env))
targets = Targets()

# downsample if mock
if mock:
    env['out'] = env.subst('${out}-mock')
    seqs, maps = env.Local(
        target=['$out/sample.fasta', '$out/sample.seq_info.csv'],
        source=[seqs, maps],
        action='downsample -N 10 $SOURCES $TARGETS'
    )

#dedup_info, dedup_fa, = env.Local(
#    target=['$out/dedup_info.csv', '$out/dedup.fasta'],
#    source=[seqs, maps],
#    action=('deduplicate_sequences.py '
#            '${SOURCES[0]} --split-map ${SOURCES[1]} '
#            '--deduplicated-sequences-file ${TARGETS[0]} ${TARGETS[1]}')
#    )

merged, scores = env.Command(
    target=['$out/dedup_merged.fasta.gz', '$out/dedup_cmscores.txt.gz'],
    source=[refpkg, seqs],
    action=('refpkg_align $SOURCES $TARGETS $nproc'),
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

# reduplicate
placefile, = env.Local(
    target='$out/redup.jplace.gz',
    source=[weights, dedup_jplace],
    action='guppy redup -m -o $TARGET -d ${SOURCES[0]} ${SOURCES[1]}',
    ncores=nproc)

nbc_sequences = merged

classify_db, = env.Command(
    target='$out/placements.db',
    source=[refpkg, placefile, nbc_sequences],
    action=('rm -f $TARGET && '
            'rppr prep_db -c ${SOURCES[0]} --sqlite $TARGET && '
            'guppy classify --pp --classifier hybrid2 -j ${nproc} '
            '-c ${SOURCES[0]} ${SOURCES[1]} --nbc-sequences ${SOURCES[2]} --sqlite $TARGET && '
            'multiclass_concat.py $TARGET'),
    ncores=nproc
)

for_transfer = []

# describe classification at each major rank
ranks = ['phylum', 'class', 'order', 'family', 'genus', 'species']
for rank in ranks:
    e = env.Clone()
    e['rank'] = rank
    bytaxon, byspecimen, groupbyspecimen = e.Local(
        target=['$out/byTaxon.${rank}.csv', '$out/bySpecimen.${rank}.csv',
                '$out/groupBySpecimen.${rank}.csv'],
        source=Flatten([maps, labels, classify_db]),
        action=('classif_rect.py --want-rank ${rank} --specimen-map '
                '${SOURCES[0]} --metadata ${SOURCES[1]} ${SOURCES[2]} $TARGETS'))

    decorated_groupbyspecimen, = e.Local(
        target='$out/decoratedGroupBySpecimen.${rank}.csv',
        source=[groupbyspecimen, labels],
        action='csvjoin $SOURCES -c specimen >$TARGET')

    for_transfer.extend([bytaxon, byspecimen, groupbyspecimen,
                         decorated_groupbyspecimen])

    targets.update(locals().values())

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
