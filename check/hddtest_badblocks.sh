#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

# send abort status, if signal catched
# 
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  for hdd in $(get_disks | cut -d: -f1 | cut -d/ -f3) ; do
    serials=$(get_all_hdd_serials | grep $hdd | cut -d: -f2)
    for serial in $serials ; do
      send hddtest-result "ABORT" "Aborted! [$STARTTIME - $(date +%Y.%m.%d\ %H:%M:%S)]" "$serial"
    done
  done
}
trap "abort ; kill -9 $$" 1 2 9 15

echo_yellow "\n=====  HARDDISK TEST (badblocks)  =====\n"


# if no disks found, return error
if [ -z "$(get_hdd)" ] ; then
  echo_red "No disks found!  Abort ..."
  exit 1
fi

# mode: write or read
if [ "$1" == "write" ] ; then
  DOWRITE=1
else
  DOWRITE=0
fi

ATTENDED=1
ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"

if [ "$2" == "unattended" ] ; then
  ATTENDED=0
fi

if [ $DOWRITE -eq 1 ] ; then
  if [ $ATTENDED -eq 1 ] ; then
    echo_red "Dieser Test löscht unwiederruflich die Festplatten. Wollen Sie fortfahren? (j/N)\n"
    read -n1 NACHFRAGE
  else
    NACHFRAGE="j"
  fi

  if [ "$NACHFRAGE" != "j" ] && [ "$NACHFRAGE" != "J" ] ; then
    abort
    exit 1
  fi
fi

STARTTIME="$(date +%d.%m.\ %H:%M)"
echo_grey "START: $STARTTIME"


# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
cat <<EOF >$screenrc
## zombie on
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="

EOF


# add screen windows with badblocks commands
for diskdata in $(get_disks) ; do
  disk=$(echo $diskdata | cut -d: -f1)
  size=$(echo $diskdata | cut -d: -f2)
  disk_wo_dev=$(echo $disk | cut -d/ -f3)
  serials=$(get_all_hdd_serials | grep $disk_wo_dev | cut -d: -f2)

  if [ $DOWRITE -eq 1 ] ; then
    echo "screen -t $disk bash -c 'bash $PWD/hddtest_badblocks_worker.sh $disk \"$(echo $serials)\" write ; sleep 2'" >> $screenrc
  else
    echo "screen -t $disk bash -c 'bash $PWD/hddtest_badblocks_worker.sh $disk \"$(echo $serials)\" ; sleep 2'" >> $screenrc
  fi
done

# start erasing in a screen session: start screen and stay attached
#
sleep 1
screen -mS $(basename $0) -c $screenrc
rm $screenrc
rm $LOGDIR/hddtest*

# end
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"
