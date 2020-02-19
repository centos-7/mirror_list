#!/bin/bash

#
# this script DELETES the harddisk(s) of this machine remotely
#
# david.mayr@hetzner.de - 2010.01.14


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# stop test, if hddwipe is not allowed
if ! hddwipe_allowed ; then
  echo_red "HDD wiping is not allowed - server seems not to be cancelled since at least 48 hours. ABORT."
  sleep 1
  exit 0
fi


export TERM=linux

tty=9

echo -e "\n\nWARNING:  starting HDD WIPE now."
echo -e "          For output see tty$tty.\n"

chvt $tty
clear > /dev/console
echo -e "REMOTE HDD WIPE\n\n" > /dev/console
$PWD/hddwipe.sh force >/dev/console </dev/console 2>&1 &

