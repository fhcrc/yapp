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

Requirements
============

* Apptainer/Singularity
* Python 3
* SQLite

execution
=========

After cloning and entering the repository::

  # Install Apptainer/Singularity and SQLite
  ml Apptainer SQLite
  cp settings-example.conf settings.conf
  # modify settings.conf as necessary
  # Install Python dependencies
  bin/setup.sh
  source yapp-env/bin/activate

Execute the pipeline::

  scons -f SConstruct-get-data
  scons
  scons -f SConstruct-get-details && scons -f SConstruct-get-details

Docker image
============

This project provides a Docker container hosted on ghcr.io providing a
Python execution environment for some scripts. Manual build and
deployment can be performed as follows::

  bin/docker-build.sh
  bin/docker-build.sh push

Run the container::

  % docker run --platform=linux/amd64 --rm -it ghcr.io/fhcrc/yapp:latest
  Python 3.11.2 (main, Mar 23 2023, 03:00:37) [GCC 10.2.1 20210110] on linux
