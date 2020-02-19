#!/bin/bash

#
# hddwipe wrapper
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function
. $PWD/hddwipe.functions

main_worker "$@"
