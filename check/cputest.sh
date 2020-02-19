#!/bin/bash

#
# this script tests the CPU of this machine
#
# david.mayr@hetzner.de - 2007.08.06


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send cpu_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15


echo_yellow "\n===== CPU TEST =====\n"


ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send cpu_result "WORKING" "Start $STARTTIME" "-"


# start stress for the cpu ...
#
count=1
echo "Running $CPUTESTCOUNT tests, each takes $CPUTESTTIME seconds: "
until [ $count -gt $CPUTESTCOUNT ] ; do
  stress -c 4 -t $CPUTESTTIME -q  2>&1 | $LOG
  [ $? -ne 0 ] && ERROR=1
  if [ "$ERROR" == "1" ]; then
    catch_error "Fehler beim Testen der CPU" "ERROR"
    echo "cputest:error:cpu:error at cpu test" >> $ROBOT_LOGFILE
  fi
  echo -n '.'
  count=$(( $count + 1 ))
  if [ $exitcode != 0 ] ; then
    echo_red "\n=====> ERROR <=====\n"
    exit 1
  fi
done




###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "cpu_result"


