#!/bin/bash

DIR="/root/.oldroot/nfs/ipmi/asus/KRPA-U16"

FWREV="2.00"
STEPFW="1.15"
FWDIR="$DIR/$FWREV"

# if update="true" bmc will be updated to latest version
update="$1"

get_fw_version() {
  local bmc_fw_ver="$(ipmitool mc info 2>/dev/null | awk '/Firmware Revision/{print $4}')"
  echo $bmc_fw_ver
}

CURRENT=$(get_fw_version)

if [ -n "$CURRENT" ]; then
  if $(dpkg --compare-versions $CURRENT lt $FWREV); then
    echo "BMC Firmware needs to be updated!"
    if [ "$update" = "true" ]; then
      echo -n "Starting Firmware update..."
      if $(dpkg --compare-versions $CURRENT lt $STEPFW); then
        cd $DIR/$STEPFW
        echo "Updating to $STEPFW"
        ./update.sh
        echo "done."
        echo "Waiting 120 seconds for BMC reboot..."
        sleep 120
        modprobe ipmi_si || (echo "unable to load ipmi driver (modprobe ipmi_si) - please wait another 120 seconds and try again. Otherwise try a full power cycle." && exit 1 )
        CURRENT=$(get_fw_version)
      fi
      if $(dpkg --compare-versions $CURRENT ge $STEPFW); then
        cd $FWDIR
        echo "Updating to $FWREV"
        ./update.sh
        echo "done."
        echo "Waiting 120 seconds for BMC reboot..."
        sleep 120
        modprobe ipmi_si || (echo "unable to load ipmi driver (modprobe ipmi_si) - please wait another 120 seconds and try again. Otherwise try a full power cycle." && exit 1 )
        CURRENT=$(get_fw_version)
      fi
      if $(dpkg --compare-versions $CURRENT eq $FWREV); then
        echo "Update successful."
        exit 0
      else
        echo "Update failed"
        exit 1
      fi
    fi
    # exit with error, as we should have updated
    exit 1
  else
    ipmitool lan print 8 &>/dev/null
    ret=$?
    if [ $ret == 0 ]; then
      echo "BMC Firmware needs to be updated!"
      if [ "$update" = "true" ]; then
        echo -n "Starting Firmware update..."
        cd $FWDIR
        ./update_fast.sh
        echo "done."
        echo "Waiting 120 seconds for BMC reboot..."
        sleep 120
        modprobe ipmi_si || (echo "unable to load ipmi driver (modprobe ipmi_si) - please wait another 120 seconds and try again. Otherwise try a full power cycle." && exit 1 )
        ipmitool lan print 8 &>/dev/null
        ret=$?
        if [ $ret == 1 ]; then
          echo "Update successful."
          exit 0
        else
          echo "Update failed"
          exit 1
        fi
      else
        # exit with error, as we should have updated
        exit 1
      fi
    else
      echo "BMC FW is up2date ($CURRENT)."
      exit 0
    fi
  fi
else
  echo "No BMC found."
  exit 0
fi

