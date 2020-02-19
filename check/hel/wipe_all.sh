#!/bin/bash
#
# script to wipe all disks
# jukka.lehto@hetzner.com - 2018.9.25 - modified from /root/.oldroot/nfs/check/menu.sh for wiping disks without confirmation
#

# setting new PATH
PATH=$PATH:/usr/local/bin
export PATH


# read in configuration file
#
MYPWD=$(dirname $(realpath -s $0))
PWD=/root/.oldroot/nfs/check

# ask for confirmation before wipe
#
printf "This script will wipe all attached disks (NVMe, SATA and USB)\n"
printf "Type 'yes' to confirm data loss: "
read wipeconfirmation
[ "$wipeconfirmation" != "yes" ] && exit

cd $PWD
. $PWD/config
. $PWD/report.function
. $PWD/hddwipe_ssd.function

#
# include menu.functions.conf
. $MYPWD/wipe_all.function

main "$@"
