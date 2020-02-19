#!/bin/bash
#
# This script tests the status of the lsi megaraid controller
#
# nadine.doegow@hetzner.de - 2011.10.13
#


# read configuration file
PWD="$(dirname $0)"
. $PWD/config

# send abort status
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send lsi_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15

echo_yellow "\n===== LSI MegaRAID Controller TEST =====\n"

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send lsi_result "WORKING" "Start $STARTTIME" "-"

# is a lsi megaraid controller built in?
echo_white "Looking for lsi megaraid controller ..."
get_lsi 2>&1 | $LOG
if [ $? != 0 ]; then
  echo_yellow "No lsi megaraid controller found, thus cannot test."
  send lsi_result "NONE" "No raid controller found" "-"
  sleep 1
  exit 0
fi


# check the raid controller status
echo_white "\nCheck raid controller status ..."

RAIDSTATUS="$(megacli -LDInfo -Lall -Aall 2>&1)"
echo "$RAIDSTATUS" | $LOG
megacli -LDInfo -Lall -Aall 2>&1 | $LOG

ARRAYSTATUSES="$(echo -e "$RAIDSTATUS" | grep "State" | awk '{print $3}' )"
for ARRAYSTATUS in $ARRAYSTATUSES ; do
  if [ $ARRAYSTATUS != 'Optimal' ] ; then
    false
    catch_error "RAID Array ist nicht OK."
    echo "raid:error:array:the raid array is not ok" >> $ROBOT_LOGFILE
  fi
done  


# Endtime
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

# evaluate ERRORMSG, eventually filled by catch_error()
send_status "lsi_result"


