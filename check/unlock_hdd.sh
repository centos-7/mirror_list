#!/bin/bash

PWD="$(dirname $0)"
. $PWD/config

for dev in $(get_disks | cut -d: -f1); do 
  if ! [ "$(hdparm -I $dev | sed -n 's/\t\(.*\)\tenabled/\1/p')" ]; then 
    echo $dev 
    echo  "unlock hdd" 
    hdparm --user-master u --security-unlock abcd $dev
    echo "disable security"
    hdparm --user-master u --security-disable abcd $dev
  fi
done

