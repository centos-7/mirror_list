#!/bin/bash
echo "1 4 1 7" > /proc/sys/kernel/printk

. /root/.oldroot/nfs/check/hwb/lpt_led_functions

ATAPORT=$(echo $3 | sed -ne 's/.*\/ata\(.*\)\/h.*/\1/p')
SAS="false"

if [ $1 == "add" ]; then
  if [ ! -z "$ATAPORT" ]; then
    LEDPORT=$(($ATAPORT+1))
    echo "Device $2 Action $1, ATAPORT $ATAPORT, LED $LEDPORT" >> /mnt/mount.log
    echo $3 >> /tmp/mount.log
  else
    HOST=$(echo $3 | sed -ne 's/.*\/host\(.*\)\/p.*/\1/p')
    CONTROLLER=$(cat /sys/bus/scsi/devices/host$HOST/scsi_host/host$HOST/unique_id)
    ATAPORT=$( sas2ircu $CONTROLLER display | grep $(sas_port $2) -B1 | awk '/Slot/ {print $4}')
    echo "Host $HOST, Controller $CONTROLLER, ATAPORT $ATAPORT" >> /tmp/mount.log

    if [ -n "$ATAPORT" ]; then
      START=$(($CONTROLLER*4))
      LEDPORT=$(($ATAPORT+2+$START))
      SAS="true"
      echo "Device $2 Action $1, ATAPORT $ATAPORT, LED $LEDPORT" >> /tmp/mount.log
    else
      exit 0
    fi
  fi
fi

if [ $1 == "add" ]; then
  if [ -n "$LEDPORT" ]; then
    file=$(find /run/hdd_test_status/ -name $LEDPORT)
    if [ -n "$file" ]; then
      rm $file
      sleep 1
    fi
    
    led_off $LEDPORT
    
    echo $2 > /run/hdd_test_status/running/$LEDPORT

    hdparm --user-master u --security-unlock abcd $2
    hdparm --user-master u --security-disable abcd $2

    screen -S hwb_wipe_check -X screen -t $2 bash -c "/root/.oldroot/nfs/check/hwb/hdd_wipe_check.sh $2 $SAS"
  fi
else
  file=$(grep -ril $2 /run/hdd_test_status/failed/)
  if [ -n "$file" ]; then
    rm $file
    pkill -9 -f "hdd_wipe_check.sh $2"
    sleep 2
    led_off $LEDPORT
  fi

  file=$(grep -ril $2 /run/hdd_test_status/running/)
  if [ -n "$file" ]; then
    LEDPORT=${file##*/}
    mv $file /run/hdd_test_status/failed/
    pkill -9 -f "hdd_wipe_check.sh $2"
    echo "Device $2 Action $1, LED $LEDPORT: REMOVED WHILE RUNNING" >> /tmp/mount.log
  fi

  file=$(grep -ril $2 /run/hdd_test_status/finished/)
  if [ -n "$file" ]; then
    LEDPORT=${file##*/}
    rm $file
    sleep 2
    led_off $LEDPORT
    echo "Device $2 Action $1, LED $LEDPORT: REMOVED AFTER FINISH" >> /tmp/mount.log
  fi
fi
