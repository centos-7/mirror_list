#!/bin/bash

#
# this script tests the harddisk(s) of this machine
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

MODE=$1

rm $LOGDIR/hddtest*
echo "$MODE"

# send abort status, if signal catched
# 
abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  for hdd in $(get_disks | cut -d: -f1 | cut -d/ -f3) ; do
    serials=$(get_all_hdd_serials | grep $hdd | cut -d: -f2)
  done
}
trap "abort ; kill -9 $$" 1 2 9 15

echo_yellow "\n=====  HARDDISK TEST (SMART)  =====\n"


if [ "$(get_raid)" ]; then
  # prepare screenrc
  #
  screenrc="/tmp/screenrc-$(basename $0)-$$"
  cat <<EOF >$screenrc
  ## zombie on
  caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
  hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="

EOF

  RAIDCONTROLLER="$(get_raid)"

# 3ware RAID Controller
#
  if [ "$(echo $RAIDCONTROLLER | grep 3ware)" ]; then 
    EXTENTION="-d 3ware,"

    # Check with tw_cli controllernumber $c, devices $p and start smarttest in a screen
    #
    CX="$(tw_cli show | grep ^c | cut -c 1-2)"
    # Controler counter for tw device
    CONTROLLER_COUNT=0
    for c in $CX; do
      CNUMBER="$(echo $c | cut -c 2)"
      PATTERN="$(ls /dev/ | grep "^tw" | head -n1 | cut -c 1-3)"
      DEVPFAD="/dev/$PATTERN$CONTROLLER_COUNT"
      PX="$(tw_cli /$c show | grep ^p  | awk '{print $1}')"
      for p in $PX; do
        serial="$(tw_cli /$c/$p show serial | awk -F' ' '{print $4}')"
        PNUMBER="$(echo $p | cut -c 2)"
        if [ "$(smartctl $EXTENTION$PNUMBER $DEVPFAD -H | grep failed)" ]; then
          echo error
        else
          echo "screen -t $DEVPFAD  bash -c 'bash $PWD/hddtest_smart_worker.sh $DEVPFAD $serial $MODE \"$EXTENTION$PNUMBER\" ; sleep 2'" >> $screenrc
          sleep 2
        fi
      done
      CONTROLLER_COUNT=$(($CONTROLLER_COUNT+1))
    done
  fi

# Adaptec RAID COntroller
#
  if [ "$(echo $RAIDCONTROLLER | grep Adaptec)" ]; then
    # Start sg modul that we have the sgX devices in /dev
    modinfo sg >> /dev/null
    modprobe sg >> /dev/null

    EXTENTION="-d sat"

    # Check with arcconf devicecount
    #
    DEVPFAD="/dev/sg"
    sleep 2
 
    for device in $(ls $DEVPFAD[1-9]*); do
      serial=$(smartctl -a -d scsi $device | grep "Serial number:" | awk '{print $3'})
      if [ "$(smartctl $EXTENTION $device -H | grep failed)" ]; then
           # maybe it is a scsi device
           EXTENTION="-d scsi"
           if [ "$(smartctl $EXTENTION $device -H | grep failed)" ]; then
	      echo error
           else
              echo "screen -t $device  bash -c 'bash $PWD/hddtest_smart_sasworker.sh $device \"$(echo $serial)\" $MODE \"$EXTENTION\" ; sleep 2'" >> $screenrc
              # set extension to the old state for the next run of the loop
              EXTENTION="-d sat"
              sleep 2
           fi
      else
        echo "screen -t $device  bash -c 'bash $PWD/hddtest_smart_worker.sh $device \"$(echo $serial)\" $MODE \"$EXTENTION\" ; sleep 2'" >> $screenrc
        sleep 2
      fi
    done
  fi


# LSI RAID Controller
#
  if [ "$(echo $RAIDCONTROLLER | grep LSI)" ]; then 
    EXTENTION="-d megaraid,"

    # Check with tw_cli controllernumber $c, devices $p and start smarttest in a screen
    #
      DEVPFAD="/dev/sda"
      LSI_ADP="$(megacli -pdgetnum -aall | grep "Number" | awk '{print $7}' | cut -c 1)"
      for adp in $LSI_ADP; do
         LSI_SLOT=0
         LSI_DI="$(megacli -pdlist -a$adp | grep "Device Id" | awk '{print $3}')"
         for di in $LSI_DI; do
	   LSI_SLOT="$(( ${LSI_SLOT}+1 ))" 
          if [ "$(/usr/sbin/smartctl $EXTENTION$di $DEVPFAD -H | grep failed)" ]; then
	    echo error
          else
	    if [ "$(/usr/sbin/smartctl -a $EXTENTION$di $DEVPFAD | grep "Transport protocol" | grep "SAS")" ]; then
              serial="$(/usr/sbin/smartctl -a $EXTENTION$di $DEVPFAD | grep "Serial" | awk '{print $3}' | cut -c1-8 )"
              echo "screen -t $DEVPFAD bash -c 'bash $PWD/hddtest_smart_lsi_worker.sh ${DEVPFAD} ${serial} ${MODE} \"${EXTENTION}${di}\" ; sleep 2'" >>  $screenrc
	    else
              serial="$(/usr/sbin/smartctl -a $EXTENTION$di $DEVPFAD | grep "Serial" | awk '{print $3}' )"
              if [ "$(echo $serial | grep 'WD-')" ]; then 
                serial="$(echo $serial | cut -d- -f2 )"
              fi
              echo "screen -t $DEVPFAD bash -c 'bash $PWD/hddtest_smart_worker.sh ${DEVPFAD} ${serial} ${MODE} \"${EXTENTION}${di}\" ; sleep 2'" >>  $screenrc
	    fi
            sleep 2
          fi
        done
      # done
    done
  fi

fi

# if no disks found, return error
#

if [ -z "$(get_raid)" ]; then
if [ "$(get_hdd)" ]; then

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"


STARTTIME="$(date +%d.%m.\ %H:%M)"
echo_grey "START: $STARTTIME"


# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
cat <<EOF >$screenrc
## zombie on
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="

EOF


# add screen windows with smartctl commands
for diskdata in $(get_disks) ; do
  disk=$(echo $diskdata | cut -d: -f1)
  size=$(echo $diskdata | cut -d: -f2)
  disk_wo_dev=$(echo $disk | cut -d/ -f3)
  serials=$(get_all_hdd_serials | grep $disk_wo_dev | cut -d: -f2)

    echo "screen -t $disk bash -c 'bash $PWD/hddtest_smart_worker.sh $disk \"$(echo $serials)\" $MODE ; sleep 2'" >> $screenrc
  
done
fi
fi
# start erasing in a screen session: start screen and stay attached
#
sleep 1
screen -mS $(basename $0) -c $screenrc
#rm $screenrc
#rm $LOGDIR/hddtest*

# end
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"
