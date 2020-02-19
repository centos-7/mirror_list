#!/bin/bash
source /root/.oldroot/nfs/firmware_update/scripts/functions.sh
NFSPATH="/root/.oldroot/nfs/ipmi/asus/"
SCRIPTSPATH="/root/.oldroot/nfs/ipmi/scripts/"
BOARD=$(get_mainboard)

if [[ "$BOARD" =~ "KRPA-U16" ]]; then
  # check if bmc is available
  ipmitool mc info 1>/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "No BMC found!"
    exit 0
  fi

  # reset bmc
  echo -n "Resetting BMC to factory defaults ... "
  ipmitool raw 0x06 0x02 > /dev/null
  if [ $? -eq 0 ] ; then
    echo "done"
  else
    echo "failed"
    exit 1
  fi

  echo " Wait 5 seconds to let BCM restart ..."
  sleep 5

  echo -n " Wait for BMC getting up again ... "
  count=0
  found=0

  ipmitool mc info > /dev/null &
  ipmitool_pid=$!

  while [ $count -lt 30 ] ; do
    sleep 3
    if ! kill -0 $ipmitool_pid 1>/dev/null 2>&1 ; then
      found=1
      break
    fi
    let count=count+1
  done

  if [ $found -eq 1 ] ; then
    echo "up"

    count=0
    found=0
    echo -n " Check if BMC is available ... "
    while [ $count -lt 15 ] ; do
      sleep 2
      if [ "$(ipmitool mc info 2>/dev/null | awk '/^Device Available/{print $4}')" == "yes" ] ; then
        found=1
        break
      fi
      let count=count+1
    done

    if [ $found -eq 1 ] ; then
      echo "yes"
    else
      echo "no"
      echo "Please check with command 'ipmitool mc info'!"
      exit 4
    fi
  else
    echo "down"
    exit 3
  fi

  ipmitool raw 0x30 0x0e 0x04 0x00 0x23 0x0a 0x28 0x19 0x32 0x3c 0x3c 0x64 0x5e 0x64
  ipmitool raw 0x30 0x0e 0x04 0x01 0x23 0x0a 0x28 0x19 0x32 0x3c 0x3c 0x64 0x5e 0x64
  ipmitool raw 0x30 0x0e 0x04 0x02 0x23 0x0a 0x28 0x19 0x32 0x3c 0x3c 0x64 0x5e 0x64
  ipmitool raw 0x30 0x0e 0x04 0x03 0x23 0x0a 0x28 0x19 0x32 0x3c 0x3c 0x64 0x5e 0x64
  ipmitool raw 0x32 0xaa 0x01
fi
exit 0
