#!/bin/bash

#
# this script sends a periodic livesign
# in the background to the monitoring server
#
# david.mayr@hetzner.de - 2007.08.08


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function


(
  until false ; do
    send2 update > /dev/null
    sleep 180
  done
) &

