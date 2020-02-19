#!/bin/bash
# written by Patrick Kratzer <patrick.kratzer@hetzner.de>

# setting global variables
## configuration variables
DEFAULT_ROOT_MOUNTPOINT="/mnt"
DEFAULT_VOLUMEGROUP="vg"
### default mountpoints (please fill in device in DEFAULT_DEVICES !AND! mountpoints in DEFAULT_MOUNTPOINTS)
DEFAULT_DEVICES=(/root /dev/md0 /tmp /usr /var /vartmp)
DEFAULT_MOUNTPOINTS=(/ /boot /tmp /usr /var /var/tmp)
## predefined colors
COL_RED="\033[31m"
COL_YELLOW="\033[33m"
COL_GREEN="\033[32m"
COL_RESET="\033[0m"

function usage(){
   echo -e "$COL_YELLOW""HOS - HDD-Automount Script for managed servers""$COL_RESET"
   echo -e "$COL_YELLOW""==============================================""$COL_RESET"
   echo
   echo -e "$COL_GREEN""Mounting all common devices under a specific mount point:""$COL_RESET"
   echo "hos-hdd_automount -m [ROOT_MOUNTPOINT]"
   echo
   echo -e "$COL_GREEN""Unmounting all commont devices under a specific mount point:""$COL_RESET"
   echo "hos-hdd_automount -u [ROOT_MOUNTPOINT]"
   echo
   echo -e "$COL_GREEN""Prepare one mount point for chroot:""$COL_RESET"
   echo "hos-hdd_automount -p [ROOT_MOUNTPOINT]"
   echo
   echo -e "$COL_GREEN""Open chroot environment for one mount point:""$COL_RESET"
   echo "hos-hdd_automount -c [ROOT_MOUNTPOINT]"
   echo
   echo -e "$COL_GREEN""Mount filesystems, prepare for chroot and start chroot environment:""$COL_RESET"
   echo "hos-hdd_automount -a [ROOT_MOUNTPOINT]"
   echo
   echo -e "$COL_GREEN""Display this help message:""$COL_RESET"
   echo "hos-hdd_automount -h"
   echo
}

function check_lvm(){
   volumegroup=$1
   ls /dev/$volumegroup/ > /dev/null
   if [ $? -eq 0 ]
   then
     echo -e "$COL_GREEN""Volume group $volumegroup seems to be running correctly""$COL_RESET"
   else
     echo -e "$COL_RED""Volume group $volumegroup seems to be inactive - starting LVM""$COL_RESET"
     vgchange -ay
   fi
}

function mount_devices(){
   root_mountpoint=$1
   if [ "$root_mountpoint" == "" ]
   then
     root_mountpoint=$DEFAULT_ROOT_MOUNTPOINT
   fi
   volumegroup=$2
   if [ "$volumegroup" == "" ]
   then
     volumegroup=$DEFAULT_VOLUMEGROUP
   fi
   counter=0
   for device in ${DEFAULT_DEVICES[*]}
   do
     if [ "$device" != "/dev/md0" ]
     then
       full_device_name=/dev/$volumegroup$device
     else
       full_device_name=$device
     fi
     full_mountpoint=$root_mountpoint${DEFAULT_MOUNTPOINTS[$counter]}
     echo "will mount $full_device_name on $full_mountpoint"
     if $(mount $full_device_name $full_mountpoint)
     then
       echo -e "$COL_GREEN""Finished successfully""$COL_RESET"
     else
       echo -e "$COL_RED""Errors when trying to mount - Please check manually""$COL_RESET"
       return 1
     fi
     let counter++
   done
}

function unmount_devices(){
   root_mountpoint=$1
   echo "will unmount devices under $root_mountpoint"
   if $(umount -l $root_mountpoint)
   then
     echo -e "$COL_GREEN""Finished successfully""$COL_RESET"
   else
     echo -e "$COL_RED""Errors when trying to unmount - Please check manually""$COL_RESET"
     return 1
   fi
}

function prepare_chroot(){
   root_mountpoint=$1
   echo "will prepare $root_mountpoint for croot"
   chroot-prepare $root_mountpoint
}

function start_chroot(){
   root_mountpoint=$1
   echo "will start chroot environment for $root_mountpoint"
   chroot $root_mountpoint
}

function main(){
   given_mountpoint=$2
   if [ "$given_mountpoint" == "" ]
   then
     given_mountpoint=$DEFAULT_ROOT_MOUNTPOINT
   fi
   case $1 in
     -m|-M)
            mount_devices $given_mountpoint $DEFAULT_VOLUME_GROUP
            ;;
     -u|-U)
            unmount_devices $given_mountpoint
            ;;
     -p|-P)
            prepare_chroot $given_mountpoint
            ;;
     -c|-C)
            start_chroot $given_mountpoint
            ;;
     -a|-A)
            mount_devices $given_mountpoint $DEFAULT_VOLUME_GROUP
            prepare_chroot $given_mountpoint
            start_chroot $given_mountpoint
            ;;
     *)
            usage
            break
            ;;
   esac
}

main $@
