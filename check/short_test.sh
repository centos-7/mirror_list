#!/bin/bash

#
# this script runs some short tests
#
# david.mayr@hetzner.de - 2007.08.23


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function

# send abort status
#
trap "echo_red '\n\nSending ABORT ...\n' ; umount /mnt/* >/dev/null 2>&1 ; send shorttest_result 'ABORT' '-' '-' ; send remove ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  SHORT TEST  =====\n"

STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"


board="$(dmidecode -s baseboard-product-name 2>/dev/null | tail -n1)"
if [ "$board" = "S1200RP" ] ; then
  echo_cyan "\n== FRU/SDR SETTINGS ==\n"
  echo_white "Found S1200RP board - configure FRU/SDR ... "
  /root/.oldroot/nfs/firmware_update/intel_s1200v3rp/frusdr.sh 01-03-0004
  if [ $? -eq 0 ] ; then
    echo_green "  Configuring done!"
  else
    echo_red "  Configuring failed!"
  fi

  # check if there is a rmm available
  echo_cyan "\n== Check for RMM4 module ==\n"
  /root/.oldroot/nfs/ipmi/intel/check_rmm.sh > /dev/null
  if [ $? -eq 0 ] ; then
    echo_green "Module found!"
  else
    echo_yellow "Module not found!"
  fi
elif [ -n "$(echo "$board" | grep -i x9sri)" ] ; then
  echo_cyan "\n== IPMI/SDR SETTINGS ==\n"
  echo_white "Found X9SRI board - configure IPMI/SDR ... "
  /root/.oldroot/nfs/ipmi/smi/reset.sh 1>/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    echo_green "  Configuring done!"
  else
    echo_red "  Configuring failed!"
  fi
elif [ -n "$(echo "$board" | grep -i h8sgl)" ] ; then
  echo_cyan "\n== IPMI/SDR SETTINGS ==\n"
  echo_white "Found H8SGL board - check for ipmi firmware update ... "

  # check for current IPMI firmware version
  ipmi_ver=$(/root/.oldroot/nfs/ipmi/smi/ipmicfg -ver | sed 's/.*: \(.*\)/\1/g' | tr -d '.')
  if [ ${ipmi_ver} -lt 319 ] ; then
    echo_white "IPMI firmware update needed - do firmware update ... "
    /root/.oldroot/nfs/ipmi/smi/check_update_h8sgl.sh true 1>/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      echo_green "  Update done!"
    else
      echo_red "  Update failed!"
    fi
  else
    echo_green "  No Update needed!"
  fi

  echo_white "Configure IPMI/SDR ... "
  /root/.oldroot/nfs/ipmi/smi/reset.sh 1>/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    echo_green "  Configuring done!"
  else
    echo_red "  Configuring failed!"
  fi
elif [ -n "$(echo "$board" | grep -i Z10PA-U8)" ] ; then
  echo_cyan "\n== IPMI/SDR SETTINGS ==\n"
  echo_white "Found Z10PA-U8 board - check for ipmi firmware update ... "

  # check for current IPMI firmware version (if present)
  ipmi_ver="$(ipmitool mc info 2>/dev/null | grep 'Firmware Revision' | cut -d ':' -f 2 | sed -e 's/ //g;s/\.//g')"
  
  if [ -n "$ipmi_ver" ]; then
    if [ ${ipmi_ver} -lt 108 ] ; then
      echo_white "IPMI firmware update needed - do firmware update ... "
      /root/.oldroot/nfs/ipmi/asus/check_update_z10pa-u8.sh true 1>/dev/null 2>&1
      if [ $? -eq 0 ] ; then
        echo_green "  Update done!"
      else
        echo_red "  Update failed!"
      fi
    else
      echo_green "  No Update needed!"
    fi

  else
    echo_green "  No BMC Module found!"
  fi
fi

# update mx300 if needed
/root/.oldroot/nfs/firmware_update/crucial/update_mx300.sh

# update intel ssds
/root/.oldroot/nfs/firmware_update/intel_ssd/update_intel_ssd_530_535.sh

for hdd in $(get_hdd lines | cut -d: -f1); do
  model="$(get_hdd_model /dev/$hdd)"

  if [[ $model =~ ^Micron_5100_.*$ ]]; then
    fw="$(smartctl -i /dev/$hdd | sed -ne 's/Firmware.*:\ \(.*\)/\1/p')"
    echo "Micron Firmware: $hdd, $fw"

    if [ "$fw" != "D0MU027" ]; then
      echo "y" | /root/.oldroot/nfs/firmware_update/crucial/update_5100.sh /dev/$hdd
    fi
  fi
done

echo_cyan "\n== SHORT HDD TEST ==\n"

# if no disks found, return error
if [ -z "$(get_disks)" ] ; then
  echo_red "No disks found!  Send status and abort test ..."
  send2 reset
  send2 update
  TEST_ID="$(send2 shorttest "ERROR")"
  send2 finished "$TEST_ID" > /dev/null
  exit 1
# if only one disk and no raid controller found, wait for user interaction
elif [ "$(get_disks | wc -l)" -eq 1 ] && [ "$(get_raid | wc -l)" -eq 0 ] ; then
  echo_red "Only one disk found!"
  echo_red "Press 'c' to continue ..."
  PRESSED_KEY=''
  while [ "$PRESSED_KEY" != "c" ]; do    
    read -n1 PRESSED_KEY
  done
else
  echo_green "The following disks were found:"
  get_disks
  echo
fi

# check if we should do a CPU test
if [ -n "$1" ] && [ "$1" == "no_cpu" ]; then
  DO_CPU_TEST="no"
else
  DO_CPU_TEST="yes"
fi


# ask if disk(s) should really be deleted when paritions exist
#
ask_delete_partitions

# partition disks, create filesystems and mount them ...
#
echo -n "Create test partitions in 3 seconds: "
sleep_dots 3
for disk in $(get_disks | cut -d: -f1) ; do
  if [ $(lsb_release -c | sed -n 's/.*:\t\(.*\)$/\1/p') = "jessie" ]; then
    echo_white "Setting msdos label on $disk"
    parted -s $disk mklabel msdos 1>/dev/null
    echo_white "Partitioning $disk ... "
    (echo "1,5120,L" | sfdisk -quM $disk) 1>/dev/null 2>/dev/null
  else
    echo_white "Creating msdos label and 5G partition ..."
    echo -e  "label: dos\nstart= 2048, size= 10485760, type=83" | sfdisk -q $disk 2>&1 >/dev/null
  fi
  hdparm -z $disk 2>&1 >/dev/null
  sleep 5

  # 01.09.2018 11:05 jukka.lehto
  # nvme magic
  [ "${disk:5:4}" == "nvme" ] && disk=${disk}p
  echo_white "Formatting   $disk""1 ... "
  mkfs.xfs -f ${disk}1 1>/dev/null 2>/dev/null | $LOG
  mntdir="/mnt/$(basename $disk)1"
  mkdir -p $mntdir
  echo_white "Mounting     $disk""1 to $mntdir ... "
  mount $disk''1 $mntdir  2>&1 | $LOG
  chmod a+rwx $mntdir
done



# write some data on all disks
#
echo
for disk in $(get_disks | cut -d: -f1) ; do
  # 01.09.2018 11:05 jukka.lehto
  # nvme magic
  [ "${disk:5:4}" == "nvme" ] && disk=${disk}p
  echo_white "Writing Test data ($SHORTTESTSIZE MB) on $disk""1 ... (Please wait) ..."
  mntdir="/mnt/$(basename $disk)1"
  dd bs=1M count=$SHORTTESTSIZE if=/dev/zero of=$mntdir/testfile.zero >> $LOGDIR/$LOGFILE 2>&1
  echo
done



# umount all disks
#
for disk in $(get_disks | cut -d: -f1) ; do
  # 01.09.2018 11:05 jukka.lehto
  # nvme magic
  [ "${disk:5:4}" == "nvme" ] && disk=${disk}p
  echo_white "Unmounting ${disk}1 ... "
  umount $disk''1  2>&1 | $LOG
done



# delete created test partitions
#
echo -n "Delete test partitions in 3 seconds: "
sleep_dots 3
for disk in $(get_disks | cut -d: -f1) ; do
  echo_white "Removing test partitions from $disk ... "
  wipefs -a ${disk}1 > /dev/null
  sgdisk -Z $disk > /dev/null
done



# start temp logger
echo "true" > $LOGDIR/stresstest-temp.run
$PWD/stresstest_temp_log.sh &


# start stress for the cpu ...
#
if [ "$DO_CPU_TEST" == "yes" ]; then
  echo_cyan "\n== SHORT CPU TEST ==\n"
  count=1
  CPUTESTCOUNT=20
  CPUTESTTIME=3
  echo "Running $CPUTESTCOUNT tests, each takes $CPUTESTTIME seconds: "
  until [ $count -gt $CPUTESTCOUNT ] ; do
    stress -c 4 -t $CPUTESTTIME -q  2>&1 | $LOG
    echo -n '.'
    count=$(( $count + 1 ))
  done
  echo
  echo
fi

# stop temp logger
echo "false" > $LOGDIR/stresstest-temp.run
LOG_STILL_RUNNING="true"
while [ "$LOG_STILL_RUNNING" == "true" ]; do
  sleep 2
  PROCESSLIST="$(ps a)"
  if [ -z "$(echo "$PROCESSLIST" | grep stresstest_temp_log.sh)" ]; then
    LOG_STILL_RUNNING="false"
  fi
done

# check core temp log
TEMP_ERROR_LOG=''
for temp_log in $(cat $LOGDIR/stresstest-temp.log | sort -nr | uniq -c | sed -e 's/^ *//g;s/ /:/g' | head -n 10); do
  count=$(echo $temp_log | cut -d: -f1)
  temp=$(echo $temp_log | cut -d: -f2)
  maxtemp=85
  if [ "$board" = "S1200RP" ] ; then
    maxtemp=95
  fi

  if [ -n "$temp" ] && [ "$temp" -gt "$maxtemp" ] ; then
    TEMP_ERROR_LOG="$TEMP_ERROR_LOG$count $temp\n"
  fi
done
# save TEMP_ERROR_LOG
if [ -n "$TEMP_ERROR_LOG" ]; then
  TEMP_LOG="error"
  echo_red '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
  echo_red '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
  echo_red "\nCPU Temperatur ERROR\n$TEMP_ERROR_LOG" 
  echo_red '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
  echo_red '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
  touch $LOGDIR/cpu_temp_error
fi



# update raid controller
#
echo "Check for RAID-Controller updates ..."
$PWD/update_controller.sh

###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

send2 reset
send2 update


if [ -z $TEMP_LOG ]; then
  TEST_ID="$(send2 shorttest "OK")"
  send2 test_log_raw "$TEST_ID" "shorttest_log" "$LOGDIR/$LOGFILE"
  sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' $LOGDIR/short_test_full.log > $LOGDIR/short_test_full_no_color.log
  send2 test_log_raw "$TEST_ID" "__short_test_full_log" "$LOGDIR/short_test_full_no_color.log"
else
  TEST_ID="$(send2 shorttest "ERROR")"
  send2 test_log_raw "$TEST_ID" "shorttest_log" "$LOGDIR/$LOGFILE"
  sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' $LOGDIR/short_test_full.log > $LOGDIR/short_test_full_no_color.log
  send2 test_log_raw "$TEST_ID" "__short_test_full_log" "$LOGDIR/short_test_full_no_color.log"
fi

#
# finishing report
send2 finished "$TEST_ID" > /dev/null


# show mac adress
#
echo_yellow "MAC of current server: $(get_mac)"

beep4

