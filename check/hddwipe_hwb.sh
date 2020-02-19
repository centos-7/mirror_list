#!/bin/bash

#
# this script DELETES the harddisk(s) of this machine
#
# david.mayr@hetzner.de - 2008.10.28
#
# edit by patrick.tausch@hetzner.de - 2014.06.10
#   - add parameter to change the wipe mode 


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/hddwipe_hwb.functions

main_wipe "$@"
