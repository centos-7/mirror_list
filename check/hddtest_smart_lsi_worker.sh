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
  echo "Usage:  $0  </dev/your_disk> <serial(s)> "
  exit 1
fi


MODE="$3"
echo "$MODE"
sleep 20
size=$(get_hdd_size $disk)
sizeKB=$(get_hdd_size $disk kb)
cache=$(get_hdd_cache $disk)
cacheMB="$[$cache/1024]M"
model=$(get_hdd_model $disk)
model_text="$model (${cache}K)"
mac="$(get_mac)"


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
  

# start smarttest
#
STARTTIME="$(date +%d.%m.\ %H:%M)"
send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serials"
power_on_hours=$(/usr/sbin/smartctl $4 -a $disk | grep Power_On_Hours | awk '{print $10}')
power_on_hours_sas=$(/usr/sbin/smartctl $4 -a $disk | grep -i power | awk '{print $7}')

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
echo "Power On Hours $power_on_hours $power_on_hours_sas" >> $LOGDIR/hddtest-$serials.log
echo "" >> $LOGDIR/hddtest-$serials.log


starttest=$(/usr/sbin/smartctl $4 -t $MODE $disk)
echo $starttest >> $LOGDIR/hddtest-$serials.log


TIMING="$(cat $LOGDIR/hddtest-$serials.log | egrep -o "Please wait (.*) minutes for test to complete." | cut -d" " -f3)"
echo "duration time: $TIMING minutes"
if [ -n "$TIMING" ]; then
  SECONDS="$[$TIMING*60]"
else
  SECONDS="600"
fi
#rm $LOGDIR/hddtest-$serials.tmp


#COUNTER=0
#if [ $SECONDS ]; then 
#  if [ "$SECONDS" -gt "600" ]; then  
#    WERT="$(echo "$SECONDS/600" | bc -l | awk -F'.' '{print $2}')"
#    WERT="0.$WERT" 
#    WERT="$(echo "$WERT*600" | bc -l | awk -F'.' '{print $1}')"
#    COUNTER="$[600-$WERT]"
#  fi
#  for ((i=$SECONDS; i>=1; i--)); do
#    if [ "$COUNTER" == "600" ]; then
#      COUNTER=0
#      echo " "
#      echo "finished in $(($i/60)) minutes"
#    fi
#    sleep 1
#    echo -n "."
#    COUNTER="$[$COUNTER+1]"
#  done
#else
#  echo "sleep 10 sek"
#fi
#echo " "

stat="250"
while [ "$stat" -gt "0" ]; do
  lsi_stat="$(/usr/sbin/smartctl $4 -a $disk | grep "# 1" | grep "NOW")"
  if [ -n "$lsi_stat" ]; then 
    stat="5"
  else
    stat="0"
  fi
  
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
    echo " "
    echo "unknown % remaining"
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
ERG_LSI="$(cat $LOGDIR/hddtest-$serials.log | grep "^# 1" | grep "Completed  ")"
if [ "$ERG_LSI" ]; then
  echo "Completed without errors"
  send hddsmart-result "OK" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
else
  echo "Completed with errors"
  echo "hdd_smart_test:error:hdd:too many badblocks at $disk_wo_dev" >> $ROBOT_LOGFILE
  send hddsmart-result "ERROR" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"

fi
#rm $LOGDIR/hddtest-$serials.log
