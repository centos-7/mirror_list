#!/bin/bash

#
# this script checks 
#
# david.mayr@hetzner.de - 2011.02.24


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function

#
# logfile
LOGFILE="dmesg.server.log"

#
# report bmc_reset
TEST_ID="$(send2 dmesg "working" "working")"


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send dmesg_result 'ABORT' '-' '-' ; send2 update_status $TEST_ID "ABORTED" ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  DMESG TEST  =====\n"

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send dmesg_result "WORKING" "Start $STARTTIME" "-"

output=""


# check dmesg output
#
output="$(dmesg | egrep -C1 'ata.*exception Emask|status: { DRDY ERR }|device error|hard resetting link|Hardware Error|ata.*: SError|segfault|failed to read native max address|failed to IDENTIFY|I/O error|Result: hostbyte=DID_BAD_TARGET' 2>&1)"


# check HDD firmware versions
#
for disk in $(get_disks | cut -d: -f1) ; do
  smart_output=$(smartctl -i $disk)
  firmware=$(echo "$smart_output" | grep "^Firmware Version:" | cut -d: -f2 | sed "s/ //g")
  model=$(echo "$smart_output" | grep "^Device Model:" | cut -d: -f2 | sed "s/ //g")
  if [ "$firmware" = "SD17" -o "$firmware" = "SD37" ] ; then
    output="$output\n\nFIRMWARE-VERSION von $disk ($model) ist $firmware - MUSS geupdatet werden !!!\n\n"
  fi
done


echo -e "DMESG-CHECK\n$(date)" >> $LOGDIR/dmesg.sh.tmp
ERROR_DETAILS="##################### DMESG Error Details #####################"
if [ "$output" ] ; then
  #
  # write errors into logfile and report to rzadmin
  echo "$output" > $LOGDIR/$LOGFILE
  send2 test_log_raw "$TEST_ID" "dmesg_log" "$LOGDIR/$LOGFILE" > /dev/null
fi

if [ -s "$LOGDIR/dmesg_bootup.log" ]; then
  send2 test_log_raw "$TEST_ID" "__dmesg_bootup" "$LOGDIR/dmesg_bootup.log" > /dev/null
fi


###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"


result="$(send2 finished "$TEST_ID")"

if [ -n  "$result" -a "$result" == "test_ok" ]; then
  ERROR=0
  echo -e "\n\nDMESG-Check:\t OK" | $LOG
  echo "No errors found in dmesg output"
else
  ERROR=1
  ERRORMSG="DMESG-Fehler"
  echo -e "\n\nDMESG-Check:\t ERROR\n\n$ERROR_DETAILS\n$output" >> $LOGDIR/dmesg.sh.tmp
  catch_error "dmesg enthaelt Fehler" "ERROR"
  echo "dmesg:error:dmesg:dmesg contains error(s)" >> $ROBOT_LOGFILE
fi

# evaluate ERRORMSG, eventually filled by catch_error()
#
send_status "dmesg_result"


