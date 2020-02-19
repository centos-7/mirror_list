#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#
# david.mayr@hetzner.de - 2007.08.06


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
  if [ "$3" == "write" ] ; then
    DOWRITE=1
    MODE='write'
  else
    DOWRITE=0
    MODE='read'
  fi
else
  echo "Usage:  $0  </dev/your_disk> <serial(s)> [write]"
  exit 1
fi

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
  for serial in $serials ; do
   send hddtest-result "ABORT" "Aborted! [$STARTTIME - $(date +%d.%m.\ %H:%M)]" "$serial"
  done
  sleep 1
}
trap "abort ; kill -9 $$" 1 2 9 15

# send starting status
#
for serial in $serials ; do
  send hddtest-result "WORKING" "Starting in $HDDWIPE_SLEEP seconds ..." "$serial"
done

# wait some time before starting, to have a chance to cancel ...
#
echo_red "Badblocks $MODE-test will be STARTED in $HDDWIPE_SLEEP seconds on DISK $disk! \nPress CTRL-C to abort now! "
sleep_dots $HDDWIPE_SLEEP ; echo

# run badblocks on disk
#
STARTTIME="$(date +%d.%m.\ %H:%M)"
for serial in $serials ; do
  send hddtest-result "WORKING" "Start (Mode: $MODE, Device: $disk_wo_dev)" "$serial"
done
echo_white "Testing $disk ... "
time1=$(date +%s)
if [ $DOWRITE -eq 1 ] ; then
  BBOUTPUT="$(badblocks -t 0xaa -c 1024 -e 1 -s -w $disk)"
  #sleep 3
else
  BBOUTPUT="$(badblocks -c 1024 -e 1 -s $disk)"
  #sleep 3
fi

for serial in $serials ; do
  echo "$BBOUTPUT" > $LOGDIR/hddtest-$serial.log
  BBOUTPUTGREP1="$(echo "$BBOUTPUT" | grep -i "Too many bad blocks")"
  time2=$(date +%s)
  timediff=$[time2-time1]
  sizetocalc=$(echo $size | cut -d: -f2 | cut -dG -f1)
  sizeMB=$[$sizetocalc*1024]
  throughput=$[$sizeMB/$timediff]
  echo -e "\nDurchsatz $disk:  ca. $throughput MB/s  bzw. $[$throughput*1024] KB/s ($sizeMB MB in $timediff Sekunden)\n\n" >> $LOGDIR/hddtest-$serial.log
done

###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

for serial in $serials ; do
  if [ -z "$BBOUTPUTGREP1" ]; then
    send hddtest-result "OK" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serial"
  else
    echo "hdd_badblocks:error:hdd:too many badblocks at $disk_wo_dev" >> $ROBOT_LOGFILE
    send hddtest-result "ERROR" "Finished (Mode: $MODE, Device: $disk_wo_dev); [$STARTTIME - $ENDTIME]" "$serial"
  fi
done
