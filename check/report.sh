#!/bin/bash

. /root/.oldroot/nfs/check/config
. /root/.oldroot/nfs/check/report.function

LOGFILE="hardware.report"

send_reset() {
  send2 reset "$3" &> /dev/null
}

send_update() {
  send2 update &> /dev/null
}

send_info() {
  shift
  send2 info "$@" &> /dev/null
}

send_attr() {
  shift
  send2 attr "$@" &> /dev/null
}

send_cattr() {
  local computer_item="$2"
  local item_value="$3"
  local data_file="$4"
  [[ -f "$data_file" ]] && item_value="$(cat "$data_file")"
  send2 cattr "$computer_item" "$item_value" &> /dev/null
}

function log(){
  local return_value="$1"
  local func_name="$2"
  local command="$3"

  DATE="$(date -Iseconds)"
  printf "[%s] ---- %-10s ---- %-20s ---- %s\n" "$DATE" "$return_value" "$func_name" "$command" >> $LOGDIR/$LOGFILE
}

MAC="$(get_mac)"
IP="$(get_ip)"

URL="https://$SERVER_DATACENTER"

# moved from botom to the top of the script # TimF
#
#
# reset computer details
send_reset "$MAC" "$IP" '1'

#
# update computer

send_update "$MAC" "$IP"

#
# mainboard info
SERIAL=$(dmidecode -t system | sed -n 's/.*UUID:\ \(.*\)/\1/p')
send_info "$MAC" "$SERIAL" "mainboard"

eval "declare -A data=($(echo -n $(dmidecode -t baseboard | grep -E 'Serial|Manu|Version|Product' | sed -n 's/\t\(.*\):\ \(.*\)$/["\1"]="\2"/p;')))"
for key in "${!data[@]}"; do
  #curl -k -X PUT "https://78.47.119.246/api/$MAC/hardware/$serial/attribute/$key/${data[$key]}" -d "";
  send_attr "$MAC" "$SERIAL" "$(echo -n $key | sed 's/\ /%20/g')" "${data[$key]}"
done

dmidecode -t baseboard | sed -n 's/.*Product\ .*:\ \(.*\)/\1/p' > /tmp/mainboard
send_cattr "$MAC" "Mainboard" "" "/tmp/mainboard"

#
# report CPU info to mainboard serial
eval "declare -A data=($(echo -n $(dmidecode -t processor | grep -E 'Version|Upgrade' | sed -n 's/\t\(.*\):\ \(.*\)$/["\1"]="\2"/p;')))"
for key in "${!data[@]}"; do
  send_attr "$MAC" "$SERIAL" "CPU_$key" "${data[$key]}"
done

dmidecode -t processor | sed -n 's/.*Version:\ \(.*\)/\1/p' | grep -v 'Not Specified' > /tmp/cpuversion
send_cattr "$MAC" "CPU" "" "/tmp/cpuversion"

#
# get BIOS Version
BIOS="$(dmidecode -t bios | grep -E 'Version' | sed -n 's/.*:\ \(.*\)/\1/p')"
send_attr "$MAC" "$SERIAL" "BIOS_Version" "$BIOS"

echo "$BIOS" > /tmp/bios
send_cattr "$MAC" "BIOS" "" "/tmp/bios"

#
#memory report
additional_identifier=0
info_sent=''
while read line; do
  if [[ $line =~ ^Serial.* ]]; then
    SERIAL='';
    SERIAL=$(echo $line | sed -n 's/.*:\ \(.*\)/\1/p');
    if [[ "$SERIAL" != "00000000" && "$SERIAL" != "Unknown" ]]; then
      if [[ "$SERIAL" != 'Not Specified' ]] &&
        [[ "$SPEED" != 'Unknown' ]] &&
        [[ "$SIZE" != 'No Module Installed' ]] &&
        [[ "$MANUFACTURER" != 'Not Specified' ]]; then
        additional_identifier=$((additional_identifier+1))

        #
        # memory info
        send_info "$MAC" "$SERIAL" "memory" $additional_identifier
        info_sent="$SERIAL"

        #
        # memory attr
        send_attr "$MAC" "$SERIAL" "Speed" "$SPEED" $additional_identifier
        send_attr "$MAC" "$SERIAL" "Size" "$SIZE" $additional_identifier
        send_attr "$MAC" "$SERIAL" "Locator" "$LOCATOR" $additional_identifier
        send_attr "$MAC" "$SERIAL" "Bank_Locator" "$BANK_LOCATOR" $additional_identifier
        send_attr "$MAC" "$SERIAL" "Manufacturer" "$MANUFACTURER" $additional_identifier
      fi
    fi;
  fi;
  if [[ $line =~ ^Manufacturer.* ]]; then
    MANUFACTURER='';
    MANUFACTURER=$(echo $line | sed -n 's/.*:\ \(.*\)/\1/p');
  fi;
  if [[ $line =~ ^Speed.* ]]; then
    SPEED='';
    SPEED=$(echo $line | sed -n 's/.*:\ \(.*\)\ .*/\1/p');
  fi;
  if [[ $line =~ ^Size.* ]]; then
    SIZE='';
    SIZE=$(echo $line | sed -n 's/.*:\ \(.*\)\ .*/\1/p');
  fi;
  if [[ $line =~ ^Locator.* ]]; then
    LOCATOR='';
     LOCATOR=$(echo $line | sed -n 's/.*:\ \(.*\)$/\1/p')
  fi;
  if [[ $line =~ ^Bank\ Locator.* ]]; then
    BANK_LOCATOR='';
    BANK_LOCATOR=$(echo $line | sed -n 's/.*:\ \(.*\)$/\1/p');
  fi;
  if [[ $line =~ ^Part.* ]]; then
    PART='';
    PART=$(echo $line | sed -n 's/.*:\ \(.*\)/\1/p');
    if [ -n "$PART" ]; then
      if [[ "$PART" != 'Not Specified' ]]; then
        if [[ $info_sent == "$SERIAL" ]]; then
          send_attr "$MAC" "$SERIAL" "Part Number" "$PART" $additional_identifier
        fi
      fi
    fi
  fi;
done <<< "$(dmidecode -t memory | sed -n '/^Memory.*/,/Part/p')"
#
# amount memory

send_cattr "$MAC" "Memory" "$(cat /proc/meminfo | awk '/MemTotal/ {print $2/1024 }')"

#
# harddisk info

for hdd in $(get_all_hdd_types); do
  HDDTYPE=$(echo $hdd | cut -d : -f1)
  DEVICE=$(echo $hdd | cut -d : -f2)
  SERIAL=$(echo $hdd | cut -d : -f3)
  if [ "$HDDTYPE" == "lsi" ]; then
    DEVICE_ID=$(echo $hdd | cut -d : -f4)
    RAW_SIZE="$(smartctl -i -d megaraid,$DEVICE_ID /dev/$DEVICE | sed -n 's/User Capacity:\ \+\(.*\)\ bytes.*/\1/p' | sed 's/,//g')"
    SIZEGiB="$(( $RAW_SIZE / 1024 / 1024 / 1024 ))GiB"
    SIZEGB="$(( $RAW_SIZE / 1000 / 1000 / 1000 ))GB"
  else
    for size in $(get_hdd_size $DEVICE); do
      SIZEGiB=$(echo $size | cut -d: -f1)
      SIZEGB=$(echo $size | cut -d: -f2)
    done
  fi
  SECTOR_SIZE_LOG=$(hdparm -I /dev/$DEVICE | sed -n 's/.*Logical\ \+Sector\ size:\ *\([[:digit:]]\+\)\ .*/\1/p')
  SECTOR_SIZE_PHY=$(hdparm -I /dev/$DEVICE | sed -n 's/.*Physical.*:\ *\([[:digit:]]\+\)\ .*/\1/p')
  # echo "$SERIAL, $DEVICE, $SECTOR_SIZE_LOG, $SECTOR_SIZE_PHY"
  if [ "$SECTOR_SIZE_LOG" == 512 ]; then
    if [ "$SECTOR_SIZE_LOG" -eq "$SECTOR_SIZE_PHY" ]; then
      SECTOR_SIZE="${SECTOR_SIZE_LOG}n"
    else
      SECTOR_SIZE="${SECTOR_SIZE_LOG}e"
    fi
  else
    SECTOR_SIZE="$SECTOR_SIZE_LOG"
  fi
  if [ -z "$SECTOR_SIZE_LOG" -a -n "$SECTOR_SIZE_PHY" ]; then
    SECTOR_SIZE="${SECTOR_SIZE_PHY}n"
  fi

  # echo "sec: $SECTOR_SIZE"

  send_info "$MAC" "$SERIAL" "harddisk"
  send_attr "$MAC" "$SERIAL" "Device" "$DEVICE"
  send_attr "$MAC" "$SERIAL" "ATA_Device" "$(readlink /sys/block/$DEVICE | sed 's/\/host[0-9].*//g; s/^\.\.\/.*\///g;')"
  send_attr "$MAC" "$SERIAL" "Controller" "$HDDTYPE"
  send_attr "$MAC" "$SERIAL" "SIZEGiB" "$SIZEGiB"
  send_attr "$MAC" "$SERIAL" "SIZEGB" "$SIZEGB"
  send_attr "$MAC" "$SERIAL" "SECTOR_SIZE" "$SECTOR_SIZE"
done

#
# Mac and Nic details
while read -r line; do
  if [ -n "$(echo $line | grep -i ethernet)" ]; then
    pci=$(echo $line | sed -n 's/\(.*\)\ .*\ .*:\ .*$/\1/p')
    nic=$(echo $line | sed -n 's/.*:\ \(.*\)$/\1/p')
    mac="$(cat /sys/bus/pci/devices/0000\:$pci/net/eth*/address)"
    send_info "$MAC" "$mac" "Nic"
    send_attr "$MAC" "$mac" "Device" "$nic"
  fi
done < <(lspci)

#
# GPU
send_cattr "$MAC" "video_card" "$(get_gpu)"

processor_must_be_replaced && send_cattr "$MAC" 'processor_must_be_replaced' 'yes'
