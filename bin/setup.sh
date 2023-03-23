#!/bin/bash

PYTHON=${PYTHON-python3}
venv="$(pwd)/yapp-env"

if [[ -d $venv ]]; then
    echo "$venv already exists"
else
    $PYTHON -m venv "$venv"
fi

"$venv/bin/pip" install -U pip wheel
"$venv/bin/pip" install -r requirements.txt

