#!/bin/bash

python3 -m venv yapp-env
source yapp-env/bin/activate

pip install -U pip wheel
pip install -r requirements.txt
