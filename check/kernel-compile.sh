#!/bin/bash

#
# this script compiles a kernel to test the hardware of this machine
#
# david.mayr@hetzner.de - 2007.08.06


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send compile_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15


echo_yellow "\n=====  COMPILE KERNEL TEST  =====\n"


# stop test, if hdd tests are not activated in config
if [ ! "$HDD_TESTS_ACTIVE" = "true" ] ; then
  echo_red "HDD tests are not activated in the config file, this test would need a free HDD. ABORT."
  sleep 1
  exit 0
fi


ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send compile_result "WORKING" "Start $STARTTIME" "-"




# ask if disk(s) should really be deleted when paritions exist
#
ask_delete_partitions
echo_white "Create partitions in 5 seconds: "
sleep_dots 5



# get biggest disk
#
size=0
for disk in $(get_disks) ; do
  disksize="$(echo $disk | cut -d: -f2)"
  if [ $disksize -gt $size ] ; then
    size=$disksize
    biggestdisk=$(echo $disk | cut -d: -f1)
  fi
done
echo_grey "Biggest found disk is $biggestdisk with $(($size/1024/1024)) GB ..."



# partition biggest disk, create filesystem and mount it ...
#
echo_white "Partitioning $biggestdisk ... "
echo -e ",3072,L" | sfdisk -q $biggestdisk >/dev/null
[ $? -ne 0 ] && ERROR=1
if [ "$ERROR" == "1" ] ; then
  echo "kernel-compile:error:hdd:error to partition $biggestdisk" >> $ROBOT_LOGFILE
  catch_error "Fehler bei partitionieren von $biggestdisk" "ERROR"
fi
#
echo_white "Formatting $biggestdisk ... "
#mkfs.xfs -q -f $biggestdisk''2
mkfs.ext3 -q $biggestdisk''1
[ $? -ne 0 ] && ERROR=1
if [ "$ERROR" == "1" ] ; then
  echo "kernel-compile:error:hdd:error to format $biggestdisk" >> $ROBOT_LOGFILE
  catch_error "Fehler beim formatieren von $biggestdisk""1" "ERROR"
fi
#
mntdir="/usr/src"
mkdir -p $mntdir
echo_white "Mounting $biggestdisk""1 to $mntdir ... "
mount $biggestdisk''1 $mntdir
[ $? -ne 0 ] && ERROR=1
if [ "$ERROR" == "1" ] ; then
  echo "kernel-compile:error:hdd:error to mount $biggestdisk" >> $ROBOT_LOGFILE
  catch_error "Fehler beim mounten von $biggestdisk""1" "ERROR"
fi
chmod a+rwx $mntdir


OLDDIR=$(pwd)
cd `dirname $0`
DIR=$(pwd)
cd $OLDDIR

count=0
until [ $count -ge $COMPILECOUNT ] ; do

  let count=$count+1
  [ $COMPILECOUNT -gt 1 ] && echo_white "-> Run $count of $COMPILECOUNT ..."

  # decompress kernel
  #
  echo_white "   Decompress kernel ..."
  tar xjf $DIR/$KERNELFILE -C $mntdir  2>&1 | $LOG
  [ $? -ne 0 ] && ERROR=1
  if [ "$ERROR" == "1" ] ; then
    echo "kernel-compile:error:kernel:error to extract kernel" >> $ROBOT_LOGFILE
    catch_error "Entpacken des Kernels fehlgeschlagen" "ERROR"
  fi
  [ -L $mntdir/linux ] || ln -s $mntdir/linux-* $mntdir/linux

  # configure kernel
  #
  cd $mntdir/linux
  echo_white "   Configure kernel defaults ..."
  make allmodconfig >/dev/tty6 2>&1
  [ $? -ne 0 ] && ERROR=1
  if [ "$ERROR" == "1" ] ; then
    echo "kernel-compile:error:kernel:error to configure the kernel" >> $ROBOT_LOGFILE
    catch_error "Konfigurieren des Kernels (make allmodconfig) fehlgeschlagen" "ERROR"
  fi

  # compile kernel
  #
  CPUs="$(cat /proc/cpuinfo | grep processor | wc -l)"
  echo_white "   Start compiling kernel on $CPUs cpu(s) ...   (see tty6 for details)"
  CPUs=$(($CPUs*2))
  make -j$CPUs  2>&1 | $LOG  >/dev/tty6
  [ $? -ne 0 ] && ERROR=1
  if [ "$ERROR" == "1" ] ; then
    echo "kernel-compile:error:kernel:error at make the kernel" >> $ROBOT_LOGFILE
    catch_error "Compilieren des Kernels (make) fehlgeschlagen" "ERROR"
  fi
  cd - >/dev/null


  # clean up
  #
  echo_white "   Cleaning up files ..."
  rm -r $mntdir/linux*

done




# umount disk
#
echo_yellow "Unmounting $biggestdisk""1 ... "
umount $biggestdisk''1  2>&1 | $LOG
[ $? -ne 0 ] && ERROR=1
if [ "$ERROR" == "1" ] ; then
  echo "kernel-compile:error:hdd:error to unmount $biggestdisk" >> $ROBOT_LOGFILE
  catch_error "Fehler beim unmounten" "ERROR"
fi


# delete created test partitions
#
echo_white "\nDelete partitions in 5 seconds: "
sleep_dots 5
echo_yellow "Removing partitions from $biggestdisk ... "
echo "0,0,0" | sfdisk -q $biggestdisk >/dev/null




###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "compile_result"


