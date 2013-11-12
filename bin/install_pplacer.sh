#!/bin/bash

# Install OPAM (binary) and the ocaml interpreter (compiled), and
# pplacer and dependencies (compiled). Requires various system
# dependencies described here:
# http://matsen.github.io/pplacer/compiling.html

function abspath(){
    # no readlink -f on Darwin, unfortunately
    python -c "import os; print os.path.abspath(\"$1\")"
}

set -e

PREFIX=/usr/local
SRCDIR=/usr/local/src

OPAM_VERSION='1.1.0'
OCAML_VERSION='4.01.0'
PPLACER_VERSION=master
PIP=$(which pip || echo "")

if [[ $1 == '-h' || $1 == '--help' ]]; then
    echo "Install OPAM, the ocaml interpreter, and pplacer"
    echo "Options:"
    echo "--prefix          - base dir for binaries (eg, \$PREFIX/bin/pplacer) [$PREFIX]"
    echo "--srcdir          - path for downloads and compiling [$SRCDIR]"
    echo "--opamroot        - sets \$OPAMROOT [\$PREFIX/share/opam]"
    echo "--pip             - path to pip for installing python scripts [$PIP]"
    echo "--pplacer-version - git branch, tag, or sha [$PPLACER_VERSION]"
    echo "--opam-version    - opam binary version [$OPAM_VERSION]"
    echo "--ocaml-version   - ocaml interpreter version [$OCAML_VERSION]"
    exit 0
fi

while true; do
    case "$1" in
	--prefix ) PREFIX="$(abspath $2)"; shift 2 ;;
	--srcdir ) SRCDIR="$(abspath $2)"; shift 2 ;;
	--opamroot ) OPAMROOT="$(abspath $2)"; shift 2 ;;
	--pip ) PIP="$(abspath $2)"; shift 2 ;;
	--pplacer-version ) PPLACER_VERSION="$2"; shift 2 ;;
	--opam-version ) OPAM_VERSION="$2"; shift 2 ;;
	--ocaml-version ) OCAML_VERSION="$2"; shift 2 ;;
	* ) break ;;
    esac
done

if [[ ! -w $PREFIX ]]; then
    echo "$PREFIX is not writable - you probably want to run using sudo"
    exit 1
fi

OPAMROOT=${OPAMROOT-$PREFIX/share/opam}

mkdir -p $SRCDIR

# Install OPAM; see http://opam.ocaml.org/doc/Quick_Install.html -
# below is a greatly simplified version of
# http://www.ocamlpro.com/pub/opam_installer.sh
OPAM=$PREFIX/bin/opam
if $OPAM --version | grep -q $OPAM_VERSION; then
    echo "opam version $OPAM_VERSION is already installed in $PREFIX/bin"
else
    OPAM_FILE="opam-${OPAM_VERSION}-$(uname -m)-$(uname -s)"
    wget -P $SRCDIR -N http://www.ocamlpro.com/pub/$OPAM_FILE
    chmod +x $SRCDIR/$OPAM_FILE
    cp $SRCDIR/$OPAM_FILE $PREFIX/bin
    ln -f $PREFIX/bin/$OPAM_FILE $OPAM
fi

$OPAM init --root $OPAMROOT --comp $OCAML_VERSION --no-setup

# Install remote repository for pplacer
if $OPAM repo --root $OPAMROOT  list | grep -q pplacer-deps; then
    echo pplacer-deps is already a remote repository
else
    $OPAM repo --root $OPAMROOT add pplacer-deps http://matsen.github.com/pplacer-opam-repository
fi

$OPAM update --root $OPAMROOT pplacer-deps

PPLACER_SRC=$SRCDIR/pplacer
if [[ -d $PPLACER_SRC ]]; then
    (cd $PPLACER_SRC && git fetch --all && git reset --hard origin/master)
else
    git clone https://github.com/matsen/pplacer.git $PPLACER_SRC
fi

cd $PPLACER_SRC
git checkout $PPLACER_VERSION

# Note: batteries.2.0.0 fails to build on ubuntu 12.04 - leaving the
# version unspecified seems to work, and pplacer still seems to
# complile. So we exclude batteries from opam-requirements.txt and
# install separately below.
for dep in $(grep -v batteries opam-requirements.txt); do
    $OPAM install --root $OPAMROOT -y $dep
done
$OPAM install --root $OPAMROOT -y batteries

eval $($OPAM config --root $OPAMROOT env)
make
cp $PPLACER_SRC/bin/{pplacer,guppy,rppr} $PREFIX/bin

# install python scripts
if [[ ! -z $PIP ]]; then
    $PIP install -U $PPLACER_SRC/scripts
else
    python setup.py install $PPLACER_SRC/scripts --prefix=$PREFIX
fi
