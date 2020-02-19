#!/bin/bash

#
# wipe all found harddisks on this computer.
# use at your own risk!
# 
# by david.mayr(at)hetzner.de, 2008.10
#
# edit by patrick.tausch@hetzner.de - 2014.06.10
#   - add parameter to change the wipe mode
#


# load hwcheck functions
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/hddwipe_hwb.functions

main_wipe_eraser "$@"
