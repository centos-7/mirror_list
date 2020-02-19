#!/bin/bash

#
# this script DELETES the harddisk(s) of this machine
#
# david.mayr@hetzner.de - 2008.10.28


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


echo_yellow "\n=====  HARDDISK WIPE - DELETE ALL HARDDISKS  =====\n"


# send abort status, if signal catched
#
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
}
trap "abort ; kill -9 $$" 1 2 9 15


## stop test, if hddwipe is not allowed
#if ! hddwipe_allowed ; then
#  echo_red "HDD wiping is not allowed - server seems not to be cancelled since at least 48 hours. ABORT."
#  sleep 1
#  exit 0
#fi


# if no disks found, return error
if [ -z "$(get_hdd)" ] ; then
  echo_red "No disks found!  Abort ..."
  exit 1
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
# add screen windows with erase commands
for hdd in $(get_hdd lines | cut -d: -f1) ; do
  serials=$(get_all_hdd_serials | grep $hdd | cut -d: -f2)
  [ -z "$serials" ] && serials="RAID"
  serials_combined=$(echo $serials | sed "s/ /_/g")
  [ -z "$serials_combined" ] && serials_combined="RAID"
  size=$(get_hdd_size /dev/$hdd)
  cache=$(get_hdd_cache /dev/$hdd)
  cacheMB="$[$cache/1024]M"
  model=$(get_hdd_model /dev/$hdd)
  model_text="$model (${cache}K)"
  mac="$(get_mac)"
  echo "screen -t $hdd bash -c 'bash $PWD/hddwipe_eraser.sh /dev/$hdd $(echo $serials) |  \
    tee $LOGDIR/hddwipe-$serials_combined.log ; sleep 2'" >> $screenrc
done


# ask if disk(s) should really be deleted - unless "force" param used
#
[ "$1" = "force" ] || ask_hddwipe


# start erasing in a screen session: start screen and stay attached
#
sleep 1
screen -mS $(basename $0) -c $screenrc
rm $screenrc
rm $LOGDIR/hddwipe-*.log

# end
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

