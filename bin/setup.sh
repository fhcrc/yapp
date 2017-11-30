#!/bin/bash

venv="py3-env"

if [[ -d $venv ]]; then
    echo "$venv already exists"
    exit 1
fi

python3 -m venv "$venv"

while read pkg; do
    "$venv/bin/pip" install "$pkg" --upgrade
done < requirements.txt
