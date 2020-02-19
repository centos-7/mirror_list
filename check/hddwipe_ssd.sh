#!/bin/bash

#
# this script offers a small menu to control the
# automated hardware checks
#
# david.mayr@hetzner.de - 2007.08.06
#

# setting new PATH
PATH=$PATH:/usr/local/bin
export PATH


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

#
# include menu.functions.conf
. $PWD/hddwipe_ssd.function

main "$@"
