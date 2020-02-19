#!/bin/bash

#
# bash script to create / delete raids on lsi controller
#

PWD="$(dirname $0)"
. $PWD/config

LSI_LOGFILE="/tmp/raid_lsi.log"
LSI_LOG="tee -a $LSI_LOGFILE"

# is a lsi megaraid controller built in?
echo_white "Looking for lsi megaraid controller ..."
get_lsi 2>&1 | $LOG
if [ $? != 0 ]; then
  echo_yellow "No lsi megaraid controller found, thus cannot configure raid."
  sleep 1
  exit 0
fi

sleep 2

while [ answer != "e" -a answer != "E" ] ; do
  clear
  echo_yellow "==================================================="
  echo_white " Create RAID on LSI-Controller for hwbau"
  echo_yellow "==================================================="
  echo_white " Select from the following options"
  echo_yellow "==================================================="
  echo_white "   C    clear raid"
  echo
  echo_white "   1    RAID1"
  echo_white "   2    RAID1 (2x)"
  echo_white "   4    RAID10"
  echo_white "   5    RAID5"
  echo_white "   0    RAID0 (3rd hdd)"
  echo_white "   6    RAID6 (15 hdds)"
  echo
  echo_white "   L    Read raid logfile"
  echo_white "   E    Exit"
  echo_yellow "==================================================="
  echo -n " Your choice: "
  read -n1 answer
  echo
  echo_yellow "==================================================="
  echo
  case $answer in
    e|E) break ;;
    l|L)
      less $LSI_LOGFILE
      ;;
    c|C)
      echo_white "You chose \"REMOVE raid\""
      echo_yellow "Start removing raids ..."
      megacli -CfgLdDel -Lall -aAll 2>&1 | $LSI_LOG
      if [ $? -eq 0 ] ; then
        echo_green " DONE - all raids removed!"
      else
        echo_red " FAILED - no raids have been removed!"
      fi
      ;;
    1)
      echo_white "You chose \"Create 1x RAID1 over first two hdds\""
      echo_yellow "Start creating raid ..."
      megacli -CfgLdAdd -r1 [252:0,252:1] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG
      if [ $? -eq 0 ] ; then
        echo_green " DONE - RAID1 created!"
      else
        echo_red " FAILED - no raids have been created!"
      fi
      ;;
    5)
      echo_white "You chose \"Create 1x RAID5 over first three hdds\""
      echo_yellow "Start creating raid ..."
      megacli -CfgLdAdd -r5 [252:0,252:1,252:2] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG
      if [ $? -eq 0 ] ; then
        echo_green " DONE - RAID5 created!"
      else
        echo_red " FAILED - no raids have been created!"
      fi
      ;;
    4)
      echo_white "You chose \"Create 1x RAID10 over first four hdds\""
      echo_yellow "Start creating raid ..."
      megacli -CfgSpanAdd -r10 -Array0[252:0,252:1] Array1[252:2,252:3] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG
      if [ $? -eq 0 ] ; then
        echo_green " DONE - RAID10 created!"
      else
        echo_red " FAILED - no raids have been created!"
      fi
      ;;
    2)
      echo_white "You chose \"Create 2x RAID1 over first four hdds\""
      echo_yellow "Start creating raid ..."
      EXITCODE=0
      megacli -CfgLdAdd -r1 [252:0,252:1] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG ; EXITCODE=$?
      megacli -CfgLdAdd -r1 [252:2,252:3] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG ; EXITCODE=$?
      if [ $EXITCODE -eq 0 ] ; then
        echo_green " DONE - two RAID1 created!"
      else
        echo_red " FAILED - no raids have been created!"
      fi
      ;;
    0)
      echo_white "You chose \"Create 1x RAID0 over third hdd\""
      echo_yellow "Start creating raid ..."
      megacli -CfgLdAdd -r0 [252:2] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG
      if [ $? -eq 0 ] ; then
        echo_green " DONE - RAID0 created!"
      else
        echo_red " FAILED - no raids have been created!"
      fi
      ;;
    6)
      echo_white "You chose \"Create 1x RAID6 over 15 hdds\""
      echo_yellow "Start creating raid ..."
      megacli -CfgLdAdd -r6 [245:0,245:1,245:2,245:3,245:4,245:5,245:6,245:7,245:8,245:9,245:10,245:11,245:12,245:13,245:14] WB RA Direct CachedBadBBU -a0 2>&1 | $LSI_LOG
      if [ $? -eq 0 ] ; then
        echo_green " DONE - RAID6 created!"
      else
        echo_red " FAILED - no raids have been created!"
      fi
      ;;
    *)
      echo_red "No valid input!"
      ;;
  esac
  echo "press RETURN for menu"
  read key
done

rm $LSI_LOGFILE > /dev/null
exit 0

