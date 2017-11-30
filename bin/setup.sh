#!/bin/bash

PYTHON=$(PYTHON-python3)
venv="py3-env"

if [[ -d $venv ]]; then
    echo "$venv already exists"
    exit 1
fi

$PYTHON -m venv "$venv"

while read pkg; do
    "$venv/bin/pip" install "$pkg" --upgrade
done < requirements.txt
