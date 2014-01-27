#!/bin/bash

set -e

# run all using
# salloc -n12 ./run-analysis.sh

refpkg_ft=data/urogenital-named-20130610.infernal1.1.refpkg
refpkg_rx=data/urogenital-named-20130610.infernal1.1-raxml.refpkg

# want: {dev,318}/{fasttree,raxml}/AT and 318/{fasttree,raxml}/OSAT

(source 20140123-dev-env/bin/activate
    # dev FT AT
    scons -f SConstruct virtualenv=20140123-dev-env use_cluster=no out=output-dev-FT-AT refpkg=$refpkg_ft

    # dev RX AT
    scons -f SConstruct virtualenv=20140123-dev-env use_cluster=no out=output-dev-RX-AT refpkg=$refpkg_rx

    # dev FT OSAT
    scons -f SConstruct-byspecimen virtualenv=20140123-dev-env use_cluster=no out=output-dev-FT-OSAT refpkg=$refpkg_ft

    # dev RX OSAT
    scons -f SConstruct-byspecimen virtualenv=20140123-dev-env use_cluster=no out=output-dev-RX-OSAT refpkg=$refpkg_rx

)

(source 20140123-318-env/bin/activate

    # 318 FT AT
    scons -f SConstruct virtualenv=20140123-318-env use_cluster=no out=output-318-FT-AT refpkg=$refpkg_ft

    # 318 RX AT
    scons -f SConstruct virtualenv=20140123-318-env use_cluster=no out=output-318-RX-AT refpkg=$refpkg_rx

    # 318 FT OSAT
    scons -f SConstruct-byspecimen virtualenv=20140123-318-env use_cluster=no out=output-318-FT-OSAT refpkg=$refpkg_ft
    # 318 RX OSAT
    scons -f SConstruct-byspecimen virtualenv=20140123-318-env use_cluster=no out=output-318-RX-OSAT refpkg=$refpkg_rx
)


(source 20140123-dev-env/bin/activate && scons -f SConstruct-compare)
