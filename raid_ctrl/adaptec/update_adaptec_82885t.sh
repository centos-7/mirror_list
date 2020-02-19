#!/bin/bash

BASEDIR="/root/.oldroot/nfs/raid_ctrl/adaptec"
EXTRA=""
VERSION=""
CURRENT="B059"

if [ "$1" ]; then
  if [ "$1" = 'noprompt' ]; then
    EXTRA="noprompt"
  else
    echo "unknown option"
    exit 1
  fi
fi

if lspci -n | grep -q 9005:028d || lspci -n | grep -q 9005:028f; then
  VERSION="$(arcconf getconfig 1 pd | grep AEC-82885T -A 1 -B 8|awk -F': ' '/Firmware/{print $2}')"
  if [[ "$VERSION" =~ ^B0 ]]; then
  echo "Adaptec SAS Expander 82885T found"
  echo -e "\e[31;5mThe Server will automatically go to standby for 20 seconds and reboot after the firmware update! \e[0m"
    if [ "$VERSION" = "$CURRENT" ]; then
      echo "already up2date, skipping"
      exit 0
    else
      LOCATION=$(arcconf getconfig 1 pd | grep AEC-82885T -A 1 -B 9|grep "Reported Location"|sed -ne 's/.*:\(.*\),.*/\1/p')
      CHANNEL="${LOCATION} $(arcconf getconfig 1 pd | grep AEC-82885T -A 1 -B 9|awk -F': ' '/Reported Channel,Device\(T\:L\)/{print substr($2,1,3)}'|sed 's/\,/ /g')"
      arcconf EXPANDERUPGRADE 1 ENCLOSURE $CHANNEL EXPANDER $BASEDIR/82885T/firmware_${CURRENT,,}.bin 7 $EXTRA
      rtcwake -m mem -s 20
      reboot
    fi
  fi
else
  echo "no Adaptec controller found"
fi
