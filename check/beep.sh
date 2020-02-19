#!/bin/bash

#
# this script just lets the pc speaker beep a while
#
# david.mayr@hetzner.de - 2007.08.23


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


(
  for i in $(seq 0 10)
  do
    $BEEP -f1000 -n -f2500 -n -f1750 -l500
  done
) &

