#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#
# david.mayr@hetzner.de - 2007.08.06


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send hdd_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15


echo_yellow "\n=====  HARDDISK TEST  =====\n"


# stop test, if hdd tests are not activated in config
if [ ! "$HDD_TESTS_ACTIVE" = "true" ] ; then
  echo_red "HDD tests are not activated in the config file. ABORT."
  sleep 1
  exit 0
fi


ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send hdd_result "WAIT" "Start $STARTTIME" "-"


# ask if disk(s) should really be deleted when paritions exist
#
ask_delete_partitions


send hdd_result "WORKING" "Start $STARTTIME" "-"


# if no disks found, return error
if [ -z "$(sfdisk -l)" ] ; then
  echo_red "No disks found!  Send status and abort test ..."
  send hdd_result "ERROR" "No disks found! [$STARTTIME]" "-"
  exit 1
fi


# partition disks, create filesystems and mount them ...
#
echo_white "Create test partitions in 5 seconds: "
sleep_dots 5
for disk in $(get_disks | cut -d: -f1) ; do
  echo
  echo_white "Partitioning $disk ... "
  echo -e ",1024,S\n,,L" | sfdisk -q $disk >/dev/null
  catch_error "Fehler bei partitionieren von $disk"
  echo_white "Formatting $disk ... "
  #mkfs.xfs -q -f $disk''2  2>&1 | $LOG
  mkfs.ext3 -q $disk''2  2>&1 | $LOG
  catch_error "Fehler beim formatieren von $disk"
  mntdir="/mnt/$(basename $disk)2"
  mkdir -p $mntdir
  echo_white "Mounting $disk to $mntdir ... "
  mount $disk''2 $mntdir  2>&1 | $LOG
  catch_error "Fehler beim mounten von $disk"
  chmod a+rwx $mntdir
done



# run bonnie on all disks
#
echo
for disk in $(get_disks | cut -d: -f1) ; do
  echo_white "Testing $disk ... "
  mntdir="/mnt/$(basename $disk)2"
  bonnie++ -d $mntdir -s $BONNIESIZE -u nobody  2>&1 | $LOG
  catch_error "Bonnie beendete mit Fehler"
  echo
done



# umount all disks
#
for disk in $(get_disks | cut -d: -f1) ; do
  echo_yellow "Unmounting $disk ... "
  umount $disk''2  2>&1 | $LOG
  catch_error "Fehler beim unmounten"
done



# delete created test partitions
#
echo_white "\nDelete test partitions in 5 seconds: "
sleep_dots 5
for disk in $(get_disks | cut -d: -f1) ; do
  echo_yellow "Removing test partitions from $disk ... "
  echo "0,0,0" | sfdisk -q $disk >/dev/null
done




###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "hdd_result"


