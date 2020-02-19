#!/bin/bash
# stops and remove mdadm raid
# 29.10.2018 07:58 jukka.lehto

RAIDS=($(cat /proc/mdstat | grep md. | cut -f1 -d\ ))
i=0
while [ "${RAIDS[$i]}" != "" ]; do
  MD=${RAIDS[$i]}
  i=$((++i))
  DEVS=($(mdadm --detail /dev/$MD|grep -v ":"|grep /dev|cut -f3- -d/))
  mdadm --stop /dev/$MD
  o=0
  while [ "${DEVS[$o]}" != "" ]; do
    DEV=${DEVS[$o]}
    mdadm --zero-superblock /dev/$DEV
    o=$((++o))
  done
  mdadm --remove /dev/$MD
  echo
done
