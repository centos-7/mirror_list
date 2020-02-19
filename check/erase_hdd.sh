#!/bin/bash

#
# this script removes all partitions of all harddisk(s)
# after confirmation
#
# david.mayr@hetzner.de - 2007.08.10


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config



# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send erasehdd_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15


echo_yellow "\n=====  ERASE HARDDISK  =====\n"


# stop test, if hdd tests are not activated in config
if [ ! "$HDD_TESTS_ACTIVE" = "true" ] ; then
  echo_red "HDD tests are not activated in the config file. ABORT."
  sleep 1
  exit 0
fi


ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send erasehdd_result "WAIT" "Start $STARTTIME" "-"



echo_red "===>  !WARNING!  <==="
echo_red "---------------------\n"
echo_red "Partitions on the harddisk(s):"
sfdisk -l ; echo
echo_red "All data on the disk(s) will be deleted!\n"
beep2
echo -n "Do you really want to continue? [N/y] "
until [ "$REALLY" ] ; do
  read -n1 -t5 REALLY
  if [ -e "/tmp/delete_$(get_mac)" ] ; then
    rm "/tmp/delete_$(get_mac)"
    echo_green "\nAnswered 'y' remotely ..."
    REALLY=y
  fi
done
echo
if [ "$REALLY" != "y" -a "$REALLY" != "Y" ] ; then
  echo_green "Aborted ..."
  sleep 1
  kill -2 $$
fi




send erasehdd_result "WORKING" "Start $STARTTIME" "-"


# if no disks found, return error
if [ -z "$(sfdisk -l)" ] ; then
  echo_red "No disks found!  Send status and abort test ..."
  send erasehdd_result "ERROR" "No disks found! [$STARTTIME]" "-"
  exit 1
fi

# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
cat <<EOF >$screenrc
## zombie on
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="

EOF

# erase all disks ...
#
echo_white "ERASE ALL DISKS in 5 seconds: "
sleep_dots 5
# add screen windows with erase commands
for disk in $(get_disks | cut -d: -f1) ; do
  echo
#  echo_white "ERASING $disk ... "
  echo "screen -t $disk bash -c 'ddrescue --force /dev/zero $disk'" >> $screenrc
  #catch_error "Fehler beim loeschen von $disk"
done

sleep 1
screen -mS $(basename $0) -c $screenrc
rm $screenrc


###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "erasehdd_result"


