#!/bin/bash

DIR="/root/.oldroot/nfs/ipmi/smc"

FWREV="1.18"
FWDIR="$DIR/X11SRA-RF_$FWREV"
IPMICFG="/root/.oldroot/nfs/ipmi/smc/ipmicfg/ipmicfg"

# if update="true" bmc will be updated to latest version
update="$1"

get_fw_version() {
 local bmc_fw_ver="$(ipmitool mc info | grep 'Firmware Revision' | cut -d ':' -f 2 | sed -e 's/ //g')"
 echo $bmc_fw_ver
}

bmc_current_ver=$(get_fw_version)

if [ "$bmc_current_ver" != "$FWREV" ]; then
  echo "BMC Firmware needs to be updated!"
  if [ "$update" = "true" ]; then
    echo -n "Starting Firmware update..."
    MAC=$($IPMICFG -m|tail -1|sed -e 's/MAC=//g')
    cd $FWDIR
    ./update.sh
    echo "done."
    echo "Waiting 60 seconds for BMC reboot..."
    sleep 60
    $IPMICFG -a $MAC
    sleep 5
    MAC_NEW=$($IPMICFG -m|tail -1|sed -e 's/MAC=//g')
    if [ "$MAC" = "$MAC_NEW" ]; then
      echo "IPMI MAC reset successful, reconfiguring static network"
      $IPMICFG -fde
      /bin/sleep 10
      /usr/bin/ipmitool lan set 1 ipsrc static
      /bin/sleep 15
      /usr/bin/ipmitool lan set 1 ipaddr 0.0.0.0
      /usr/bin/ipmitool lan set 1 ipaddr 0.0.0.0
      bmc_current_ver=$(get_fw_version)
      if [[ "$bmc_current_ver" = "$FWREV" && "$MAC" = "$MAC_NEW" ]]; then
        echo "Update successful."
        exit 0
      else
        echo "Update failed"
        exit 1
      fi
    else
      echo "resetting MAC address failed. Please set manually!"
      exit 1
    fi
  fi
  # exit with error, as we should have updated
  exit 1
else
  echo "BMC FW is up2date ($bmc_current_ver)."
  exit 0
fi
