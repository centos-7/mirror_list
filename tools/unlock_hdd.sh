#!/bin/bash
source /root/.oldroot/nfs/check/report.function 2>/dev/null
source /root/.oldroot/nfs/check/wipe.function 2>/dev/null

if [ ! -b /dev/sda ]; then
  echo "no disks found"
  exit 0
fi

pass_seagate="abcd SeaChest p"
pass_wd="abcd WDCWDCWDCWDCWDCWDCWDCWDCWDCWDCW p"
pass_micron="abcd NULL p"
pass_default="abcd p"

for dev in /dev/sd?; do
  if [[ "$(hdparm -I $dev|grep "Security:" -A10|grep enabled|sed 's/\t//g')" == "enabled" && "$(hdparm -I $dev|grep "Security:" -A10|grep frozen|sed 's/\t//g')" == "frozen" ]]; then
    echo "SUSPEND SERVER TO UNLOCK DISKS"
    if [ ! "$(dmidecode -t baseboard | grep -i "product name" | grep "Z10PA-U8")" ]; then
      echo "$dev is frozen, using rtcwake"
      rtcwake -u -s 30 -m mem
      break
    else
      echo "not supported by mainboard"
      exit 1
    fi
  fi
done

for dev in /dev/sd?; do
  serial=$(hdparm -I $dev|grep "Serial Number:"|awk -F' ' '{print $3}')
  if [ "$(hdparm -I $dev|grep "Security:" -A10|grep enabled|sed 's/\t//g')" == "enabled" ]; then
    case $(get_manufacturer $serial) in
      Seagate)
        try_pass=$pass_seagate
        ;;
      HGST|"Western Digital")
        try_pass=$pass_wd
        ;;
      Micron|Crucial)
        try_pass=$pass_micron
        ;;
      *)
        try_pass=$pass_default
        ;;
    esac
    for pass in $try_pass; do
      if [ "$(hdparm -I $dev|grep "Security:" -A10|grep enabled|sed 's/\t//g')" == "enabled" ]; then
        if [ "$(hdparm -I $dev|grep "Security:" -A10|grep locked|sed 's/\t//g')" == "locked" ]; then
          echo  "trying to unlock $dev $serial with password \"$pass\""
          if [[ "$pass" == "WDCWDCWDCWDCWDCWDCWDCWDCWDCWDCW" ]]; then
            hdparm --user-master m --security-unlock "$pass" $dev 2>&1 > /dev/null
          else
            hdparm --user-master u --security-unlock "$pass" $dev 2>&1 > /dev/null
          fi
        fi
        if [[ "$(hdparm -I $dev|grep "Security:" -A10|grep locked|sed 's/\t//g')" == "notlocked" && "$(hdparm -I $dev|grep "Security:" -A10|grep enabled|sed 's/\t//g')" == "enabled" ]]; then
          echo "trying to disable security on $dev $serial with password \"$pass\""
          if [[ "$pass" == "WDCWDCWDCWDCWDCWDCWDCWDCWDCWDCW" ]]; then
            hdparm --user-master m --security-disable "$pass" $dev 2>&1 > /dev/null
          else
            hdparm --user-master u --security-disable "$pass" $dev 2>&1 > /dev/null
          fi
        fi
      fi
    done
  fi
  if [[ "$(hdparm -I $dev|grep "Security:" -A10|grep locked|sed 's/\t//g')" == "locked" || "$(hdparm -I $dev|grep "Security:" -A10|grep enabled|sed 's/\t//g')" == "enabled" ]]; then
    echo -e "\e[31mdisk $dev $serial still locked\e[0m"
  else
    echo -e "\e[32mdisk $dev $serial is unlocked\e[0m"
  fi
done
