#!/bin/bash
. /root/.oldroot/nfs/check/hwb/lpt_led_functions

PWD="$(dirname $0)"
. $PWD/../config
. $PWD/../report.function
. $PWD/../wipe.function

HDD="/dev/$1"
IS_SAS="$2"
SERIAL=$(get_hdd_serial $HDD | xargs)
declare -r FILE="$(grep -ril "$1" /run/hdd_test_status/)"

#0. firmware update
echo "Checking for firmware updates.."
/root/.oldroot/nfs/firmware_update/crucial/update_crucial_micron.sh $HDD
/root/.oldroot/nfs/firmware_update/intel_ssd/update_intel_ssd.sh $HDD
/root/.oldroot/nfs/firmware_update/seagate/update_seagate.sh $HDD
/root/.oldroot/nfs/firmware_update/westerndigital/update_westerndigital.sh $HDD
echo "Firmware update check finished."

echo "Wiping $HDD.."
SECURE_ERASE="true"
[ "$IS_SAS" == "true" ] && SECURE_ERASE="false"
$(is_frozen $HDD) && SECURE_ERASE="false"
if [ "$SECURE_ERASE" == "false" ]; then
  timeout --foreground 24h $PWD/../hddwipe_wrapper_worker.sh $HDD $SERIAL
  return=$?
else
  echo "Running Secure-Erase.."
  timeout --foreground 24h $PWD/../wipe_eraser.sh $HDD sec | tee $LOGDIR/hddwipe-$SERIAL.log
  return=$?
  echo "Secure-Erase finished."
fi
if [ $return -eq 124 ]; then
  echo "the command timed out"
  send2 update_status "$(tail -n1 $FILE)" "ABORTED"
  LAST_STATUS="test_timeout"
else
  LAST_STATUS="$(send2 finished $(tail -n1 $FILE))"
fi

if [ "$LAST_STATUS" == "test_ok" ]; then
  echo "Smart-Test 1.."
  if [ "$(smartctl -i $HDD | grep -q SAS)" ]; then
    $PWD/../hddtest_smart_worker_sas_v2.0.0.sh $HDD $SERIAL "short" " " " " standard 1 true
  else
    $PWD/../hddtest_smart_worker_v2.0.3.sh $HDD $SERIAL "short" " " standard 1 true
  fi
fi

[ ! "$LAST_STATUS" == "test_timeout" ] && LAST_STATUS="$(send2 finished $(tail -n1 $FILE))"
if [ "$LAST_STATUS" == "test_ok" -o "$LAST_STATUS" == "test_warning" ]; then
  echo "Stresstest.."
  $PWD/../stressapptest-dev.sh -d 240 --destructive --ignore-error --single $HDD
fi

[ ! "$LAST_STATUS" == "test_timeout" ] && LAST_STATUS="$(send2 finished $(tail -n1 $FILE))"
if [ "$LAST_STATUS" == "test_ok" -o "$LAST_STATUS" == "test_warning" ]; then
  echo "Smart-Test 2.."
  if [ "$(smartctl -i $HDD | grep -q SAS)" ]; then
    $PWD/../hddtest_smart_worker_sas_v2.0.0.sh $HDD $SERIAL "long" "" "" standard 2 true
  else
    $PWD/../hddtest_smart_worker_v2.0.3.sh $HDD $SERIAL "long" " " standard 2 true
  fi

fi


LEDPORT=${FILE##*/}

if [ ! "$LAST_STATUS" == "test_timeout" ]; then
  json="[$(tail -n +2 $FILE | paste -sd "," -)]"
  STATUS="$(send2 id_based_summary "$json")"
fi

echo $STATUS >> $FILE

if [ "$STATUS" == "test_ok" ]; then
  mv $FILE /run/hdd_test_status/finished/
  echo_green "Test finished OK"
  sleep 1
  led_on $LEDPORT
  while [ -f /run/hdd_test_status/finished/$LEDPORT ]; do
    sleep 1
  done
else
  mv $FILE /run/hdd_test_status/failed/
  echo_red "Test finished FAILED"
  while [ -f /run/hdd_test_status/failed/$LEDPORT ]; do
   sleep 1
  done
fi
