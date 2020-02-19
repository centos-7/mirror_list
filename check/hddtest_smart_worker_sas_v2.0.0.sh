#!/bin/bash

disk=$1
serials=$2

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

#
# load report function 2
. $PWD/report.function

# get some important data about the disk
#
if [ "$1" -a "$2" ] ; then
  disk=$1
  disk_dev=$(echo $disk | cut -d/ -f3)
  serials=$2
else
  echo "Usage:  $0  </dev/your_disk> <serial(s)>"
  exit 1
fi

MODE="$3"
echo "$MODE"
EXTENSION="$4"
SD_DEVICE="$5"
READTEST="$6"
TESTNUMBER="$7"

echo "MODE=$MODE, EXTENSION=$EXTENSION, SD_DEVICE=$SD_DEVICE, READTEST=$READTEST, TESTNUMBER=$TESTNUMBER"
sleep 20

checkForRunningTests()
{
   device=$1
   if [ -n "$device" ]; then
     tests="$(smartctl $EXTENSION -l selftest $device | grep "Self test in progress ...")"
     if [ -n "$tests" ]; then
       echo "test running"
     else
       echo "no test running"
     fi
   else
     echo "parameter device missing"
   fi
}

# send abort status, if signal catched
#  
#
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  send hddsmart-result "ABORT" "Aborted! [$STARTTIME - $(date +%d.%m.\ %H:%M)]" "$serials" "$TESTNUMBER"
  smartctl -X $disk
  sleep 1
  }
trap "abort ; kill -9 $$" 1 2 9 15

#
# start read test
start_read_test() {
  # send status
  send hddsmart-result "WORKING" "Start (Read-Check, Device: $disk_dev)" "$serials" "$TESTNUMBER"
  local SUBTEST_ID="$(send2 subtest "$HDDTEST_ID" "READ-Check" "working" "starting")"
  echo "Start: Read Test"
  echo -n "Read Test:" >> $LOGDIR/hddtest-$serials.log
  [ -n "$SD_DEVICE" ] && READ_DISK=$SD_DEVICE
  [ -n "$(echo "$disk" | grep sd)" ] && READ_DISK="$(echo "$disk" | grep sd)"
  if [ -n "$READ_DISK" ]; then
    local LOGFILE="hddtest_smart.dmesg.$serials.log"
    DD_OUTPUT="$(dd if=$READ_DISK bs=1M count=102400 | pv -brtpe -s100G -i1 -N"Read 100GiB" | dd of=/dev/null 2>&1)"
    echo "         OK" >> $LOGDIR/hddtest-$serials.log
    DMESG=$(echo $DD_OUTPUT | tail -n 1000)
    echo "$DMESG" > $LOGDIR/$LOGFILE
    send2 test_log_raw "$SUBTEST_ID" "read_log" "$LOGDIR/$LOGFILE" > /dev/null
  else
    echo "         NOT Supported" >> $LOGDIR/hddtest-$serials.log
    send2 update_status $HDDTEST_ID "NOT-SUPPORTED"
  fi
  send2 finished "$SUBTEST_ID" > /dev/null
  send2 update_message "$SUBTEST_ID" "finished" > /dev/null
}

#
# check dmesg
check_dmesg() {
#  echo -n "DMESG Check:" >> $LOGDIR/hddtest-$serials.log
#  local SUBTEST_ID="$(send2 subtest "$HDDTEST_ID" "DMESG-Check" "working" "starting")"
#  DEVICE="$(echo $disk | cut -d/ -f3)"
#  DMESG="$(dmesg | awk "/$DEVICE/&&/[E|e]rror/" | tail -n2)"
#  if [ -n "$DMESG" ]; then
#    FAILED=1
#    ERROR_MSG=$(echo -e "       FAILED\n\n\n====TEST DETAIL====\n$DMESG\n")
#    ERROR_CHECK="DMESG-Check"
#  else
#    echo "       OK" >> $LOGDIR/hddtest-$serials.log
#  fi



  local SUBTEST_ID="$(send2 subtest "$HDDTEST_ID" "DMESG-Check" "working" "starting")"
  echo -n "DMESG Check:" >> $LOGDIR/hddtest-$serials.log
  DEVICE="$(echo $disk | cut -d/ -f3)"
  DMESG="$(dmesg | awk "/$DEVICE/&&/[Ee]rror/" | tail -n2)"
  if [ -n "$DMESG" ]; then
    FAILED=1
    ERROR_MSG=$(echo -e "       FAILED\n\n\n########## TEST DETAIL ##########\n$DMESG\n")
    ERROR_CHECK="DMESG-Check"
  else
    echo "       OK" >> $LOGDIR/hddtest-$serials.log
  fi
  local LOGFILE="hddtest_smart.dmesg.$serials.log"
  dmesg | awk "/$DEVICE/&&/[Ee]rror/" > $LOGDIR/$LOGFILE
  if [ "$(cat $LOGDIR/$LOGFILE | wc -l)" -gt "0" ]; then
    DMESG=$(cat $LOGDIR/$LOGFILE | tail -n 1000)
    echo "$DMESG" > $LOGDIR/$LOGFILE
  else
    echo "ok" > $LOGDIR/$LOGFILE
  fi
  send2 test_log_raw "$SUBTEST_ID" "dmesg_log" "$LOGDIR/$LOGFILE" > /dev/null
  send2 finished "$SUBTEST_ID" > /dev/null
  send2 update_message "$SUBTEST_ID" "finished" > /dev/null
}

#
# START SELFTEST
start_selftest(){
  echo -n "START Selftest:" >> $LOGDIR/hddtest-$serials.log

  SUBTEST_ID="$(send2 subtest "$HDDTEST_ID" "SELFTEST-Check" "working" "starting")"
  local LOGFILE="hddtest_smart.selftest.before.$serials.log"
  smartctl $EXTENSION -l selftest $disk > $LOGDIR/$LOGFILE
  send2 test_log_raw "$SUBTEST_ID" "sas_before_log" "$LOGDIR/$LOGFILE"

  starttest=$(smartctl $EXTENSION -t $MODE $disk)
  if [ -n "$(echo $starttest | grep "self test failed")" ] || [ -n "$(echo $starttest | grep "failed: No such device")" ]; then
      FAILED=1
      ERROR_MSG=$(echo -e "    FAILED\n\n\n====TEST DETAIL====\n$starttest\n")
      ERROR_CHECK="Starttest FAILED"
  else
    echo "    OK" >> $LOGDIR/hddtest-$serials.log
  fi
}

#
# check status
check_status(){
  if [ $MODE == "long" ]; then
    TIMING="$(cat $LOGDIR/hddtest-$serials.log | egrep -o "Please wait (.*) minutes for test to complete." | cut -d" " -f3)"
    echo "duration time: $TIMING minutes"
    if [ -n "$TIMING" ]; then
      SECONDS="$[$TIMING*60]"
    else
      SECONDS="600"
    fi
  else
    SECONDS="120"
  fi

  while [ "$(checkForRunningTests $disk)" == "test running" ]; do
    if [ "$SECONDS" -lt "600" ]; then
      counter=$SECONDS
    else
      counter="600"
    fi
    while [ "$counter" -gt "0" ]; do
      echo -n "."
      sleep 1
      counter="$[$counter-1]"
    done
  done
}

#
# check_result
check_result(){

  local LOGFILE="hddtest_smart.selftest.after.$serials.log"
  smartctl $EXTENSION -l selftest $disk > $LOGDIR/$LOGFILE
  send2 test_log_raw "$SUBTEST_ID" "sas_after_log" "$LOGDIR/$LOGFILE" > /dev/null
  send2 finished "$SUBTEST_ID" > /dev/null
  send2 update_message "$SUBTEST_ID" "finished" > /dev/null


  ERG="$(smartctl $EXTENSION -l selftest $disk | grep "^# 1" | grep -i "Failed")" 
  if [ -z "$ERG" ]; then
    echo -n "Selftest:" >> $LOGDIR/hddtest-$serials.log
    echo "          OK" >> $LOGDIR/hddtest-$serials.log
  else
    echo -n "Selftest:" >> $LOGDIR/hddtest-$serials.log
    echo "       FAILED" >> $LOGDIR/hddtest-$serials.log
    FAILED=1
    ERROR_MSG=$(echo -e "          FAILED\n\n\n====TEST DETAIL====\n$ERG\n")
    ERROR_CHECK="Selftest FAILED"
  fi
}

write_result_log() {
 
   if [ -n "$ERROR_MSG" ]; then
     echo "$ERROR_MSG" >> $LOGDIR/hddtest-$serials.log
   fi
 
   REPORT_ERROR=''
   if [ -n "$FAILED" ]; then
     REPORT_ERROR=1
   fi
 
   if [ -z "$REPORT_ERROR" ]; then
     echo -e "\n\nDisk: $serials OK" >> $LOGDIR/hddtest-$serials.log
     send hddsmart-result "OK" "Finished (Mode: $MODE, Device: $disk_dev); [$STARTTIME - $ENDTIME]" "$serials" "$TESTNUMBER" 
   else
     echo -e "\n\nDisk: $serials FAIL" >> $LOGDIR/hddtest-$serials.log
     echo "hdd_smart_test:error:hdd:too many badblocks at $disk_dev" >> $ROBOT_LOGFILE
     send hddsmart-result "ERROR" "Finished ($ERROR_CHECK, Device: $disk_dev); [$STARTTIME - $ENDTIME]" "$serials" "$TESTNUMBER"
   fi
 }



   STARTTIME="$(date +%d.%m.\ %H:%M)"
   send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_dev)" "$serials" "$TESTNUMBER"
 
   echo "Disk: $disk" > $LOGDIR/hddtest-$serials.log
   echo "$STARTTIME" >> $LOGDIR/hddtest-$serials.log
   echo "" >> $LOGDIR/hddtest-$serials.log
   echo "Power On Hours $power_on_hours_sas" >> $LOGDIR/hddtest-$serials.log
   echo "" >> $LOGDIR/hddtest-$serials.log
 
   FAILED=''
 
  #
  # add new hwcheck report system (rz-admin.new)
  send2 info "$serials" "HDD"
  HDDTEST_ID="$(send2 test "$serials" "HDDTEST${TESTNUMBER}" "working" "preparing")"

   SUBTEST_ID="$(send2 subtest "$HDDTEST_ID" "SASValues-Check" "working" "starting")"
   smartctl $4 -x $disk > $LOGDIR/hddtest$TESTNUMBER-$serials-full-smart.log
   send2 test_log_raw "$SUBTEST_ID" "full_smart_log" "$LOGDIR/hddtest$TESTNUMBER-$serials-full-smart.log" > /dev/null
   send2 update_message "$SUBTEST_ID" "finished" > /dev/null
   send2 finished "$SUBTEST_ID" > /dev/null

   start_selftest
   [ -z "$FAILED" ] && check_status 
   [ -z "$FAILED" ] && check_result
   [ -z "$FAILED" ] &&  start_read_test
   [ -z "$FAILED" ] && check_dmesg
 
   ENDTIME="$(date +%H:%Mh)"
 
   write_result_log
   send2 finished "$HDDTEST_ID" > /dev/null
