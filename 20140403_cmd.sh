#!/bin/bash

set -e

# bin/bootstrap.sh

# run using grabfullnode
source project-overbaugh-env/bin/activate
scons use_cluster=no

