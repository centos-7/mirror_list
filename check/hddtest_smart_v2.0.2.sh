#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

MODE=$1

rm $LOGDIR/hddtest*
echo "$MODE"

# send abort status, if signal catched
# 
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  for hdd in $(get_disks | cut -d: -f1 | cut -d/ -f3) ; do
    serials=$(get_all_hdd_serials | grep $hdd | cut -d: -f2)
    for serial in $serials ; do
      send hddsmart-result "ABORT" "Aborted! [$STARTTIME - $(date +%Y.%m.%d\ %H:%M:%S)]" "$serial"
    done
  done
}
trap "abort ; kill -9 $$" 1 2 9 15

echo_yellow "\n=====  HARDDISK TEST (SMART)  =====\n"


# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
  cat <<EOF >$screenrc
  ## zombie on
  caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
  hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="

EOF

#
# get all disks and type

DISKS="$(get_all_hdd_types)"

#
# get lsi details if lsi controller

[ "$(echo $DISKS | grep lsi)" ] && LSI_DEVICE="$(get_lsi_hdd_device)"

#
# get each disk details and prepare the smart check

for DISK in $DISKS; do
  #
  # get disk type
  TYPE=$(echo $DISK | cut -d: -f1)

  #
  # get device
  DEVICE=$(echo $DISK | cut -d: -f2)

  #
  # get serial
  SERIAL=$(echo $DISK | cut -d: -f3)

  echo "$TYPE $DEVICE $SERIAL"
  #
  # send status
  STARTTIME="$(date +%H:%Mh)"
  #send hddtest-result  "$serial"
  send hddtest-result "WAIT" "Waiting for confirmation [$STARTTIME]..." "$serial"

  #
  # start test for ata disk
  if [ "$TYPE" == "ata" ]; then
    echo "screen -t /dev/$DEVICE bash -c 'bash $PWD/hddtest_smart_worker_v2.0.2.sh /dev/$DEVICE \"$(echo $SERIAL)\" $MODE ; sleep 2'" >> $screenrc
  fi

  #
  # start test for disk at 3ware RAID
  if [ "$TYPE" == "3ware" ]; then
    EXTENSION="-d 3ware,"
    device_count_3ware=$(echo $DISK | cut -d: -f4 | sed 's/p//g')

    extend_devs=$(ls /dev/tw[a-e]*)
    for extend_dev in $extend_devs; do
      SMART_SERIAL=$(smartctl $EXTENSION$device_count_3ware -i $extend_dev | grep Serial | cut -d: -f2)

      #
      # check serials
      if [ -n "$SERIAL" ] && [ -n "$SMART_SERIAL" ] && [ $SERIAL == $SMART_SERIAL ]; then
        echo "screen -t $extend_dev  bash -c 'bash $PWD/hddtest_smart_worker_v2.0.2.sh $extend_dev \"$(echo $SERIAL)\" $MODE \"$EXTENSION$device_count_3ware\" ; sleep 2'" >> $screenrc
      fi
    done
  fi

  #
  # start test for disk at Adaptec RAID
  if [ "$TYPE" == "adaptec" ]; then
    #
    # load sg module 
    modprobe sg >> /dev/null

    #
    # check sg devices, serials and start the test
    for i in $(ls /dev/sg[0-9]*); do
      #
      # get serial from smartctl
      # used scsi extention because they work in some cases
      SMART_SERIAL="$(smartctl -d scsi -i $i | grep Serial | cut -d":" -f2)"

      #
      # check serials
      if [ -n "$SERIAL" ] && [ -n "$SMART_SERIAL" ] && [ $SERIAL == $SMART_SERIAL ]; then
        #
        # check sas or sat disk
        if [ "$(smartctl -d sat -i $i | grep "Device Read Identity Failed")" ]; then
          #
          # sas disk - start test
          echo "screen -t $i  bash -c 'bash $PWD/hddtest_smart_sasworker.sh $i \"$(echo $SERIAL)\" $MODE \"-d scsi\" ; sleep 2'" >> $screenrc
        else
          # sat disk - start test
          echo "screen -t $i  bash -c 'bash $PWD/hddtest_smart_worker_v2.0.2.sh $i \"$(echo $SERIAL)\" $MODE \"-d sat\" ; sleep 2'" >> $screenrc
        fi 
      fi
    done
  fi

  #
  # start test for disk at LSI RAID
  if [ "$TYPE" == "lsi" ]; then
    LSI_RAID_DEVICE="$(echo $DISK | cut -d: -f4)"
    echo "screen -t /dev/$DEVICE  bash -c 'bash $PWD/hddtest_smart_worker_v2.0.2.sh /dev/$DEVICE \"$(echo $SERIAL)\" $MODE \"-d megaraid,$LSI_RAID_DEVICE\" ; sleep 2'" >> $screenrc
  fi



done
sleep 10

STARTTIME="$(date +%d.%m.\ %H:%M)"
echo_grey "START: $STARTTIME"

sleep 1

# start erasing in a screen session: start screen and stay attached
#
sleep 1
screen -mS $(basename $0) -c $screenrc

# end
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

#
# display test result RAIL/OK

for DISK in $DISKS; do
  #
  # get disk type
  TYPE=$(echo $DISK | cut -d: -f1)

  #
  # get device
  DEVICE=$(echo $DISK | cut -d: -f2)

  #
  # get serial
  SERIAL=$(echo $DISK | cut -d: -f3)

  DETAIL=''
  STATUS="$(grep -h "$SERIAL" /root/hwcheck-logs/*)"
  HDD_LOG=$(cat /root/hwcheck-logs/hddtest-$SERIAL.log | tr -s " ")
  [ -n "$(echo "$HDD_LOG" | egrep '([0-9]{3,} ){3,}' | awk '{print $2" "$9" "$10}')" ] && DETAIL="$DETAIL$(echo "$HDD_LOG" | egrep '([0-9]{3,} ){3,}' | awk '{print $2" "$9" "$10" "}' )"
  [ -n "$(echo "$HDD_LOG" | egrep '^SELFTEST-ERROR')" ] && DETAIL="${DETAIL}SELFTEST-ERROR"
  [ -n "$(echo "$HDD_LOG" | egrep '^Error')" ] && DETAIL="$DETAIL$(echo "$HDD_LOG" | egrep 'Error' | sed 's/Error://g') "

  [ "$(echo $STATUS | grep OK)" ] && echo_green "$STATUS $DETAIL"
  [ "$(echo $STATUS | grep FAIL)" ] && echo_red "$STATUS $DETAIL"
  echo ""
done

rm $LOGDIR/hddtest*
