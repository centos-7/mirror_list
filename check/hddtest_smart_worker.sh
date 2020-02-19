#!/bin/bash

disk=$1
serials=$2

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

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

MODE="$3"
echo "Mode: $MODE"
# send abort status, if signal catched
#  
#
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  send hddsmart-result "ABORT" "Aborted! [$STARTTIME - $(date +%d.%m.\ %H:%M)]" "$serials"
  sleep 1
  }
trap "abort ; kill -9 $$" 1 2 9 15

# send starting status
   send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serials"
#
# start read test for the device
    echo "read ~50GB data from $disk before SMART TEST starts"
    echo "no log for the read test"
    echo ""
    if [ -n "$(echo "$disk" | grep sd)" ]; then
      dd if=$disk count=100000000 | pv -s 48G | dd of=/dev/null
    fi
    echo ""
# check for SSD
#
if [ "$(smartctl $4 -a $disk | grep SSD)" ]; then
  send hddsmart-result "OK" "Finished (SSD not supported, Device: $disk_wo_dev);" "$serials"
  echo "SSD erkannt"
else
  # start smarttest
  #
  STARTTIME="$(date +%d.%m.\ %H:%M)"
  send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serials"
  power_on_hours=$(smartctl $4 -a $disk | grep Power_On_Hours | awk '{print $10}')

  echo "$STARTTIME" > $LOGDIR/hddtest-$serials.log
  echo "" >> $LOGDIR/hddtest-$serials.log
  echo "####################################################" >> $LOGDIR/hddtest-$serials.log
  echo "######                                        " >> $LOGDIR/hddtest-$serials.log
  echo "######            start SMART test            " >> $LOGDIR/hddtest-$serials.log
  echo "######               MODE: $MODE              " >> $LOGDIR/hddtest-$serials.log
  echo "######  command: smartctl $4 -t $MODE $disk   " >> $LOGDIR/hddtest-$serials.log
  echo "######                                        " >> $LOGDIR/hddtest-$serials.log
  echo "####################################################" >> $LOGDIR/hddtest-$serials.log
  echo "" >> $LOGDIR/hddtest-$serials.log
  echo "Power On Hours $power_on_hours" >> $LOGDIR/hddtest-$serials.log
  echo "" >> $LOGDIR/hddtest-$serials.log


  starttest=$(smartctl $4 -t $MODE $disk) 
  echo $starttest >> $LOGDIR/hddtest-$serials.log

  TIMING="$(cat $LOGDIR/hddtest-$serials.log | egrep -o "Please wait (.*) minutes for test to complete." | cut -d" " -f3)"
  echo "duration time: $TIMING minutes"
  if [ -n "$TIMING" ]; then
    SECONDS="$[$TIMING*60]"
  else
    SECONDS="600"
  fi

  stat="250"
  while [ "$stat" -gt "0" ]; do
    stat="$(smartctl $4 -c $disk | grep "^Self-test" | awk -F'(' '{print $2}' | awk '{print $1}' | awk -F')' '{print $1}')"
  #  echo "smartctl $4 -c $disk | grep ^Self-test | awk -F'(' '{print $2}' | awk '{print $1}' | awk -F')' '{print $1}'"
    if [ "$stat" -gt "0" ]; then
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
    fi
    # read actually procent
    stat="$(smartctl $4 -c $disk | grep "^Self-test" | awk -F'(' '{print $2}' | awk '{print $1}' | awk -F')' '{print $1}')"
    # check if failed
    failed=$(smartctl $4 -c $disk | grep "failed")
    if [ -n "$failed" ]; then
      echo "Self-test failed..."
      stat=0
    fi
    prozent="$(echo $stat | sed 's/^.//' | sed 's/^.//')"
    if [ -n "$prozent" ]; then
      prozent="$[$prozent*10]"
    else
      prozent="0"
    fi
    echo " "
    echo "$prozent% remaining"
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
  echo "###### command: smartctl $4 -t -l selftest $disk  " >> $LOGDIR/hddtest-$serials.log
  echo "######                                            " >> $LOGDIR/hddtest-$serials.log
  echo "########################################################" >> $LOGDIR/hddtest-$serials.log
  echo "" >> $LOGDIR/hddtest-$serials.log

  smartctl $4 -l selftest $disk >> $LOGDIR/hddtest-$serials.log
  #erg="$(cat $LOGDIR/hddtest-$serials.log | grep "^# 1" | awk -F'%' '{print $2}' | awk -F' ' '{print $2}')"
  ERG="$(cat $LOGDIR/hddtest-$serials.log | grep "^# 1" | grep "Completed without error")"
  #ERG_LSI="$(grep "No Errors Logged" $LOGDIR/hddtest-$serials.log)"
  #ERG_LSI_TIME="$(grep "$STARTTIME" $LOGDIR/hddtest-$serials.log)"
  if [ -n "$ERG" ]; then
    echo "Completed without errors"
    send hddsmart-result "OK" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
  else
    echo "Completed with errors"
    echo "hdd_smart_test:error:hdd:too many badblocks at $disk_wo_dev" >> $ROBOT_LOGFILE
    send hddsmart-result "ERROR" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
  fi
fi
#rm $LOGDIR/hddtest-$serials.log
