#!/bin/bash

# salloc -n 12 scons classifier=nbc
# salloc -n 12 scons classifier=nbc dedup=no
# salloc -n 12 scons classifier=hybrid2
# salloc -n 12 scons classifier=hybrid2 dedup=no
# salloc -n 12 scons classifier=pplacer
# salloc -n 12 scons classifier=pplacer dedup=no

# use grabfullnode
scons classifier=hybrid2 dedup=no
scons classifier=hybrid2
scons classifier=nbc dedup=no
scons classifier=nbc
scons classifier=pplacer dedup=no
scons classifier=pplacer
