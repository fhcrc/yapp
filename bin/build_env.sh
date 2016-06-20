#!/bin/bash

# Create a virtualenv, and install requirements to it.

set -e -o pipefail

# use the active virtualenv if it exists
if [[ -z $VIRTUAL_ENV ]]; then
    VENV="$(basename $(pwd))-env"
else
    VENV="$VIRTUAL_ENV"
fi

PPLACER_INSTALL_TYPE=binary  # anything other than "binary" installs from source

# non-configurable options hard-coded here...
PPLACER_BUILD=1.1.alpha17

# make sure the base directory is yapp/
basedir=$(readlink -f $(dirname $(dirname $0)))
cd $basedir

mkdir -p src

virtualenv "$VENV"
# shebang lines in deeply nested directories may be too long; this is
# fixed by making the venv "relocatable".
virtualenv --relocatable $VENV
source $VENV/bin/activate
VENV="$VIRTUAL_ENV"  # ensure we're using the absolute path

# upgrade some packages; using 'python -m pip' bypasses long shebang
# line issue.
python -m pip install --upgrade pip wheel setuptools

# Preserve the order of installation. The requirements are sorted so
# that secondary (and higher-order) dependencies appear first. See
# bin/pipdeptree2requirements.py. We use --no-deps to prevent various
# packages from being repeatedly installed, uninstalled, reinstalled,
# etc.
while read pkg; do
    python -m pip install "$pkg" --no-deps --upgrade
done < <(/bin/grep -v -E '^#|^$' "$basedir/requirements.txt")
virtualenv --relocatable "$VENV"

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

# install infernal (cmalign) and easel binaries
bin/install_infernal_and_easel.sh --prefix "$VENV" --srcdir src

# install VSEARCH
bin/install_vsearch.sh --prefix "$VENV" --srcdir src

# install FastTree
bin/install_fasttree.sh --prefix "$VENV" --srcdir src

# install swarm
swarmwrapper install --prefix "$VENV"

# make sure long shebang line issue is fixed for all python scripts
virtualenv --relocatable $VENV
