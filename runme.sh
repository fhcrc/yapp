#!/bin/bash

set -e

scons
scons -- settings-unnamed.conf
