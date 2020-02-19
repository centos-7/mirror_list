#!/bin/bash

#
# this script benchmarks the harddisk(s) of this machine
#
# Sebastian.Nickel@hetzner.de - 2009.03.09


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

[ "$BENCHMARK_ALLOWED" = "no" ] && exit 0

# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send bm-hdd-result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15


echo_yellow "\n=====  HARDDISK BENCHMARK  =====\n"


# stop test, if hdd tests are not activated in config
if [ ! "$HDD_TESTS_ACTIVE" = "true" ] ; then
  echo_red "HDD tests are not activated in the config file. ABORT."
  sleep 1
  exit 0
fi


ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send bm-hdd-result "WAIT" "Start $STARTTIME" "-"

#stop possible raid
for i in $(egrep ^md[0-9]+ /proc/mdstat | cut -d' ' -f1); do
  mdadm -S /dev/$i
done

# ask if disk(s) should really be deleted when paritions exist
#
ask_delete_partitions


send bm-hdd-result "WORKING" "Start $STARTTIME" "-"


# if no disks found, return error
if [ -z "$(sfdisk -l)" ] ; then
  echo_red "No disks found!  Send status and abort test ..."
  send bm-hdd-result "ERROR" "No disks found! [$STARTTIME]" "-"
  exit 1
fi


# partition disks, create filesystems and mount them ...
#
echo_white "Create test partitions in 5 seconds: "
sleep_dots 5
for disk in $(get_disks | cut -d: -f1) ; do
  echo_white "Partitioning $disk ... "
  echo -e ",1024,S\n,,L" | sfdisk -q $disk 2>&1 >/dev/null
  echo_white "Formatting $disk ... "
  #mkfs.xfs -q -f $disk''2  2>&1 | $LOG
  mkfs.ext3 -q $disk''2  2>&1 | $LOG
  mntdir="/mnt/$(basename $disk)2"
  mkdir -p $mntdir
  echo_white "Mounting $disk to $mntdir ... "
  mount $disk''2 $mntdir  2>&1 | $LOG
  catch_error "Fehler beim mounten von $disk"
  chmod a+rwx $mntdir
done



# run bonnie++ on all disks
#
BM_FILE_SIZE="30G"
TEST_COUNT=1

rm -f $LOGDIR/bonnie.tmp
touch $LOGDIR/bonnie.tmp

for disk in $(get_disks | cut -d: -f1) ; do
  echo_white "Testing $disk ... "
  mntdir="/mnt/$(basename $disk)2"
  bonnie++ -d $mntdir -x $TEST_COUNT -s $BM_FILE_SIZE -u nobody  2>&1 | tee -a $LOGDIR/bonnie.tmp
  catch_error "Bonnie beendete mit Fehler"
done

  # reformat to almost human readable
  cat $LOGDIR/bonnie.tmp | bon_csv2txt > $LOGDIR/$LOGFILE
  rm -f $LOGDIR/bonnie.tmp
  sed -ie '/Sequential Create/,$ d' $LOGDIR/$LOGFILE


# umount all disks
#
for disk in $(get_disks | cut -d: -f1) ; do
  echo_yellow "Unmounting $disk ... "
  umount $disk''2  2>&1 | $LOG
  catch_error "Fehler beim unmounten"
  echo $ERRORMSG
done

#do some dd measurement
for disk in $(get_disks | cut -d: -f1) ; do
  echo_white "\n\nWriting 4GB of data with 'dd' to disk $disk ..."
  echo -e "\nSome tests with dd on $disk:" >> $LOGDIR/$LOGFILE
  dd count=4096 bs=1M if=/dev/zero of=$disk 2>&1 | $LOG
done

###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "bm-hdd-result"


