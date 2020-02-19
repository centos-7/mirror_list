#!/bin/bash

#
# this script sends a periodic livesign
# in the background to the status server
#
# david.mayr@hetzner.de - 2007.09.14


# read in configuration file
#
PWD="$(dirname $0)"
BASENAME="$(basename $0)"
. $PWD/config
. $PWD/report.function



case $1 in

  start)
    (
      until false ; do
        send2 update > /dev/null
        sleep 60
      done
    ) &
  ;;

  *)
    # start it, if not already running
    count=$(ps c | grep -c ${BASENAME:0:8})
    if [ $count -gt 2 ] ; then
      echo "already running"
    else
      $PWD/$BASENAME start
    fi
  ;;

esac

