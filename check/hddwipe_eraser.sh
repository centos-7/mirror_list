#!/bin/bash

#
# wipe all found harddisks on this computer.
# use at your own risk!
# 
# by david.mayr(at)hetzner.de, 2008.10
#


# load hwcheck functions
#
PWD=$(dirname $0)
. $PWD/config
. $PWD/report.function


# get some important data about the disk
#
if [ "$1" -a "$2" ] ; then
  disk=$1
  shift
  serials=$@
else
  echo "Usage:  $0  </dev/your_disk> <serial(s)>"
  exit 1
fi

#
# add new hwcheck report system (rz-admin.new)
send2 info "$serials" "HDD"
HDDWIPE_ID="$(send2 test "$serials" "WIPE" "working" "preparing")"
echo "HDDWIPE-START: $HDDWIPE_ID" > /tmp/report


size=$(get_hdd_size $disk)
sizeKB=$(get_hdd_size $disk kb)
cache=$(get_hdd_cache $disk)
cacheMB="$[$cache/1024]M"
model=$(get_hdd_model $disk)
model_text="$model (${cache}K)"
mac="$(get_mac)"


# send abort status, if signal catched
#
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
}
trap "abort ; kill -9 $$" 1 2 9 15

# wait some time before starting, to have a chance to cancel ...
#
echo_red "DISK  $disk  will be DELETED in $HDDWIPE_SLEEP seconds!\nPress CTRL-C to abort now! "
sleep_dots $HDDWIPE_SLEEP ; echo


# define erase function
#
erase() {
  [ $# -ne 4 ] && return "PARAM ERROR"
  my_disk=$1
  my_pattern=$2
  my_size=$3
  my_text=$4
  count=0
  countfile="/tmp/$(basename $0)_count_$(basename $my_disk)_$$"
  echo 1 > $countfile
  until false ; do
  #until [ $count -gt 10 ] ; do
    count=$[$count+1]
    # output data
    cat $PWD/data/hddwipe.${my_pattern} ; EXITCODE=$?
    # break if disk is full
    if [ $EXITCODE -ne 0 ] ; then
      echo $count > $countfile
      break
    fi
  # write data
  done | pv -brtpe -s${my_size}K -i1 -N"$my_text" | dd of=$my_disk bs=1M conv=fdatasync 2>&1 
  # check if we really filled up the disk
  count="$(cat $countfile)"
  [ $[$count*1024] -lt $my_size ] && return 1 || return 0
  sleep 2
}


# set mode
#
case $HDDWIPE_MODE in
  DoD5220.22-M-E)
    steps=3
    patterns="10101010 random 01010101"
  ;;
  DoD5220.22-M-ECE)
    steps=7
    patterns="10101010 random 01010101 random 10101010 random 01010101"
  ;;
  VSTIR)
    steps=7
    patterns="00000000 11111111 00000000 11111111 00000000 11111111 10101010"
  ;;
  *)
    echo_red "Illegal mode! see $0 ..."
    exit 1
  ;;
esac

# start erasing
#
c=0
ERRORMSG=""
STARTTIME="$(date +%d.%m.\ %H:%M)"
echo_green "\nUsing $HDDWIPE_MODE mode, time is now $STARTTIME"
echo_yellow "Start $disk ($(echo $model | sed 's/%20/ /g') [$serials] $(echo $size | cut -d: -f2))"
time1=$(date +%s)
for pattern in $patterns ; do
  c=$[$c+1]
  CURTIME="$(date +%d.%m.\ %H:%M)"
  text="$(basename $disk)/$serials - run $c/$steps ($pattern)"
  echo_cyan "\n$text"

  #
  # send wipe to new.rz-admin
  SUBTEST_ID="$(send2 subtest "$HDDWIPE_ID" "WIPE-$pattern" "working" "starting")"
  echo "HDDWIPE-WIPE-$pattern: $SUBTEST_ID" >> /tmp/report

  erase $disk $pattern $sizeKB "$text" ; ERROR=$?
  if [ "$ERROR" -ne 0 ]; then
    ERRORMSG="${ERRORMSG}Error at step $c, "
    echo "hdd_wipe:error:$disk:$disk Error at step $c" >> $ROBOT_LOGFILE
    send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-$pattern\": \"ERROR\" }" > /dev/null
    echo "HDDWIPE-WIPE-$pattern-ERROR: $SUBTEST_ID" >> /tmp/report
  else
    send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-$pattern\": \"OK\" }" > /dev/null
    echo "HDDWIPE-WIPE-$pattern-OK: $SUBTEST_ID" >> /tmp/report
  fi
  send2 finished "$SUBTEST_ID" > /dev/null
  echo "HDDWIPE-WIPE-$pattern-finish: $SUBTEST_ID" >> /tmp/report
  send2 update_message "$SUBTEST_ID" "finished" > /dev/null
  echo "HDDWIPE-WIPE-$pattern-finish-message: $SUBTEST_ID" >> /tmp/report
done


echo " "

#
# send wipe to new.rz-admin
SUBTEST_ID="$(send2 subtest "$HDDWIPE_ID" "WIPE-CHECK" "working" "starting")"
echo "HDDWIPE-WIPE-CHECK-START: $SUBTEST_ID" >> /tmp/report
 
#Check Wipe
  #Find out the sector count
    sectors=$(hdparm -g $disk | grep sector | tr "," "\n" | grep sectors | cut -d' ' -f4)

  #Calculate the middle and the last 512 Bytes
    middle="$(echo "$sectors/2" | bc -l | cut -d'.' -f1)"
    last="$(echo "$sectors-10240" | bc -l)"
  #Read the first 5M
    dd if=$disk bs=512 count=10240 of=/tmp/testfile-$serial
    if [ -e /tmp/testfile-$serial ]; then
      if [ -n "$(diff /tmp/testfile-$serial /root/.oldroot/nfs/check/data/hddwipe_checkfile_5M)" ]; then
        echo "hdd_wipe:error:$disk:$disk MBR Wipe FAILED" >> $ROBOT_LOGFILE
        echo "HDD_WIPE_CHECK: MBR: $disk Wipe FAILED"
        ERRORMSG="${ERRORMSG}MBR-Check: Not Wiped!!, " 
        send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-MBR-CHECK\": \"ERROR\" }" > /dev/null
        echo "HDDWIPE-WIPE-CHECK-MBR-LOG-ERROR: $SUBTEST_ID" >> /tmp/report
      else
        echo "HDD_WIPE_CHECK: MBR: $disk Wipe OK" 
        send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-MBR-CHECK\": \"OK\" }" > /dev/null
        echo "HDDWIPE-WIPE-CHECK-MBR-LOG-OK: $SUBTEST_ID" >> /tmp/report
      fi  
    else
      ERRORMSG="${ERRORMSG}File Error MBR-Check, "
      echo "HDD_WIPE_CHECK: MBR: $disk File Error - Check FAILED"
      echo "hdd_wipe:error:$disk:$disk MBR: File Error - Check FAILED" >> $ROBOT_LOGFILE
      send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-MBR-CHECK\": \"FAILED\" }" > /dev/null
      echo "HDDWIPE-WIPE-CHECK-MBR-LOG-FAILED: $SUBTEST_ID" >> /tmp/report
    fi

    rm /tmp/testfile-$serial
  #Read the middle 5M
    dd if=$disk bs=512 count=10240 of=/tmp/testfile-$serial skip=$middle
    if [ -e /tmp/testfile-$serial ]; then
      if [ -n "$(diff /tmp/testfile-$serial /root/.oldroot/nfs/check/data/hddwipe_checkfile_5M)" ]; then
        echo "hdd_wipe:error:$disk:$disk Middle Wiped FAILED" >> $ROBOT_LOGFILE
        echo "HDD_WIPE_CHECK: Middle: $disk Wipe FAILED"
        ERRORMSG="${ERRORMSG}Middle-Check: Not Wiped!!, " 
        send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-MIDDLE-CHECK\": \"ERROR\" }" > /dev/null
        echo "HDDWIPE-WIPE-CHECK-MIDDLE-LOG-ERROR: $SUBTEST_ID" >> /tmp/report
      else
        echo "HDD_WIPE_CHECK: Middle: $disk Wipe OK" 
        send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-MIDDLE-CHECK\": \"OK\" }" > /dev/null
        echo "HDDWIPE-WIPE-CHECK-MIDDLE-LOG-OK: $SUBTEST_ID" >> /tmp/report
      fi
    else
      ERRORMSG="${ERRORMSG}File Error Middle-Check!!, "
      echo "HDD_WIPE_CHECK: Middle: $disk File Error - Check FAILED"
      echo "hdd_wipe:error:$disk:$disk Middle: File Error - Check FAILED" >> $ROBOT_LOGFILE
      send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-MIDDLE-CHECK\": \"FAILED\" }" > /dev/null
      echo "HDDWIPE-WIPE-CHECK-MIDDLE-LOG-FAILED: $SUBTEST_ID" >> /tmp/report
    fi

    rm /tmp/testfile-$serial
  #Read the last 5M
    dd if=$disk bs=512 count=10240 of=/tmp/testfile-$serial skip=$last
    if [ -e /tmp/testfile-$serial ]; then
      if [ -n "$(diff /tmp/testfile-$serial /root/.oldroot/nfs/check/data/hddwipe_checkfile_5M)" ]; then
        echo "hdd_wipe:error:$disk:$disk End Wipe FAILED" >> $ROBOT_LOGFILE
        echo "HDD_WIPE_CHECK: End: $disk Wipe FAILED"
        ERRORMSG="${ERRORMSG}End-Check: Not Wiped!!, " 
        send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-END-CHECK\": \"ERROR\" }" > /dev/null
        echo "HDDWIPE-WIPE-CHECK-END-LOG-ERROR: $SUBTEST_ID" >> /tmp/report
      else
        echo "HDD_WIPE_CHECK: End: $disk Wipe OK"
        send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-END-CHECK\": \"OK\" }" > /dev/null
        echo "HDDWIPE-WIPE-CHECK-END-LOG-OK: $SUBTEST_ID" >> /tmp/report
      fi
    else
      ERRORMSG="${ERRORMSG}File Error End-Check!!, "
      echo "HDD_WIPE_CHECK: End: $disk File Error - Check FAILED"
      echo "hdd_wipe:error:$disk:$disk End: File Error - Check FAILED" >> $ROBOT_LOGFILE
      send2 test_log_json "$SUBTEST_ID" "{ \"WIPE-END-CHECK\": \"FAILED\" }" > /dev/null
      echo "HDDWIPE-WIPE-CHECK-END-LOG-FAILED: $SUBTEST_ID" >> /tmp/report
    fi
    send2 finished "$SUBTEST_ID" > /dev/null
    echo "HDDWIPE-WIPE-CHECK-finish: $SUBTEST_ID" >> /tmp/report
    send2 update_message "$SUBTEST_ID" "finished" > /dev/null
    echo "HDDWIPE-WIPE-CHECK-finish-message: $SUBTEST_ID" >> /tmp/report

    rm /tmp/testfile-$serial



ENDTIME="$(date +%d.%m.\ %H:%M)"
time2=$(date +%s)


# send result status
#
echo_yellow "\nErasing finished at $ENDTIME, sending status ...\n"
if [ -z "$ERRORMSG"  ] ; then
  echo "Ok"
else
  echo_red "$ERRORMSG"
fi

sleep 2

