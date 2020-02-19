#!/bin/bash

source /root/.oldroot/nfs/check/hwb/nvme.function

echo $@ |tee -a /var/log/udev_nvme.log

dev=$2
sys=/sys${3}
pciaddr=$(lspci -s $(echo "$sys" | cut -d'/' -f 6 | sed 's/^0000\://g') -vv | grep -P -o 'Physical Slot: \K\d+')

echo "dev $dev / sys $sys / pciaddr $pciaddr" >> /var/log/udev_$dev.log

if [ $1 == "add" ]; then
  file=$(find /run/hdd_test_status/ -name $pciaddr)
  if [ -n "$file" ]; then
    rm $file
    sleep 1
  fi
  led $pciaddr off
  echo $dev > /run/hdd_test_status/running/$pciaddr

  screen -S hwb_wipe_check -X screen -t $dev bash -c "/root/.oldroot/nfs/check/hwb/run_nvme_hwc.sh $dev $pciaddr"
elif [ $1 == "remove" ]; then
    file=$(grep -ril $2 /run/hdd_test_status/failed/)
  if [ -n "$file" ]; then
    rm $file
    pkill -9 -f "run_nvme_hwc.sh $2"
    sleep 2
    led ${file##*/} off
    echo "Device $2 Action $1, LED ${file##*/}: REMOVED AFTER FAILED" >> /tmp/mount.log
  fi

  file=$(grep -ril $2 /run/hdd_test_status/running/)
  if [ -n "$file" ]; then
    led ${file##*/} off
    mv $file /run/hdd_test_status/failed/
    pkill -9 -f "run_nvme_hwc.sh $2"
    echo "Device $2 Action $1, LED ${file##*/}: REMOVED WHILE RUNNING" >> /tmp/mount.log
  fi

  file=$(grep -ril $2 /run/hdd_test_status/finished/)
  if [ -n "$file" ]; then
    rm $file
    sleep 2
    led ${file##*/} off
    echo "Device $2 Action $1, LED ${file##*/}: REMOVED AFTER FINISH" >> /tmp/mount.log
  fi
else
  exit 1
fi
