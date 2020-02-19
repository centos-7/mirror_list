#!/bin/bash

#
# this script runs temeratur log for stresstest
#
# Patrick.Tausch@hetzner.de - 2013.02.28


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

#
# get duration time in seconds
#if [ -z "$1" ]; then
#  exit 1
#else
#  DURATION="$1"
#fi

#
# check that stresstest is running

#PROCESSLIST="$(ps a)"
#if [ -z "$(echo "$PROCESSLIST" | grep stresstest.sh)" ]; then 
  #exit 1
#fi


#
# start 

STARTLOG="true"

while [ "$STARTLOG" = "true" ]; do
  pgrep -f "stressapptest" | while read PID; do echo -17 > /proc/$PID/oom_score_adj; done
  for hwmon_dir in $(find /sys/class/hwmon/ -type l); do
    if [ -e $hwmon_dir/name ]; then
      if [ "$(grep "coretemp" $hwmon_dir/name)" ]; then
        temp="$(cat $hwmon_dir/temp1_input)"
        echo "+${temp:0:-3}"
      fi
    fi
  done >> $LOGDIR/stresstest-temp.log
  if [ "$(cat $LOGDIR/stresstest-temp.run)" == "false" ]; then
    STARTLOG="false"
  fi
  sleep 10 
done
