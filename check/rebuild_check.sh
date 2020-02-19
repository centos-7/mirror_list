#!/bin/bash

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

ERROR=''
RAID="$(get_raid)"

if [ -n "$RAID" ]; then
  if [ -n "$(echo $RAID | grep -i "lsi")" ]; then
    megacli -pdlist -aall | grep -i rebuild 2<&1 > /dev/null && ERROR=1
    megacli -ldinfo -lall -aall | grep -i degraded 2<&1 > /dev/null && ERROR=1
  fi
  if [ -n "$(echo $RAID | grep -i "adaptec")" ]; then
    arcconf getconfig 1 ld | egrep -i "rebuild|degraded" 2<&1 > /dev/null && ERROR=1
  fi
  if [ -n "$(echo $RAID | grep -i "3ware")" ]; then
    CX="$(tw_cli show | grep ^c | cut -c 1-2)"
    for controller in $CX; do
      tw_cli /$controller show | egrep -i "degraded|initializing" 2<&1 > /dev/null && ERROR=1
    done
  fi
fi

#cat /proc/mdstat | grep -i rebuild

if [ -n "$ERROR" ]; then
  echo -e "Rebuild is running or RAID is degraded\nStop all Tests" > $LOGDIR/test_error.log
  echo "rebuild_check:error: Rebuild is active or RAID degraded - Check FAILED" >> $ROBOT_LOGFILE
fi
