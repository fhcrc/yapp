#!/bin/bash

PYTHON=${PYTHON-python3}
venv="$(pwd)/yapp-env"

if [[ -d $venv ]]; then
    echo "$venv already exists"
else
    $PYTHON -m venv "$venv"
fi

while read pkg; do
    "$venv/bin/pip" install "$pkg" --upgrade
done < requirements.txt

# if --relocatable becomes necessary: https://gist.github.com/wynemo/3310583

# install pplacer and accompanying python scripts
PPLACER_BUILD=1.1.alpha19
PPLACER_DIR=pplacer-Linux-v${PPLACER_BUILD}
PPLACER_ZIP=${PPLACER_DIR}.zip
PPLACER_GH="https://github.com/matsen/pplacer"

pplacer_is_installed(){
    $venv/bin/pplacer --version 2> /dev/null | grep -q "$PPLACER_BUILD"
}

if pplacer_is_installed; then
    echo -n "pplacer is already installed: "
    $venv/bin/pplacer --version
else
    mkdir -p src && \
	(cd src && \
	wget -nc --quiet $PPLACER_GH/releases/download/v$PPLACER_BUILD/$PPLACER_ZIP && \
	unzip -o $PPLACER_ZIP && \
	cp $PPLACER_DIR/{pplacer,guppy,rppr} $venv/bin)
    # confirm that we have installed the requested build
    if ! pplacer_is_installed; then
	echo -n "Error: you requested pplacer build $PPLACER_BUILD "
	echo "but $($venv/bin/pplacer --version) was installed."
	echo "Try removing src/$PPLACER_ZIP first."
	exit 1
    fi
fi

(cd src &&
     wget -nc https://www.sqlite.org/2018/sqlite-tools-linux-x86-3230100.zip &&
     unzip -o sqlite*.zip '*/sqlite3' &&
     cp "$(find -name sqlite3)" $venv/bin
 )
