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
* uses python3!

initial setup
=============

This pipeline uses a virtualenv with a minimum of packages
installed. The only python-related dependency is a python binary to
create (and be copied into) the virtualenv - this uses the default
python interpreter defined in your environment, or can be specified as
an environment variable. For example (after cloning this repo
someplace)::

  PYTHON=~/local/bin/python3 bin/setup.sh

Because long paths seem not to be tolerated in shebang lines, the
setup script uses virtualenv's ``--relocatable`` option to make paths
relative. It's best to install additional python packages by adding
them to ``requirements.txt`` and re-running the above command. If the
virtualenv is active, you don't need to specify the python interpreter
when re-running build_env.sh after initial setup.

singularity
===========

