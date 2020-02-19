#!/bin/bash

#
# this script tests the status of the 3ware raid controller
#
# david.mayr@hetzner.de - 2007.08.15


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send 3ware_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  3ware RAID TEST  =====\n"

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send 3ware_result "WORKING" "Start $STARTTIME" "-"



# do we have a 3ware raid controller built in?
#
echo_white "Looking for 3ware raid controller ..."
get_3ware 2>&1 | $LOG
if [ $? != 0 ] ; then
  echo_yellow "No 3ware raid controller found, thus cannot test."
  send 3ware_result "NONE" "No raid controller found" "-"
  sleep 1
  exit 0
fi




# check the raid controller status
#
echo_white "\nCheck raid controller status..."
# get the raid controller ID
RAIDCONTROLLER=$($TW_RAIDTOOL show | tr -s ' ' |  grep -E 'c[0-9]' | cut -d ' ' -f 1)
$TW_RAIDTOOL /$RAIDCONTROLLER show 2>&1 | $LOG
DISKSNOTOK="$($TW_RAIDTOOL /$RAIDCONTROLLER show | grep "^p" | grep -v "OK")" ; DISKSSTATUS=$?
ARRAYNOTOK="$($TW_RAIDTOOL /$RAIDCONTROLLER show | grep "^u" | egrep -v "OK|INIT")" ; ARRAYSTATUS=$?
if [ $DISKSSTATUS = 0 ] ; then
  false
  catch_error "Mindestens eine Festplatte am RAID Controller ist nicht OK."
  echo "raid:error:hdd:at least on hdd is not ok" >> $ROBOT_LOGFILE
  #echo_red "At least one disk is NOT OK."
fi
if [ $ARRAYSTATUS = 0 ] ; then
  false
  catch_error "RAID Array ist nicht OK."
  echo "raid:error:array:the raid array is not ok" >> $ROBOT_LOGFILE
  #echo_red "RAID Array seems to be NOT OK."
fi



###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "3ware_result"


