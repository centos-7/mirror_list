#!/bin/bash

#
# this script offers a small menu to control the
# automated hardware checks
#
# patrick.tausch@hetzner.de
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
. $PWD/wipe.function

wipe_eraser "$@"
