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

if '--' in sys.argv:
    settings = sys.argv[-1]
else:
    settings = 'settings.conf'

if not path.exists(settings):
    sys.exit('\nCannot find "{}" '
             'expected "settings.conf" (can also provide as "scons <options> -- settings-file")'
             '- make a copy of one of settings*.conf and update as necessary'.format(settings))

conf = ConfigParser.SafeConfigParser(allow_no_value=True)
conf.read(settings)

venv = conf.get('DEFAULT', 'virtualenv') or thisdir + '-env'

ref_data = conf.get('input', 'refs')
ref_seqs = conf.get('input', 'ref_seqs') if ref_data else None
ref_info = conf.get('input', 'ref_info') if ref_data else None
ref_taxonomy = conf.get('input', 'ref_taxonomy') if ref_data else None

refpkg = conf.get('input', 'refpkg')

datadir = conf.get('input', 'datadir')
seqs = conf.get('input', 'seqs')
seq_info = conf.get('input', 'seq_info')
labels = conf.get('input', 'labels')
weights = conf.get('input', 'weights')

outdir = conf.get('output', 'outdir')

differences = int(conf.get('swarm', 'differences'))
min_mass = int(conf.get('swarm', 'min_mass'))

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

vars.Add(PathVariable('refpkg', 'Reference package', refpkg, PathVariable))

# slurm settings
vars.Add(BoolVariable('use_cluster', 'Dispatch jobs to cluster', True))
vars.Add('nproc', 'Number of concurrent processes', default=12)
vars.Add('small_queue', 'slurm queue for jobs with few CPUs', default='campus')
vars.Add('large_queue', 'slurm queue for jobs with many CPUs', default='full')
vars.Add(BoolVariable(
    'get_hits',
    'perform blast search of swarm OTU reps (output in "output-hits")', False))

# Provides access to options prior to instantiation of env object
# below; it's better to access variables through the env object.
varargs = dict({opt.key: opt.default for opt in vars.options}, **vars.args)
truevals = {True, 'yes', 'y', 'True', 'true', 't'}

mock = varargs['mock'] in truevals
nproc = int(varargs['nproc'])
small_queue = varargs['small_queue']
large_queue = varargs['large_queue']
refpkg = varargs['refpkg']
get_hits = varargs['get_hits'] in truevals
use_cluster = conf.get('DEFAULT', 'use_cluster') in truevals
censored = conf.get('input', 'censored') if conf.has_option('input', 'censored') else None

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
    shell='bash',
    # other parameters
    differences=differences,
    min_mass=min_mass
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
    dedup_info, dedup_fa = File(weights), File(seqs)
else:
    dedup_info, dedup_fa, dropped_fa = env.Command(
        target=['$out/dedup_info.csv', '$out/dedup.fasta', '$out/dropped.fasta.gz'],
        source=[seqs, seq_info],
        action=('swarmwrapper '
                # '-v '
                '--threads $nproc '
                'cluster '
                '${SOURCES[0]} '
                '--specimen-map ${SOURCES[1]} '
                '--abundances ${TARGETS[0]} '
                '--seeds ${TARGETS[1]} '
                '--dropped ${TARGETS[2]} '
                '--dereplicate '
                '--differences $differences '
                '--min-mass $min_mass ')
)


# censor specified sequences, for example reads determined to be
# environmental contaminants
if censored:
    dedup_fa, = env.Command(
        target='$out/dedup_sans_censored.fasta',
        source=[censored, dedup_fa],
        action=('seqmagick convert --exclude-from-file $SOURCES $TARGET')
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

# length pca - ignore errors and create empty files on failure (requires at least two samples)
proj, trans, xml = env.Command(
    target=['$out/lpca.{}'.format(sfx) for sfx in ['proj', 'trans', 'xml']],
    source=[placefile, seq_info, refpkg],
    action=('guppy lpca ${SOURCES[0]}:${SOURCES[1]} '
            '-c ${SOURCES[2]} --out-dir $out --prefix lpca'
            ' || touch $TARGETS')
)

# calculate ADCL
adcl, = env.Command(
    target='$out/adcl.csv.gz',
    source=placefile,
    action=('(echo name,adcl,weight && guppy adcl --no-collapse $SOURCE -o /dev/stdout) | '
            'gzip > $TARGET')
)

# rppr prep_db and guppy classify have some issues related to the
# shared filesystem and gizmo cluster.
# 1. guppy classify fails with Uncaught exception:
#    Multiprocessing.Child_error(_) - may be mitigaed by running with fewer cores.
# 2. rppr prep_db fails with Uncaught exception: Sqlite3.Error("database is locked")
# for now, run locally with a reduced number of cores.
guppy_classify_env = env.Clone()
# guppy_classify_cores = min([nproc, 4])
# guppy_classify_env['nproc'] = guppy_classify_cores
classify_db, = guppy_classify_env.Local(
    target='$out/placements.db',
    source=[refpkg, dedup_jplace, merged, dedup_info, adcl, seq_info],
    action=('guppy_classify.sh --nproc $nproc '
            '--refpkg ${SOURCES[0]} '
            '--placefile ${SOURCES[1]} '
            '--nbc-sequences ${SOURCES[2]} '
            '--dedup-info ${SOURCES[3]} '
            '--adcl ${SOURCES[4]} '
            '--seq-info ${SOURCES[5]} '
            '--sqlite-db $TARGET '
        ),
    # ncores=guppy_classify_cores
)

for_transfer = [settings]

# perform classification at each major rank
# tallies_wide includes labels in column headings (provided by --metadata-map)
if labels:
    classif_sources = [classify_db, seq_info, labels]
    labels_cmd = '--metadata-map ${SOURCES[2]} '
else:
    classif_sources = [classify_db, seq_info]
    labels_cmd = ' '

classified = defaultdict(dict)
for rank in ['phylum', 'class', 'order', 'family', 'genus', 'species']:
    e = env.Clone()
    e['rank'] = rank
    by_taxon, by_specimen, tallies_wide = e.Command(
        target=['$out/by_taxon.${rank}.csv', '$out/by_specimen.${rank}.csv',
                '$out/tallies_wide.${rank}.csv'],
        source=Flatten(classif_sources),
        action=('classif_table.py ${SOURCES[0]} '
                '--specimen-map ${SOURCES[1]} '
                + labels_cmd +
                '/dev/stdout '
                '--by-specimen ${TARGETS[1]} '
                '--tallies-wide ${TARGETS[2]} '
                '--rank ${rank} | '
                'csvsort -c tally -r > ${TARGETS[0]}')
    )
    targets.update(locals().values())
    for_transfer.extend([by_taxon, by_specimen, tallies_wide])
    classified[rank] = {
        'by_taxon': by_taxon,
        'by_specimen': by_specimen,
        'tallies_wide': tallies_wide}

    # pie charts
    # if rank in {'family', 'order'}:
    #     pies = e.Local(
    #         target=['$out/pies.{}.{}'.format(rank, ext) for ext in ['pdf', 'svg']],
    #         source=[proj, by_specimen],
    #         action='Rscript bin/pies.R $SOURCES $TARGET')
    #     for_transfer.extend(pies)
    #     targets.update(locals().values())


# check final read mass for each specimen; arbitrarily use
# 'by_specimen' produced in the final iteration of the loop above.
# if weights:
#     read_mass, = env.Local(
#         target='$out/read_mass.csv',
#         source=[seq_info, by_specimen, weights],
#         action='check_counts.py ${SOURCES[:2]} --weights ${SOURCES[2]} -o $TARGET',
#     )
# else:
#     read_mass, = env.Local(
#         target='$out/read_mass.csv',
#         source=[seq_info, by_specimen],
#         action='check_counts.py $SOURCES -o $TARGET',
#     )


# classification for each read
multiclass_concat, = env.Command(
    target='$out/multiclass_concat.csv',
    source=[classify_db, 'bin/multiclass_concat.sql'],
    action='sqlite3 -csv -header ${SOURCES[0]} < ${SOURCES[1]} > $TARGET'
)

# run other analyses
if get_hits:
    if multiclass_concat.exists() and multiclass_concat.is_up_to_date():
        for_transfer += SConscript(
            'SConscript-gethits', [
                'multiclass_concat',
                'classify_db',
                'dedup_fa',
                'dedup_info',
                'dedup_jplace',
                'env',
                'merged',
                'ref_seqs',
                'ref_info',
                'refpkg',
                'seq_info',
                'labels',
            ])
    else:
        print '*** Run scons again to evaluate SConstruct-gethits (similarity searches of reads)'


# save some info about executables
version_info, = env.Local(
    target='$out/version_info.txt',
    source=None,
    action='version_info.sh > $TARGET'
)
Depends(version_info,
        ['bin/version_info.sh', 'SConstruct', 'SConscript-gethits'])
for_transfer.append(version_info)

# write a list of files to transfer
def list_files(target, source, env):
    with open(target[0].path, 'w') as f:
        f.write('\n'.join(sorted(str(t) for t in source)) + '\n')

    return None

for_transfer = env.Local(
    target='$out/for_transfer.txt',
    source=for_transfer,
    action=list_files
)

# end analysis
targets.update(locals().values())

# identify extraneous files
targets.show_extras(env['out'])
