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



echo_yellow "\n=====  REMOVE PARTITIONS  =====\n"


# ask if disk should really be deleted when paritions exist
#
if $(partitions_exist) ; then
  echo_red "===>  !WARNING!  <==="
  echo_red "---------------------\n"
  echo_red "There exist the following partitions on the harddisk(s):"
  echo_white "\n$(get_disks)\n"
  echo_red "All data on the disk(s) will be deleted!\n"
  echo_yellow "Do you really want to continue? [N/y] "
  read -n1 REALLY ; echo
  if [ "$REALLY" != "y" -a "$REALLY" != "Y" ] ; then
    echo_green "Aborted ..."
    sleep 1
    kill -2 $$
  else
    # delete partitions
    echo_white "\nDelete test partitions in 5 seconds: "
    sleep_dots 5
    for disk in $(get_disks | cut -d: -f1) ; do
      echo_yellow "Removing test partitions from $disk ... "
      sgdisk -Z $disk >/dev/null
    done
  fi
else
  echo_white "No partitions found on the disk(s)."
fi

