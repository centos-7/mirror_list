#!/bin/bash
source /root/.oldroot/nfs/check/hwb/nvme.function
source /root/.oldroot/nfs/check/report.function

hwcdir="/root/.oldroot/nfs/check"

mode=long
readtest=full

dev=$1
pciaddr=$2
sn=$(nvme id-ctrl /dev/${dev}|awk -F 'sn:' 'match($0, "sn"){gsub (" ", "", $0); print $1 $2}')

# Declare file where test ids are stored
declare -r file="$(grep -ril "$dev" /run/hdd_test_status/)"

led $pciaddr slow

#0. firmware update
echo "Checking for firmware updates.."
/root/.oldroot/nfs/firmware_update/crucial/update_crucial_micron.sh /dev/$dev
/root/.oldroot/nfs/firmware_update/intel_ssd/update_intel_ssd.sh /dev/$dev
/root/.oldroot/nfs/firmware_update/samsung/update_samsung.sh /dev/$dev
/root/.oldroot/nfs/firmware_update/toshiba/update_toshiba.sh /dev/$dev
/root/.oldroot/nfs/firmware_update/westerndigital/update_westerndigital.sh /dev/$dev
echo "Firmware update check finished."

#1. wipe
echo "Running Secure-Erase.."
timeout --foreground 24h $hwcdir/hddwipe_ssd_eraser.sh $dev "$sn"
return=$?
echo "Secure-Erase finished."

if [ $return -eq 124 ]; then
  echo "the command timed out"
  send2 update_status "$(tail -n1 $file)" "ABORTED"
  last_status="test_timeout"
else
  last_status="$(send2 finished $(tail -n1 $file))"
fi

#2. hddtest1
if [ "$last_status" == "test_ok" ]; then
  echo "Smart-Test 1.."
  $hwcdir/hddtest_smart_worker_nvme.sh /dev/$dev "$sn" "$mode" "" "$readtest" "1"
  echo "Smart-Test 1 finished."
fi

[ ! "$last_status" == "test_timeout" ] && last_status="$(send2 finished $(tail -n1 $file))"
if [ "$last_status" == "test_ok" -o "$last_status" == "test_warning" ]; then
  echo "Stresstest.."
  $hwcdir/stressapptest-dev.sh -d 180 --destructive --ignore-error --single /dev/$dev
  echo "Stresstest finished."
fi

[ ! "$last_status" == "test_timeout" ] && last_status="$(send2 finished $(tail -n1 $file))"
if [ "$last_status" == "test_ok" -o "$last_status" == "test_warning" ]; then
  echo "Smart-Test 2.."
  $hwcdir/hddtest_smart_worker_nvme.sh /dev/$dev "$sn" "$mode" "" "$readtest" "2"
  echo "Smart-Test 2 finished."
fi

if [ ! "$last_status" == "test_timeout" ]; then
  json="[$(tail -n +2 $file | paste -sd "," -)]"
  status="$(send2 id_based_summary "$json")"
fi

echo $status >> $file

if [ "$status" == "test_ok" ]; then
  mv $file /run/hdd_test_status/finished/
  echo_green "Test finished OK"
  led $pciaddr on
  sleep 1
  while [ -f /run/hdd_test_status/finished/$pciaddr ]; do
    sleep 1
  done
else
  mv $file /run/hdd_test_status/failed/
  led $pciaddr fast
  echo_red "Test finished FAILED"
  while [ -f /run/hdd_test_status/failed/$pciaddr ]; do
   sleep 1
  done
fi
