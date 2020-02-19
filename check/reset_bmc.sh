#!/bin/bash


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function

BMCLOG="$LOGDIR/resetbmc"
rm $BMCLOG 2>/dev/null
RESET="$1"
STATUS=""
STATUS_MESSAGE=""
ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
echo_green "=====  Reset BMC  ====="

# get mainboard name
mainboard="$(get_mainboard | cut -d' ' -f1)"

if [ "$mainboard" = "S1200RP" ] ; then
  # Intel S1200V3RP
  echo_yellow "Found S1200RP mainboard"

  # get current bios-version
  bios_version="$(get_bios_version | cut -d' ' -f1 | cut -d. -f3,4,5 | tr "." "-")"

  echo_yellow " - reset BMC/IPMI settings ... "
  # reset BMC to factory defaults
  /root/.oldroot/nfs/ipmi/intel/reset_intel.sh >> $BMCLOG
  exitcode="$?"
  if [ $exitcode -gt 0 ] ; then
    echo_red "   reset BMC/IPMI failed"
  else
    echo_green "   reset BMC/IPMI done"
  fi

  if [ $exitcode -eq 0 ] ; then
    echo_yellow " - configure FRU/SDR ... "
    # update fru/sdr settings
    /root/.oldroot/nfs/firmware_update/intel/S1200RP/frusdr.sh "$bios_version" >> $BMCLOG
    exitcode="$?"
    if [ $exitcode -gt 0 ] ; then
      echo_red "   reset FRU/SDR failed"
      echo "FRU/SDR update failed" >> $BMCLOG
    else
      echo_green "   reset FRU/SDR done"
    fi
  fi

  if [ $exitcode -gt 0 ] ; then
    STATUS="ERROR"
    STATUS_MESSAGE="BMC Reset failed"
  else
    STATUS="OK"
    STATUS_MESSAGE="BMC Reset Successfull"
  fi
  echo $STATUS | $LOG
elif [ -n "$(echo "$mainboard" | grep -i x9sri)" ] ; then
  # Supermicro X9SRI
  echo_yellow "Found X9SRi-F mainboard"

  echo_yellow " - check firmware and update if outdated ... "
  /root/.oldroot/nfs/ipmi/smi/check_update_x9sri.sh true >> $BMCLOG

  echo_yellow " - reset BMC/IPMI settings ... "
  # reset BMC to factory defaults
  /root/.oldroot/nfs/ipmi/smi/reset.sh reset >> $BMCLOG
  exitcode="$?"
  if [ $exitcode -gt 0 ] ; then
    echo_red "   reset BMC/IPMI failed"
  else
    echo_green "   reset BMC/IPMI done"
  fi

  if [ $exitcode -gt 0 ] ; then
    STATUS="ERROR"
    STATUS_MESSAGE="BMC Reset failed"
  else
    STATUS="OK"
    STATUS_MESSAGE="BMC Reset Successfull"
  fi
  echo $STATUS | $LOG
elif [ -n "$(echo "$mainboard" | grep -i h8sgl)" ] ; then
  # Supermicro H8SGL
  echo_yellow "Found H8SGL-F mainboard"

  echo_yellow " - check firmware and update if outdated ... "
  /root/.oldroot/nfs/ipmi/smi/check_update_h8sgl.sh true >> $BMCLOG

  echo_yellow " - reset BMC/IPMI settings ... "
  # reset BMC to factory defaults
  /root/.oldroot/nfs/ipmi/smi/reset.sh reset >> $BMCLOG
  exitcode="$?"
  if [ $exitcode -gt 0 ] ; then
    echo_red "   reset BMC/IPMI failed"
  else
    echo_green "   reset BMC/IPMI done"
  fi

  if [ $exitcode -gt 0 ] ; then
    STATUS="ERROR"
    STATUS_MESSAGE="BMC Reset failed"
  else
    STATUS="OK"
    STATUS_MESSAGE="BMC Reset Successfull"
  fi
  echo $STATUS | $LOG
elif [ -n "$(echo "$mainboard" | grep -i z10pa-u8)" ] ; then
  # ASUS Z10PA-U8
  echo_yellow "Found Z10PA-U8 mainboard"

  echo_yellow " - check firmware and update if outdated ... "
  /root/.oldroot/nfs/ipmi/asus/check_update_z10pa-u8.sh true >> $BMCLOG

  echo_yellow " - reset BMC/IPMI settings ... "
  # reset BMC to factory defaults
  /root/.oldroot/nfs/ipmi/asus/reset.sh reset >> $BMCLOG
  exitcode="$?"
  if [ $exitcode -gt 0 ] ; then
    echo_red "   reset BMC/IPMI failed"
  else
    echo_green "   reset BMC/IPMI done"
  fi

  if [ $exitcode -gt 0 ] ; then
    STATUS="ERROR"
    STATUS_MESSAGE="BMC Reset failed"
  else
    STATUS="OK"
    STATUS_MESSAGE="BMC Reset Successfull"
  fi
  echo $STATUS | $LOG
elif [ -n "$(echo "$mainboard" | grep -i x11sra-rf)" ] ; then
  # SMC X11SRA-RF
  echo_yellow "Found X11SRA-RF mainboard"

  echo_yellow " - check firmware and update if outdated ... "
  /root/.oldroot/nfs/ipmi/smc/check_update_x11sra-rf.sh true >> $BMCLOG

  echo_yellow " - reset BMC/IPMI settings ... "
  # reset BMC to factory defaults
  /root/.oldroot/nfs/ipmi/smc/reset.sh reset >> $BMCLOG
  exitcode="$?"
  if [ $exitcode -gt 0 ] ; then
    echo_red "   reset BMC/IPMI failed"
  else
    echo_green "   reset BMC/IPMI done"
  fi

  if [ $exitcode -gt 0 ] ; then
    STATUS="ERROR"
    STATUS_MESSAGE="BMC Reset failed"
  else
    STATUS="OK"
    STATUS_MESSAGE="BMC Reset Successfull"
  fi
  echo $STATUS | $LOG
elif [ -n "$(echo "$mainboard" | grep -i krpa-u16)" ] ; then
  # ASUS KRPA-U16
  echo_yellow "Found KRPA-U16 mainboard"

  echo_yellow " - check firmware and update if outdated ... "
  /root/.oldroot/nfs/ipmi/asus/KRPA-U16/check_update_krpa-u16.sh true >> $BMCLOG

  echo_yellow " - reset BMC/IPMI settings ... "
  # reset BMC to factory defaults
  /root/.oldroot/nfs/ipmi/asus/KRPA-U16/reset.sh reset >> $BMCLOG
  exitcode="$?"
  if [ $exitcode -gt 0 ] ; then
    echo_red "   reset BMC/IPMI failed"
  else
    echo_green "   reset BMC/IPMI done"
  fi

  if [ $exitcode -gt 0 ] ; then
    STATUS="ERROR"
    STATUS_MESSAGE="BMC Reset failed"
  else
    STATUS="OK"
    STATUS_MESSAGE="BMC Reset Successfull"
  fi
  echo $STATUS | $LOG
else
  echo_yellow "NO supported mainboard found"
  STATUS="NONE"
  STATUS_MESSAGE="NO supported mainboard found"
fi


###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

if [ "$STATUS" != "NONE" ]; then
  if [ "$RESET" == "reset" ]; then
    send2 reset

    #
    # send hwdata to new.rz-admin
    echo_grey "\nsend hardware information to rz-admin ..."
    $PWD/report.sh

  fi
 
  #
  # report bmc_reset
  TEST_ID="$(send2 bmc)"

  send2 test_log_json "$TEST_ID" "{\"STATUS\":\"$STATUS\",\"MESSAGE\":\"$STATUS_MESSAGE\"}" > /dev/null
  send2 test_log_raw "$TEST_ID" "bmc_log" "$BMCLOG" > /dev/null

  echo "reset_bmc:$(send2 finished "$TEST_ID"):$STATUS_MESSAGE" >> $ROBOT_LOGFILE
fi
