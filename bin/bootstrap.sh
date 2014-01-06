#!/bin/bash

# Create a virtualenv, and install requirements to it.

# override the default python interpreter using
# `PYTHON=/path/to/python bin/bootstrap.sh`

set -e

if [[ -z $1 ]]; then
    venv=$(basename $(pwd))-env
else
    venv=$1
fi

if [[ -z $PYTHON ]]; then
    PYTHON=$(which python)
fi

mkdir -p src

# Create the virtualenv using a specified version of the virtualenv
# source. This also provides setuptools and pip. Inspired by
# http://eli.thegreenplace.net/2013/04/20/bootstrapping-virtualenv/
VENV_VERSION=1.10.1
VENV_URL='http://pypi.python.org/packages/source/v/virtualenv'

# download virtualenv source if necessary
if [ ! -f src/virtualenv-${VENV_VERSION}/virtualenv.py ]; then
    (cd src && \
	wget -N ${VENV_URL}/virtualenv-${VENV_VERSION}.tar.gz && \
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

# install pplacer and python scripts - to install from source
# (includes opam and ocaml interpreter), comment/uncomment as
# necessary below.
# PPLACER_INSTALL=binary
PPLACER_INSTALL=source

# only used if PPLACER_INSTALL==source
# PPLACER_VERSION=dev
PPLACER_VERSION=318-placement-specific-mask
opamroot=$HOME/local/share/opam

if [[ $PPLACER_INSTALL == "binary" ]]; then
    function srcdir(){
	tar -tf $1 | head -1
    }

    PPLACER_VERSION=1.1
    PPLACER_TGZ=pplacer-v${PPLACER_VERSION}-Linux.tar.gz
    if [ ! -f $venv/bin/pplacer ]; then
	mkdir -p src && \
	    (cd src && \
	    wget -N http://matsen.fhcrc.org/pplacer/builds/$PPLACER_TGZ && \
	    tar -xf $PPLACER_TGZ && \
	    cp $(srcdir $PPLACER_TGZ)/{pplacer,guppy,rppr} ../$venv/bin && \
	    pip install -U $(srcdir $PPLACER_TGZ)/scripts && \
	    rm -r $(srcdir $PPLACER_TGZ))
    else
	echo -n "pplacer is already installed: "
	$venv/bin/pplacer --version
    fi
else
    echo "installing opam and ocaml in $opamroot and pplacer in $venv/bin"
    bin/install_pplacer.sh \
	--prefix $venv \
	--srcdir ./src \
	--pplacer-version $PPLACER_VERSION \
	--opamroot $opamroot
fi

# install infernal and easel binaries
INFERNAL_VERSION=1.1
INFERNAL=infernal-${INFERNAL_VERSION}-linux-intel-gcc
venv_abspath=$(readlink -f $venv)
if [ ! -f $venv/bin/cmalign ]; then
    mkdir -p src && \
	(cd src && \
	wget -N http://selab.janelia.org/software/infernal/${INFERNAL}.tar.gz && \
	for binary in cmalign cmconvert esl-alimerge esl-sfetch esl-reformat; do
	    tar xvf ${INFERNAL}.tar.gz --no-anchored binaries/$binary
	done && \
	    cp ${INFERNAL}/binaries/* ../$venv/bin && \
	    rm -r ${INFERNAL}
	)
fi

# install other python packages
pip install -r requirements.txt

# correct any more shebang lines
$PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py --relocatable $venv
