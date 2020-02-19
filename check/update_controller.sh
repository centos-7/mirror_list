#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


rm $LOGDIR/updatecontroller*
#LOGFILE="/root/hwcheck-logs/update_controller.sh"

UPDATE_LOG="$LOGDIR/$LOGFILE"

echo $UPDATE_LOG

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
#send update-bios_result "WORKING" "Start $STARTTIME" "-" 
echo_green "=====  Update Controller BIOS  =====" 

if [ "$(get_raid)" ]; then
  if [ "$(get_3ware)" ]; then
    echo_yellow "3ware Controller detected" 
    echo_yellow "Update Controller"
    #starting update
    cd /opt/raid_ctrl/3ware; 
    tw_cli /c0 update fw=current.img force; 
    cd - > /dev/null;
    echo_green "Update completed"
    STATUS="3_WARE Update Successfull"
    echo $STATUS 
  fi
  if [ "$(get_adaptec)" ]; then
    /root/.oldroot/nfs/raid_ctrl/adaptec/update_adaptec.sh noprompt
  fi
  if [ "$(get_lsi)" ]; then
    echo_green "LSI Controller detected"
    echo_yellow "Update Controller"
    #check firmware version
    VERSION="$(megacli -AdpAllInfo -aAll | grep "FW Package" | awk -F'-' '{print $2}')"
    if [ "$VERSION" -lt "0090" ]; then
      echo_red "Update to 12.12.0-0090" | $LOG
      echo_red "This is not the latest version" | $LOG
      cd /opt/raid_ctrl/lsi;
      megacli -adpfwflash -f 12.12.0-0090.rom -a0
      cd - > /dev/null
      echo_green "Update completed"
      STATUS="LSI Updated - Not the latest version"
      echo ""
      echo_red "Reboot..."
        reboot
    else
      echo_yellow "Update to latest version"
      cd /opt/raid_ctrl/lsi;
      megacli -adpfwflash -f current.rom -a0
      cd - > /dev/null
      echo_green "Update completed"
      STATUS="LSI Update Successfull"
      echo $STATUS | $LOG
    fi
  fi
else
  echo_yellow "NO controller found" 
  #send update-bios_result "NONE" "NO controller found" "-"  
fi

###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
#send_status "update-bios_result"

#send update-bios_result "OK" "$STATUS" "-"
