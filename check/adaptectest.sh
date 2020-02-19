#!/bin/bash

#
# this script tests the status of the adaptec raid controller
#
# david.mayr@hetzner.de - 2010.03.30


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send adaptec_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  Adaptec RAID TEST  =====\n"

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send adaptec_result "WORKING" "Start $STARTTIME" "-"



# do we have a adaptec raid controller built in?
#
echo_white "Looking for adaptec raid controller ..."
get_adaptec 2>&1 | $LOG
if [ $? != 0 ] ; then
  echo_yellow "No adaptec raid controller found, thus cannot test."
  send adaptec_result "NONE" "No raid controller found" "-"
  sleep 1
  exit 0
fi



# check the raid controller status
#
echo_white "\nCheck raid controller status..."

RAIDSTATUS="$(arcconf getconfig 1 ld 2>&1)"
echo "$RAIDSTATUS" | $LOG
arcconf getstatus 1 2>&1 | $LOG

ARRAYSTATUSES="$(echo -e "$RAIDSTATUS" | grep "Status of logical device" | cut -d: -f2 | tr -d ' ')"
for ARRAYSTATUS in $ARRAYSTATUSES ; do
  if [ $ARRAYSTATUS != 'Optimal' ] ; then
    false
    catch_error "RAID Array ist nicht OK."
    echo "raid:error:array:the raid array is not ok" >> $ROBOT_LOGFILE
  fi
done


###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "adaptec_result"


