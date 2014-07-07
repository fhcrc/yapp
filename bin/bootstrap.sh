#!/bin/bash
# Usage: bin/bootstrap.sh [Options]

# Create a virtualenv, and install requirements to it.

# override the default python interpreter using
# `PYTHON=/path/to/python bin/bootstrap.sh`

set -e

# options configurable from the command line
GREP_OPTIONS=--color=never
VENV=$(basename $(pwd))-env
YAPP=$(cd $(dirname $BASH_SOURCE) && cd .. && pwd)
PYTHON=$(which python)
PY_VERSION=$($PYTHON -c 'import sys; print "{}.{}.{}".format(*sys.version_info[:3])')
PPLACER_VERSION=binary
WHEELSTREET=$(readlink -f ~/wheelstreet)
REQFILE=$YAPP/requirements.txt

if [[ $1 == '-h' || $1 == '--help' ]]; then
    echo "Create a virtualenv and install all pipeline dependencies"
    echo "Options:"
    echo "--venv            - path of virtualenv [$VENV]"
    echo "--python          - path to an alternative python interpreter [$PYTHON]"
    echo "--pplacer-version - git branch, tag, or sha (or 'binary' to use latest binaries) [$PPLACER_VERSION]"
    echo "--wheelstreet     - path to directory containing python wheels; wheel files will be"
    echo "                    in a subdirectory named according to the python interpreter version"
    echo "                    (eg '2.7.5') [$WHEELSTREET]"
    echo "--requirements    - an alternative requiremets file [$REQFILE]"
    exit 0
fi

while true; do
    case "$1" in
	--venv ) venv="$2"; shift 2 ;;
	--python ) PYTHON="$2"; shift 2 ;;
	--pplacer-version ) PPLACER_VERSION="$2"; shift 2 ;;
	--wheelstreet ) WHEELSTREET=$(readlink -f "$2"); shift 2 ;;
	--requirements ) REQFILE="$2"; shift 2 ;;
	* ) break ;;
    esac
done

# non-configurable options hard-coded here...
PPLACER_BINARY_VERSION=1.1
PPLACER_BUILD=1.1.alpha16
VENV_VERSION=1.11.6
INFERNAL_VERSION=1.1
WHEELHOUSE=

if [[ ! -z $WHEELSTREET ]]; then
    WHEELHOUSE=$WHEELSTREET/$PY_VERSION
    test -d $WHEELHOUSE || (echo "cannot access $WHEELHOUSE"; exit 1)
fi

mkdir -p src

# Create the virtualenv using a specified version of the virtualenv
# source. This also provides setuptools and pip. Inspired by
# http://eli.thegreenplace.net/2013/04/20/bootstrapping-virtualenv/

# create virtualenv if necessary
if [ ! -f ${VENV:?}/bin/activate ]; then
    # download virtualenv source if necessary
    if [ ! -f src/virtualenv-${VENV_VERSION}/virtualenv.py ]; then
	VENV_URL='https://pypi.python.org/packages/source/v/virtualenv'
	(cd src && \
	    wget -N ${VENV_URL}/virtualenv-${VENV_VERSION}.tar.gz && \
	    tar -xf virtualenv-${VENV_VERSION}.tar.gz)
    fi
    $PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py $VENV
    $PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py --relocatable $VENV
else
    echo "found existing virtualenv $VENV"
fi

source $VENV/bin/activate

# install python packages from pipy or wheels
grep -v -E '^#|git+|^-e' $REQFILE | while read pkg; do
    if [[ -z $WHEELHOUSE ]]; then
	pip install $pkg
    else
	pip install --use-wheel --find-links=$WHEELHOUSE $pkg
    fi
done

# install packages from git repos; we're assuming that any
# dependencies have already been installed above
pip install --no-deps -r <(grep git+ $REQFILE | grep -v -E '^#')

# scons can't be installed using pip
if [ ! -f $VENV/bin/scons ]; then
    (cd src && \
	wget -N http://downloads.sourceforge.net/project/scons/scons/2.3.0/scons-2.3.0.tar.gz && \
	tar -xf scons-2.3.0.tar.gz && \
	cd scons-2.3.0 && \
	python setup.py install
    )
else
    echo "scons is already installed in $(which scons)"
fi

if [[ $PPLACER_VERSION == "binary" ]]; then
    function srcdir(){
	tar -tf $1 | head -1
    }

    PPLACER_TGZ=pplacer-v${PPLACER_BINARY_VERSION}-Linux.tar.gz
    if ! $VENV/bin/pplacer --version | grep -q "$PPLACER_BUILD"; then
	mkdir -p src && \
	    (cd src && \
	    wget -N http://matsen.fhcrc.org/pplacer/builds/$PPLACER_TGZ && \
	    tar -xf $PPLACER_TGZ && \
	    cp $(srcdir $PPLACER_TGZ)/{pplacer,guppy,rppr} ../$VENV/bin && \
	    pip install -U $(srcdir $PPLACER_TGZ)/scripts && \
	    rm -r $(srcdir $PPLACER_TGZ))
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
    mkdir -p src && \
	(cd src && \
	wget -N http://selab.janelia.org/software/infernal/${INFERNAL}.tar.gz && \
	for binary in cmalign cmconvert esl-alimerge esl-sfetch esl-reformat; do
	    tar xvf ${INFERNAL}.tar.gz --no-anchored binaries/$binary
	done && \
	    cp ${INFERNAL}/binaries/* ../$VENV/bin && \
	    rm -r ${INFERNAL}
	)
fi

# correct any more shebang lines
virtualenv --relocatable $VENV
