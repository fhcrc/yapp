#!/bin/bash

set -e

# bin/bootstrap.sh --pplacer-version 318-placement-specific-mask

# run using
# salloc -n12 ./20140130_cmd.sh

(source project-overbaugh-env/bin/activate
    scons -f SConstruct use_cluster=no
    scons -f SConstruct-byspecimen use_cluster=no
)
