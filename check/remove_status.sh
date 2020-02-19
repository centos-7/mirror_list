#!/bin/bash

#
# this script resets the status of this machine
#
# david.mayr@hetzner.de - 2007.08.22


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


echo_yellow "Remove (hide) computer ..."

send remove


