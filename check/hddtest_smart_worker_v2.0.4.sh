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
EXTENSION="$4"
STRESSTEST="$5"

echo "Mode: $MODE, Extension: $EXTENSION, Stresstest: $STRESSTEST"

# send abort status, if signal catched
#  
#
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  send hddsmart-result "ABORT" "Aborted! [$STARTTIME - $(date +%d.%m.\ %H:%M)]" "$serials"
  sleep 1
  }
trap "abort ; kill -9 $$" 1 2 9 15

#
# get health status from hdd
check_hdd_health() {
  # send status
  send hddsmart-result "WORKING" "Start (Health-Check, Device: $disk_wo_dev)" "$serials"
  echo -n "Health Check:" >> $LOGDIR/hddtest-$serials.log
  echo "Start: Health Check" 

  SMART_HEALTH=$(smartctl $EXTENSION -H $disk | egrep "FAILED!|SAVE ALL DATA|FAILING_NOW")

  if [ -n "$SMART_HEALTH" ]; then
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\n$SMART_HEALTH\n")
    ERROR_CHECK="HEALTH-Check"
  else
    echo "      OK" >> $LOGDIR/hddtest-$serials.log
  fi
}

#
# check smart all values 
check_smart_values() {
  # send status
  send hddsmart-result "WORKING" "Start (Values-Check, Device: $disk_wo_dev)" "$serials"
  echo -n "SMART VALUES:" >> $LOGDIR/hddtest-$serials.log
  echo "Start: Values Check" 

  SMART_FAILING_NOW=$(smartctl $EXTENSION -A $disk | sed 's/^[ \t]*//' | grep '^[0-9]' | grep NOW)
  if [ -n "$SMART_FAILING_NOW" ]; then
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\n$SMART_FAILING_NOW\n")
    ERROR_CHECK="Values-Check"
  fi
  
  #
  # read SMART values and LBA Errors and store
  SMART_LBA_Error=0
  SMART_EXTEND=$(smartctl $EXTENSION -x $disk | sed 's/^[ \t]*//' | egrep '^[0-9]{1,3}\ [A-Z]|^Error\ [1-9]|^Lifetime|^Min/Max.*Limit')

  while read line; do
    # Spin Up Time
    [ "$(echo $line | grep ^3)" ] && SMART_SUT="$(echo $line | awk '{print $8}')"
    # Reallocated Sector Count
    [ "$(echo $line | grep ^5)" ] && SMART_RSC="$(echo $line | awk '{print $8}')"
    # Spin Retry Count
    [ "$(echo $line | grep ^10)" ] && SMART_SRC="$(echo $line | awk '{print $8}')"
    # Current Pending Sector
    [ "$(echo $line | grep ^197)" ] && SMART_CPS="$(echo $line | awk '{print $8}')"
    # Offline Uncorrectable
    [ "$(echo $line | grep ^198)" ] && SMART_OU="$(echo $line | awk '{print $8}')"
    # LBA Error Count
    [ "$(echo $line | grep ^Error)" ] && [ "$(echo $line | grep ^Error | awk '{print $2}')" -gt "$SMART_LBA_Error" ] && SMART_LBA_Error=$(echo $line | grep ^Error | awk '{print $2}') 
    # Max Lifetime Temperature
    [ "$(echo $line | grep ^Lifetime)" ] && SMART_MLT=$(echo $line | grep ^Lifetime | egrep -o '[0-9]{1,3}\/[0-9]{1,3}' | cut -d/ -f2 ) 
    # Max Temperature Limit (manufactuerer)
    [ "$(echo $line | grep ^Min/Max)" ] && SMART_MTL=$(echo $line | grep ^Min/Max | egrep -o '[0-9]{1,3}\/[0-9]{1,3}' | cut -d/ -f2 ) 
  done <<< "$SMART_EXTEND"

  #
  #  prepare log data
  SMART_VALUES=$(echo -e "SUT:$SMART_SUT\nRSC:$SMART_RSC\nSRC:$SMART_SRC\nCPS:$SMART_CPS\nOU:$SMART_OU\nLBA_ER:$SMART_LBA_Error\nTemperature (Limit/Max):$SMART_MTL/$SMART_MLT")

  #
  # if max Temp is set add 5°C
  if [ -n "$SMART_MTL" ]; then
    SMART_MTL=$(echo "$SMART_MTL+5" | bc -q)
  fi

  if ( [ -z "$FAILED" ] && [ "$SMART_SUT" -gt "12000" ] ) ; then 
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\nError:Spin_up_time:$SMART_SUT > 12000\n")
    ERROR_CHECK="Values-Check"
  fi
  if ( [ -z "$FAILED" ] && [ "$SMART_RSC" -gt "2000" ] ); then
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\nError:Reallocated_Sector_Count:$SMART_RSC > 2000\n")
    ERROR_CHECK="Values-Check"
  fi
  if ( [ -z "$FAILED" ] && [ "$SMART_RSC" -gt "1000" ] && [ "$SMART_LBA_Error" -gt "400" ] ); then
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\nError:Reallocated_Sector_Count:$SMART_RSC > 1000 AND LBA_ERROR:$SMART_LBA_ERROR > 400\n")
    ERROR_CHECK="Values-Check"
  fi
  if ( [ -z "$FAILED" ] && [ "$SMART_SRC" -gt "0" ] ); then
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\nError:Spin_Retry_Count:$SMART_SRC > 0\n")
    ERROR_CHECK="Values-Check"
  fi
  if ( [ -z "$FAILED" ] && [ "$SMART_CPS" -gt "500" ] && [ "$SMART_OU" -gt "500" ] ); then
    FAILED=1
    ERROR_MSG=$(echo -e "      FAILED\n\n\n====TEST DETAIL====\nError:Current_Pending_Sector:$SMART_CPS > 500 AND Offline_Uncorrectable:$SMART_OU > 500\n")
    ERROR_CHECK="Values-Check"
  fi
  if ( [ -z "$FAILED" ] && [ "$SMART_MLT" -gt "$SMART_MTL" ] ); then
    FAILED_TEMP=1
    ERROR_MSG_TEMP=$(echo -e "\n\n\n====TEST DETAIL====\nError:Max_Lifetime_Temperature:$SMART_MLT > Max_Temperature_Limit(manufacturer):$SMART_MTL\n")
    ERROR_CHECK="Values-Check-Temp"
  fi
  [ -z "$FAILED" ] && echo "      OK" >> $LOGDIR/hddtest-$serials.log
}

#
# start read test
start_read_test() {
  # send status
  send hddsmart-result "WORKING" "Start (Read-Check, Device: $disk_wo_dev)" "$serials"
  echo "Start: Read Test"
  echo -n "Read Test:" >> $LOGDIR/hddtest-$serials.log
  if [ -n "$(echo "$disk" | grep sd)" ]; then
    DD_OUTPUT="$(dd if=$disk bs=1M count=102400 | pv -brtpe -s100G -i1 -N"Read 100GiB" | dd of=/dev/null 2>&1)"
  fi
  echo "         OK" >> $LOGDIR/hddtest-$serials.log
}

#
# check dmesg
check_dmesg() {
  echo -n "DMESG Check:" >> $LOGDIR/hddtest-$serials.log
  DEVICE="$(echo $disk | cut -d/ -f3)"
  DMESG="$(dmesg | awk "/$DEVICE/&&/[E|e]rror/" | tail -n2)"
  if [ -n "$DMESG" ]; then
    FAILED=1
    ERROR_MSG=$(echo -e "       FAILED\n\n\n====TEST DETAIL====\n$DMESG\n")
    ERROR_CHECK="DMESG-Check"
  else
    echo "       OK" >> $LOGDIR/hddtest-$serials.log
  fi
}

#
# start selftest
start_selftest() {
  #
  # start selftest
  echo -n "SELFTEST:" >> $LOGDIR/hddtest-$serials.log
  starttest=$(smartctl $EXTENSION -t $MODE $disk) 

  send hddsmart-result "WORKING" "Start (Selftest, Device: $disk_wo_dev)" "$serials"
  TIMING="$(echo $starttest | egrep -o "Please wait (.*) minutes for test to complete." | cut -d" " -f3)"
  echo "duration time: $TIMING minutes"
  if [ -n "$TIMING" ]; then
    SECONDS="$[$TIMING*60]"
  else
    SECONDS="600"
  fi

  stat="250"
  while [ "$stat" -gt "0" ]; do
    stat="$(smartctl $EXTENSION -c $disk | grep "^Self-test" | awk -F'(' '{print $2}' | awk '{print $1}' | awk -F')' '{print $1}')"
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
    stat="$(smartctl $EXTENSION -c $disk | grep "^Self-test" | awk -F'(' '{print $2}' | awk '{print $1}' | awk -F')' '{print $1}')"
    # check if failed
    failed=$(smartctl $EXTENSION -c $disk | grep "failed")
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
  selftest_result=$(smartctl $EXTENSION -l selftest $disk)
  if [ "$(echo "$selftest_result" | grep "^# 1" | grep "Completed without error")" ]; then
    echo "Completed without errors"
    echo "          OK" >> $LOGDIR/hddtest-$serials.log 
    send hddsmart-result "OK" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
  else
    FAILED=1
    ERROR_MSG=$(echo -e "          FAILED\n\n\n====TEST DETAIL====\nSELFTEST-ERROR\n")
    ERROR_CHECK="Selftest"
    echo "Completed with errors"
    echo "hdd_smart_test:error:hdd:too many badblocks at $disk_wo_dev" >> $ROBOT_LOGFILE
    send hddsmart-result "ERROR" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
  fi
}

write_result_log() {
  
  if [ -n "$ERROR_MSG" ]; then
    echo "$ERROR_MSG" >> $LOGDIR/hddtest-$serials.log
  fi

  if [ -n "$ERROR_MSG_TEMP" ]; then
    echo "$ERROR_MSG_TEMP" >> $LOGDIR/hddtest-$serials.log
  fi

  if [ -n "$SMART_VALUES" ]; then
    echo -e "\n\n\n========STORED DISK VALUES========\n$SMART_VALUES" >> $LOGDIR/hddtest-$serials.log 
  fi

  REPORT_ERROR=''
  if [ -n "$FAILED" ]; then
    REPORT_ERROR=1
  fi
  if [ -n "$FAILED_TEMP" ]; then
    REPORT_ERROR=1
  fi

  if [ -z "$REPORT_ERROR" ]; then
    echo -e "\n\nDisk: $serials OK" >> $LOGDIR/hddtest-$serials.log
    send hddsmart-result "OK" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
  else
    echo -e "\n\nDisk: $serials FAIL" >> $LOGDIR/hddtest-$serials.log
    echo "hdd_smart_test:error:hdd:too many badblocks at $disk_wo_dev" >> $ROBOT_LOGFILE
    send hddsmart-result "ERROR" "Finished ($ERROR_CHECK, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serials"
  fi
}

# send starting status
   send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serials"


# check for SSD
#
if [ "$(smartctl $EXTENSION -a $disk | egrep -i "SSD|MZ7WD480HAGM|MZ7WD240HAFV")" ]; then
  echo "not Supported"
  send hddsmart-result "OK" "Finished (SSD not supported, Device: $disk_wo_dev);" "$serials"
  sleep 60;
else
  # start smarttest
  #
  STARTTIME="$(date +%d.%m.\ %H:%M)"
  send hddsmart-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serials"
  power_on_hours=$(smartctl $4 -a $disk | grep Power_On_Hours | awk '{print $10}')

  echo "Disk: $disk" > $LOGDIR/hddtest-$serials.log
  echo "$STARTTIME" >> $LOGDIR/hddtest-$serials.log
  echo "" >> $LOGDIR/hddtest-$serials.log
  echo "Power On Hours $power_on_hours" >> $LOGDIR/hddtest-$serials.log
  echo "" >> $LOGDIR/hddtest-$serials.log

  FAILED=''

  check_hdd_health
  [ -z "$FAILED" ] && check_smart_values

  [ -z "$FAILED" ] && start_read_test
  [ -z "$FAILED" ] && check_dmesg
  [ -z "$FAILED" ] && start_selftest
  
  ENDTIME="$(date +%H:%Mh)"

  write_result_log
fi

  

#rm $LOGDIR/hddtest-$serials.log
