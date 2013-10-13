#!/bin/bash

# Create virtualenv, install scons from source, and install
# requirements in requirements.txt

# override the default python interpreter using
# `PYTHON=/path/to/python bin/setup.sh`

set -e

if [[ -z $1 ]]; then
    venv=$(basename $(pwd))-env
else
    venv=$1
fi

mkdir -p src

# bootstrap a recent version of virtualenv; inspired by
# http://eli.thegreenplace.net/2013/04/20/bootstrapping-virtualenv/
VENV_VERSION=1.10.1
PYPI_VENV_BASE='http://pypi.python.org/packages/source/v/virtualenv'
if [[ -z $PYTHON ]]; then
    PYTHON=$(which python)
fi

# download virtualenv source if necessary
if [ ! -f src/virtualenv-${VENV_VERSION}/virtualenv.py ]; then
    (cd src && \
	wget -N ${PYPI_VENV_BASE}/virtualenv-${VENV_VERSION}.tar.gz && \
	tar -xf virtualenv-${VENV_VERSION}.tar.gz)
fi

# create virtualenv if necessary
if [ ! -f $venv/bin/activate ]; then
    $PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py $venv
    $PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py --relocatable $venv
else
    echo "found existing virtualenv $venv"
fi

source $venv/bin/activate

# scons can't be installed using pip
if [ ! -f $venv/bin/scons ]; then
    (cd src && \
	wget -N http://downloads.sourceforge.net/project/scons/scons/2.3.0/scons-2.3.0.tar.gz && \
	tar -xf scons-2.3.0.tar.gz && \
	cd scons-2.3.0 && \
	python setup.py install
    )
else
    echo "scons is already installed in $(which scons)"
fi

# get pplacer binaries and python scripts
PPLACER_VERSION=1.1
PPLACER_TGZ=pplacer-v${PPLACER_VERSION}-Linux.tar.gz
if [ ! -f $venv/bin/pplacer ]; then
    mkdir -p src && \
	(cd src && \
	wget -N http://matsen.fhcrc.org/pplacer/builds/$PPLACER_TGZ && \
	tar -xf pplacer-v1.1-Linux.tar.gz && \
	cp $(tar -tf $PPLACER_TGZ | head -1)/{pplacer,guppy,rppr} ../$venv/bin && \
	cp $(tar -tf $PPLACER_TGZ | head -1)/scripts/*.py ../$venv/bin)
fi

# install infernal
INFERNAL_VERSION=1.1rc4
venv_abspath=$(readlink -f $venv)
if [ ! -f $venv/bin/cmalign ]; then
    mkdir -p src && \
	(cd src && \
	wget -N http://selab.janelia.org/software/infernal/infernal-${INFERNAL_VERSION}.tar.gz && \
	tar -xf infernal-${INFERNAL_VERSION}.tar.gz && \
	cd infernal-${INFERNAL_VERSION} && \
	./configure --prefix=$venv_abspath --enable-mpi && \
	make && make install && \
	cd easel && make install)
fi

# install other python packages
pip install -r requirements.txt

# correct any more shebang lines
$PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py --relocatable $venv
