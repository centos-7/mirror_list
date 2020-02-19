#!/bin/bash

#
# this script resets the status of this machine
#
# david.mayr@hetzner.de - 2007.08.22


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


echo_yellow "Reset test status for this computer ..."


# check if adaptec raid controller exists and disable alarm
if [ -x "$(which arcconf)" ] ; then
  if [ "$(get_adaptec)" ]; then
    adaptec_controllers="$(arcconf getversion | grep -i 'Controllers found:' | head -n 1 | awk '{print $3}')"
    if [ "$adaptec_controllers" != "0" ] ; then
      echo_green "Found Adaptec RAID controller, disable audible alarms."
      arcconf setalarm 1 off
    fi
  fi
else
  echo_red "Arcconf tool for Adaptec RAID controllers not found / not executable."
fi

# check if lsi raid controller exists and disable alarm
if [ -x "$(which megacli)" ]; then 
  lsi_controller="$(megacli -LDInfo -Lall -Aall | grep 'Adapter' | awk '{print $2}')"
  if [ "$lsi_controller" == "0" ]; then
    echo_green "Found LSI RAID Controller, disable audible alarms."
    megacli -AdpSetProp -AlarmDsbl -aALL
    megacli -AdpBIOS -BE -aALL
  fi
else 
  echo_red "MegaCLI tool for LSI RAID controller not found / not executable."
fi
