#!/bin/bash

# Create a virtualenv, and install requirements to it.

# use the active virtualenv if it exists
if [[ -z $VIRTUAL_ENV ]]; then
    VENV=$(basename $(pwd))-env
else
    VENV=$VIRTUAL_ENV
fi

PPLACER_INSTALL_TYPE=binary  # anything other than "binary" installs from source

# non-configurable options hard-coded here...
PPLACER_BUILD=1.1.alpha17
INFERNAL_VERSION=1.1
VSEARCH_VERSION=1.10.2

# make sure the base directory is yapp/
basedir=$(readlink -f $(dirname $(dirname $0)))
cd $basedir

mkdir -p src

wget -nc --directory-prefix=src \
     https://raw.githubusercontent.com/nhoffman/mkvenv/master/mkvenv/mkvenv.py

python src/mkvenv.py install --venv "$VENV" -r requirements.txt

source $VENV/bin/activate
pip install -U pip

# contains the absolute path
VENV=$VIRTUAL_ENV

if [[ $PPLACER_INSTALL_TYPE == "binary" ]]; then
    PPLACER_DIR=pplacer-Linux-v${PPLACER_BUILD}
    PPLACER_ZIP=${PPLACER_DIR}.zip

    url=https://github.com/matsen/pplacer/releases/download/v${PPLACER_BUILD}/$PPLACER_ZIP

    if ! $VENV/bin/pplacer --version | grep -q "$PPLACER_BUILD"; then
	mkdir -p src && \
	    (cd src && \
		    wget -nc "$url" && \
		    unzip $PPLACER_ZIP && \
		    cp $PPLACER_DIR/{pplacer,guppy,rppr} $VENV/bin && \
		    pip install -U $PPLACER_DIR/scripts && \
		    rm -r $PPLACER_DIR)
	# confirm that we have installed the requested build
	if ! $VENV/bin/pplacer --version | grep -q "$PPLACER_BUILD"; then
	    echo -n "Error: you requested pplacer build $PPLACER_BUILD "
	    echo "but $($VENV/bin/pplacer --version) was installed"
	    exit 1
	fi
    else
	echo -n "pplacer is already installed: "
	$VENV/bin/pplacer --version
    fi
else
    opamroot=$HOME/local/share/opam
    echo "installing opam and ocaml in $opamroot and pplacer in $VENV/bin"
    bin/install_pplacer.sh \
	--prefix $VENV \
	--srcdir ./src \
	--pplacer-version $PPLACER_VERSION \
	--opamroot $opamroot
fi

# install infernal and easel binaries
INFERNAL=infernal-${INFERNAL_VERSION}-linux-intel-gcc
venv_abspath=$(readlink -f $VENV)
if [ ! -f $VENV/bin/cmalign ]; then
    mkdir -p src
    (cd src && \
	    wget -nc http://eddylab.org/software/infernal/${INFERNAL}.tar.gz && \
	    for binary in cmalign cmconvert esl-alimerge esl-sfetch esl-reformat; do
		tar xvf ${INFERNAL}.tar.gz --no-anchored binaries/$binary
	    done && \
	    cp ${INFERNAL}/binaries/* $VENV/bin && \
	    rm -r ${INFERNAL}
    )
fi

# install VSEARCH
bin/install_vsearch.sh --prefix "$VENV" --srcdir src

# install FastTree
bin/install_fasttree.sh --prefix "$VENV" --srcdir src

# install swarm
swarmwrapper install --prefix "$VENV"

# make relocatable to avoid error of long shebang lines
virtualenv --relocatable $VENV
