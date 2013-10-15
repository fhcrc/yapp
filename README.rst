=====================================
 yapp (yet another pplacer pipeline)
=====================================

initial setup
=============

This pipeline attempts to install all important dependencies
locally. It does rely on a python binary installed elsewhere to create
the virtualenv - this is specified as an environment variable;
otherwise, $(which python) is used by default. I use python 2.7.5 built
in my home directory::

  PYTHON=~/local/bin/python bin/bootstrap.sh

Because long paths seem not to be tolerated in shebang lines,
bootstrap.sh uses virtualenv's `--relocatable` option to make paths
relative. It's best to install additional python packages by adding
them to `requirements.txt` and re-running the above command. If the
virtualenv is active, you don't need to specify the python
interpreter.

And yeah, initial setup takes a while, mostly because numpy is a
dependency of several packages and needs to be compiled.

`bootstrap.sh` also installs pplacer (binaries) and Infernal 1.1 (from
source).
