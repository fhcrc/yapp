=====================================
 yapp (yet another pplacer pipeline)
=====================================

overview
========

Yet another pplacer pipleine with the following features and objectives:

 * intended to contain only a single project
 * flat (actions are mostly basic scons Commands without functional wrappers)
 * uses bioscons for dispatch to the cluster using Slurm
 * creates an execution environment that relies on local copies of
   many dependencies
 * supports Infernal 1.1

The motivation for this was the recognition that pipelines for
different projects will likely diverge (or require different versions
of various dependencies) to an extent greater than can be easily
supported using earlier versions of the pipeline.

initial setup
=============

This pipeline attempts to install most dependencies locally. The only
python-related dependency is a python binary to create (and be copied
into) the virtualenv - this uses the default python interpreter
defined in your environment, or can be specified as an environment
variable. For example (after cloning this repo someplace)::

  PYTHON=~/local/bin/python bin/bootstrap.sh

Because long paths seem not to be tolerated in shebang lines,
bootstrap.sh uses virtualenv's ``--relocatable`` option to make paths
relative. It's best to install additional python packages by adding
them to ``requirements.txt`` and re-running the above command. If the
virtualenv is active, you don't need to specify the python interpreter
when re-running bootstrap.sh after initial setup.

Initial setup takes a little while (about 8 minutes on stoat using a
shared version of opam), mostly because numpy is a dependency of
several packages and needs to be compiled.


pplacer
-------

pplacer can be installed either from source (default is the dev
branch) or as binaries. Modify ``bin/bootstrap.sh`` as necessary to
define which is used. When installing from source,
``bin/install_pplacer.sh`` attempts to install all ocaml
dependencies. This turns out to take a while, and to occupy a
considerable amount of space. By default, $OPAMROOT is defined as
~/local/share/opam so that the ocaml compiler and pplacer dependencies
can be shared between projects. If you want to compile a pplacer
version other than dev, update the value passed to
``bin/install_pplacer.sh --pplacer-version``.


infernal
--------

``bootstrap.sh`` also installs Infernal 1.1 binaries.

notes
=====

 * ``scons -h`` prints user defined command line options (``-H``
   prints built in options).
 * use ``scons mock=true`` to perform a trial run on a data subset
   (TODO: use Connor's approach of sampling from each specimen)
 * ``scons transfer`` facilitates handoff of results by enforcing a
   clean git state and copying specified files elsewhere.
 * Requires a reference package containing infernal 1.1-compatible
   alignment profile and reference alignment (use
   ``bin/upgrade_refpkg.sh`` to create a compatible version of an
   existing refpkg).
