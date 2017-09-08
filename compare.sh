#!/bin/bash

set -e

for settings in settings-{match-qual,nofilter,match,qual}.conf; do
    scons -- $settings
done

