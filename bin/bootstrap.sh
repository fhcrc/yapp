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
REQFILE=$YAPP/requirements.txt

if [[ $1 == '-h' || $1 == '--help' ]]; then
    echo "Create a virtualenv and install all pipeline dependencies"
    echo "Options:"
    echo "--venv            - path of virtualenv [$VENV]"
    echo "--python          - path to an alternative python interpreter [$PYTHON]"
    echo "--wheelstreet     - path to directory containing python wheels; wheel files will be"
    echo "                    in a subdirectory named according to the python interpreter version"
    echo "                    (eg '2.7.5') [$WHEELSTREET]"
    echo "--no-python-deps  - skip installation of python dependencies"
    exit 0
fi

while true; do
    case "$1" in
	--venv ) VENV="$2"; shift 2 ;;
	--python ) PYTHON="$2"; shift 2 ;;
	--wheelstreet ) WHEELSTREET=$(readlink -f "$2"); shift 2 ;;
	--no-python-deps ) PYTHON_DEPS=no; shift 1 ;;
	* ) break ;;
    esac
done

# non-configurable options hard-coded here...
PPLACER_INSTALL_TYPE=binary
PPLACER_BINARY_VERSION=1.1
PPLACER_BUILD_VERSION=1.1.alpha16
INFERNAL_VERSION=1.1
VSEARCH_VERSION=1.1.3
SCONS_VERSION=2.3.5
WHEELSTREET=

mkdir -p src

# mkvenv creates the virtualenv using an up to date version of
# virtualenv if not available on the system, enforcing the
# installation order specified in the requirements file. This also
# provides setuptools and pip.
(cd src && \
	wget -q -N https://raw.githubusercontent.com/nhoffman/mkvenv/0.2.2/mkvenv/mkvenv.py)

if $PYTHON src/mkvenv.py init --check; then
    USE_CACHE=""
else
    USE_CACHE="--no-cache"
fi

if [[ -n $PYTHON_DEPS ]]; then
    echo "skipping installation of python dependencies"
else
    # install packages in $REQFILE as well as the virtualenv package
    $PYTHON src/mkvenv.py install --venv "$VENV" -r "$REQFILE" "$USE_CACHE" virtualenv
fi

$VENV/bin/virtualenv -q --relocatable "$VENV"
source $VENV/bin/activate

# make sure we use the absolute path
VENV=$VIRTUAL_ENV

# scons can't be installed using pip
# if [ ! -f $VENV/bin/scons ]; then
if ! $VENV/bin/scons --version 2> /dev/null | grep -q "$SCONS_VERSION"; then
    echo "scons $SCONS_VERSION not installed in $VENV"
    (cd src && \
    	    wget -N http://bitbucket.org/scons/scons/downloads/scons-${SCONS_VERSION}.tar.gz && \
    	    tar -xf scons-${SCONS_VERSION}.tar.gz && \
    	    cd scons-${SCONS_VERSION} && \
    	    python setup.py install
    )
else
    echo "$(which scons) is already installed"
fi

if [[ $PPLACER_INSTALL_TYPE == "binary" ]]; then
    function srcdir(){
	tar -tf $1 | head -1
    }

    PPLACER_TGZ=pplacer-v${PPLACER_BINARY_VERSION}-Linux.tar.gz
    if ! $VENV/bin/pplacer --version | grep -q "$PPLACER_BUILD_VERSION"; then
	mkdir -p src && \
	    (cd src && \
	    wget -N http://matsen.fhcrc.org/pplacer/builds/$PPLACER_TGZ && \
	    tar -xf $PPLACER_TGZ && \
	    cp $(srcdir $PPLACER_TGZ)/{pplacer,guppy,rppr} $VENV/bin && \
	    pip install -U $(srcdir $PPLACER_TGZ)/scripts && \
	    rm -r $(srcdir $PPLACER_TGZ))
	# confirm that we have installed the requested build
	if ! $VENV/bin/pplacer --version | grep -q "$PPLACER_BUILD_VERSION"; then
	    echo -n "Error: you requested pplacer build $PPLACER_BUILD_VERSION "
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
	    cp ${INFERNAL}/binaries/* $VENV/bin && \
	    rm -r ${INFERNAL}
	)
fi

# install VSEARCH
vsearch_is_installed(){
    $VENV/bin/vsearch --version | grep -q "$VSEARCH_VERSION"
}

if vsearch_is_installed; then
    echo -n "vsearch $VSEARCH_VERSION is already installed: "
else
    (cd src && \
	    wget -N https://github.com/torognes/vsearch/releases/download/v${VSEARCH_VERSION}/vsearch-${VSEARCH_VERSION}-linux-x86_64 && \
	    mv vsearch-${VSEARCH_VERSION}-linux-x86_64 $VENV/bin && \
	    chmod +x $VENV/bin/vsearch-${VSEARCH_VERSION}-linux-x86_64 && \
	    ln -f $VENV/bin/vsearch-${VSEARCH_VERSION}-linux-x86_64 $VENV/bin/vsearch)
fi

# install FastTree
bin/install_fasttree.sh --prefix "$VENV" --srcdir src

