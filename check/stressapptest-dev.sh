#!/bin/bash

#
# this script runs stress test
#
# Patrick.Tausch@hetzner.de - 2013.02.28

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/stressapptest-dev.functions
. $PWD/report.function

main "$@"
