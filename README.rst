=====================================
 yapp (yet another pplacer pipeline)
=====================================

initial setup
=============

This pipeline attempts to install all important dependencies
locally. It does rely on a python binary installed elsewhere - this is
specified in the initial setup::

  PYTHON=~/local/bin/python bin/bootstrap.sh

Because long paths seem not to be tolerated in shebang lines,
bootstrap.sh uses virtualenv's --relocatable option to make paths
relative. It's best to install additional python packages by adding
them to `requirements.txt` and re-running the above command. If the
virtualenv is active, you don't need to specify the python
interpreter.

And yeah, this is a pain, mostly because numpy is a dependency of
several packages and needs to be compiled.
