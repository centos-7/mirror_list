#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/hddtest_smart.functions

main "$@"
