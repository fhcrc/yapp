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

settings = 'settings.conf'
if not path.exists(settings):
    sys.exit('\nCannot find "{}" '
             '- make a copy of one of settings*.conf and update as necessary'.format(settings))

conf = ConfigParser.SafeConfigParser(allow_no_value=True)
conf.read(settings)

rdp = conf.get('input', 'rdp')
blast_db = path.join(rdp, 'blast')
blast_info = path.join(rdp, 'seq_info.csv')
blast_taxonomy = path.join(rdp, 'taxonomy.csv')

refpkg = conf.get('input', 'refpkg')

datadir = conf.get('input', 'datadir')
seqs = conf.get('input', 'seqs')
seq_info = conf.get('input', 'seq_info')
weights = conf.get('input', 'weights')
labels = conf.get('input', 'labels')

annotation = '../../../annotation/experiment03.csv'

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
vars.Add('nproc', 'Number of concurrent processes', default=12)

if transfer_dir:
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
    seqs, seq_info = env.Local(
        target=['$out/sample.fasta', '$out/sample.seq_info.csv'],
        source=[seqs, seq_info],
        action='downsample -N 10 $SOURCES $TARGETS'
    )

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

# length pca
proj, trans, xml = env.Command(
    target=['$out/lpca.{}'.format(sfx) for sfx in ['proj', 'trans', 'xml']],
    source=[placefile, seq_info, refpkg],
    action=('guppy lpca ${SOURCES[0]}:${SOURCES[1]} -c ${SOURCES[2]} --out-dir $out --prefix lpca')
    )

# perform classification at each major rank
# tallies_wide includes labels in column headings (provided by --metadata-map)
for rank in ['phylum', 'class', 'order', 'family', 'genus', 'species']:
    e = env.Clone()
    e['rank'] = rank
    by_taxon, by_specimen, tallies_wide = e.Local(
        target=['$out/by_taxon.${rank}.csv', '$out/by_specimen.${rank}.csv',
                '$out/tallies_wide.${rank}.csv'],
        source=Flatten([classify_db, seq_info, labels]),
        action=('classif_table.py ${SOURCES[0]} '
                '--specimen-map ${SOURCES[1]} '
                '--metadata-map ${SOURCES[2]} '
                '${TARGETS[0]} '
                '--by-specimen ${TARGETS[1]} '
                '--tallies-wide ${TARGETS[2]} '
                '--rank ${rank}'))
    targets.update(locals().values())
    for_transfer.extend([by_taxon, by_specimen, tallies_wide])

    if rank in {'order'}:
        pies = e.Local(
            target=['$out/pies.{}.{}'.format(rank, ext) for ext in ['pdf', 'svg']],
            source=[proj, by_specimen],
            action='Rscript bin/pies.R $SOURCES $TARGETS')

        Depends(pies, 'bin/pies.R')
        for_transfer.extend(pies)

        e['buildings'] = '/home/local/AMC/ngh2/src/yapp/bin/buildings.R'
        buildings = e.Local(
            target=['$out/buildings.{}.{}'.format(rank, ext) for ext in ['pdf', 'svg']],
            source=[annotation, by_specimen],
            action=('Rscript $buildings --annotation ${SOURCES[0]} ${SOURCES[1]} '
                    '-o $TARGETS -c diet:metformin'))
        Depends(buildings, e['buildings'])
        for_transfer.extend(buildings)

    targets.update(locals().values())

# plot lpca metformin experiment
lpca = env.Local(
    target = ['$out/lpca.pdf', '$out/lpca.svg'],
    source = ['output/lpca.proj', annotation],
    action = 'plot_lpca.R $SOURCES --outfiles $TARGETS')
for_transfer.extend(lpca)

# calculate ADCL
adcl, = env.Local(
    target='$out/adcl.csv.gz',
    source=placefile,
    action='guppy adcl --no-collapse $SOURCE -o /dev/stdout | gzip > $TARGET'
    )

# save some info about executables
version_info, = env.Local(
    target='$out/version_info.txt',
    source=None,
    action='version_info.sh > $TARGET'
)
Depends(version_info, ['bin/version_info.sh', for_transfer])
for_transfer.append(version_info)

if transfer_dir:
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
