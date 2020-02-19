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
  disk_wo_dev=$(echo $disk | cut -d/ -f3)
  serials=$2
else
  echo "Usage:  $0  </dev/your_disk> <serial(s)>"
  exit 1
fi

EXTENSION="$4"
MODE="$3"
echo "$MODE"

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
  send hddsmart-result "ABORT" "Aborted! [$STARTTIME - $(date +%d.%m.\ %H:%M)]" "$serials"
  smartctl -X $disk
  sleep 1
  }
trap "abort ; kill -9 $$" 1 2 9 15

# start read test for the device
echo "read ~50GB data from $disk before SMART TEST starts"
echo "no log for the read test"
echo ""
if [ -n "$(echo "$disk" | grep sd)" ]; then
   dd if=$disk count=100000000 | pv -s 48G | dd of=/dev/null
fi
echo ""

#
# add new hwcheck report system (rz-admin.new)
send2 info "$serials" "HDD"
HDDTEST_ID="$(send2 test "$serials" "HDDTEST${STRESSTEST_TESTNUMBER}" "working" "preparing")"

STARTTIME="$(date +%d.%m.\ %H:%M:%S)"
power_on_hours=$(/usr/sbin/smartctl $4 -a $disk | grep Power_On_Hours | awk '{print $10}')
power_on_hours_sas=$(/usr/sbin/smartctl $4 -a $disk | grep -i power | awk '{print $7}')

echo "$STARTTIME" > $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log
echo "####################################################" >> $LOGDIR/hddtest-$serials.log
echo "######                                        " >> $LOGDIR/hddtest-$serials.log
echo "######            start SMART test            " >> $LOGDIR/hddtest-$serials.log
echo "######               MODE: $MODE              " >> $LOGDIR/hddtest-$serials.log
echo "######  command: smartctl $EXTENSION -t $MODE $disk   " >> $LOGDIR/hddtest-$serials.log
echo "######                                        " >> $LOGDIR/hddtest-$serials.log
echo "####################################################" >> $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log
echo "Power On Hours $power_on_hours $power_on_hours_sas" >> $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log


local SUBTEST_ID="$(send2 subtest "$HDDTEST_ID" "SELFTEST-Check" "working" "starting")"
local LOGFILE="hddtest_smart.selftest.before.$serials.log"
smartctl $EXTENSION -l selftest $disk > $LOGDIR/$LOGFILE
send2 test_log_raw "$SUBTEST_ID" "sas_before_log" "$LOGDIR/$LOGFILE"

i=1
while [ $i -le 3 ]; do
  starttest=$(smartctl $EXTENSION -t $MODE $disk)
  if [ -n "$(echo $starttest | grep "self test failed")" ]; then
    echo "Couldn't start test." >> $LOGDIR/hddtest-$serials.log
    if [ "$(checkForRunningTests $disk)" == "test running" ]; then
      echo "Reason: Another test is running..." >> $LOGDIR/hddtest-$serials.log
    else
      echo "Reason: Unknown" >> $LOGDIR/hddtest-$serials.log
    fi
    #echo $starttest >> $LOGDIR/hddtest-$serials.log
    if [ $i -eq 3 ]; then
      send hddsmart-result "ERROR" "Couldn't start test" "$serials"
      echo "hdd_smart_test:error:no test started at $disk_wo_dev" >> $ROBOT_LOGFILE
      exit 1;
    else
      send hddsmart-result "WAITING" "Couldn't start test, try again in few minutes..." "$serials"
    fi
    echo "Try again in 5 minutes..." >> $LOGDIR/hddtest-$serials.log
    #sleep 300
    sleep 10
    i=$[$i+1];
  else
    echo $starttest >> $LOGDIR/hddtest-$serials.log
    # success, exit loop
    i=4
  fi
done

# start smarttest
#
STARTTIME="$(date +%d.%m.\ %H:%M)"
send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serials"
echo "Test started at ${STARTTIME}"

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

#stat="in processs"
while [ "$(checkForRunningTests $disk)" == "test running" ]; do
  #stat="$(smartctl $EXTENSION -l selftest $disk | grep "Self test in progress ...")"
  #if [ -n "$stat" ]; then
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
  #fi
  # update stat
  #stat="$(smartctl $EXTENSION -l selftest $disk | grep "Self test in progress ...")"
  echo " "
  echo "test still running (procent unknown)..."
done


ENDTIME="$(date +%H:%Mh)"


# check test result
#

echo "" >> $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log
echo "$ENDTIME" >> $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log
echo "########################################################" >> $LOGDIR/hddtest-$serials.log
echo "######                                            " >> $LOGDIR/hddtest-$serials.log
echo "######           Check SMART Test Result          " >> $LOGDIR/hddtest-$serials.log 
echo "######                 MODE: $MODE                " >> $LOGDIR/hddtest-$serials.log
echo "###### command: smartctl $EXTENSION -l selftest $disk  " >> $LOGDIR/hddtest-$serials.log
echo "######                                            " >> $LOGDIR/hddtest-$serials.log
echo "########################################################" >> $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log


local LOGFILE="hddtest_smart.selftest.after.$serials.log"
smartctl $EXTENSION -l selftest $disk > $LOGDIR/$LOGFILE
send2 test_log_raw "$SUBTEST_ID" "sas_after_log" "$LOGDIR/$LOGFILE" > /dev/null
send2 finished "$SUBTEST_ID" > /dev/null
send2 update_message "$SUBTEST_ID" "finished" > /dev/null

smartctl $EXTENSION -l selftest $disk >> $LOGDIR/hddtest-$serials.log
#erg="$(cat $LOGDIR/hddtest-$serials.log | grep "^# 1" | awk -F'%' '{print $2}' | awk -F' ' '{print $2}')"
ERG="$(cat $LOGDIR/hddtest-$serials.log | grep "^# 1" | grep "Completed")"
if [ "$ERG" ]; then
  echo "Completed without errors"
  send hddsmart-result "OK" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
else
  echo "Completed with errors"
  echo "hdd_smart_test:error:hdd:too many badblocks at $disk_wo_dev" >> $ROBOT_LOGFILE
  send hddsmart-result "ERROR" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"

fi
echo "$HDDTEST_ID"
send2 finished "$HDDTEST_ID" > /dev/null
read
#rm $LOGDIR/hddtest-$serials.log

