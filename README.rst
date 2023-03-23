=====================================
 yapp (yet another pplacer pipeline)
=====================================

overview
========

A pplacer pipleine with the following features and objectives:

* intended to contain only a single project
* flat (actions are mostly basic scons Commands without functional wrappers)
* optionally uses bioscons for dispatch to the cluster using Slurm
* creates an execution environment that relies on local copies of
  many dependencies
* supports Infernal 1.1

execution
=========

After cloning and entering the repository::

  cp settings-example.conf settings.conf
  # modify settings.conf as necessary
  bin/setup.sh
  source yapp-env/bin/activate

Execute the pipeline::

  scons -f SConstruct-get-data
  scons
  scons -f SConstruct-get-details && scons -f SConstruct-get-details

