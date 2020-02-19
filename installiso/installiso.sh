#!/usr/bin/env bash

VERSION='0.1.0'
MINIMUM_HARDDISK_SIZE=$((7*1024**3)) # 7GiB
ISOHYBRID_SCRIPT='/root/.oldroot/nfs/installiso/isohybrid.pl'
MINIMUM_USB_DISK_SIZE=$MINIMUM_HARDDISK_SIZE
MEMDISK_FILE='/root/.oldroot/nfs/installiso/memdisk'

checksum() {
  set -- $(cksum "$0")
  echo "$1"
}

usage() {
  echo 'usage: installiso <iso_uri>' >&2
  exit 1
}

iso_uri_ok() {
  local iso_uri="$1"
  [[ "$iso_uri" =~ ^([^:]*)://.*$ ]] &&
    [[ "${BASH_REMATCH[1]}" =~ ^file$|^ftp[s]?$|^http[s]?$ ]]
}

error() {
  local message="$1"
  echo "error: $message" >&2
  exit 1
}

disks() {
  for dir in /sys/block/*; do
    [[ -e "$dir" ]] &&
      ! [[ -e "/sys/devices/virtual/block/${dir##*/}" ]] &&
      echo "/dev/${dir##*/}"
  done
}

usb_disk() {
  local disk="$1"
  local udevadm_info="$(udevadm info "/sys/class/block/${disk##*/}")"
  [[ "$udevadm_info" =~ DEVTYPE=disk ]] &&
    [[ "$udevadm_info" =~ ID_BUS=usb ]] &&
    [[ "$udevadm_info" =~ ID_USB_DRIVER=usb-storage ]]
}

harddisks() {
  while read -r disk; do
    usb_disk "$disk" ||
      echo "$disk"
  done < <(disks)
}

harddisks_present() {
  set -- $(harddisks)
  (( $# != 0 ))
}

disk_size() {
  local disk="$1"
  blockdev --getsize64 "$disk"
}

largest_harddisk() {
  set -- $(harddisks)
  local largest_harddisk="$1"
  while read -r harddisk; do
    (( "$(disk_size "$harddisk")" > "$(disk_size "$largest_harddisk")" )) &&
      largest_harddisk="$harddisk"
  done < <(harddisks)
  echo "$largest_harddisk"
}

harddisks_large_enough() {
  (( "$(disk_size "$(largest_harddisk)")" >= "$MINIMUM_HARDDISK_SIZE" ))
}

umount_disks() {
  echo 'umounting disks'
  while read -r disk _; do
    [[ "$disk" =~ ^/dev/.* ]] ||
      continue
    [[ -e "$disk" ]] ||
      continue
    disk="$(readlink -f "$disk")"
    [[ -e "$disk" ]] ||
      continue
    if ! umount "$disk"; then
      error "umounting $disk failed"
    fi
  done < <(tac /proc/mounts)
}

md_disks() {
  for dir in /sys/class/block/*/md; do
    [[ -e "$dir" ]] ||
      continue
    dir="${dir%/*}"
    echo "/dev/${dir##*/}"
  done
}

stop_md_disks() {
  echo 'stopping md disks'
  while read -r md_disk; do
    if ! mdadm -S "$md_disk"; then
      error "stopping $md_disk failed"
    fi
  done < <(md_disks)
}

disk_partitions() {
  local disk="$1"
  for file in "/sys/class/block/${disk##*/}/"*/partition; do
    [[ -e "$file" ]] ||
      continue
    dir="${file%/*}"
    echo "/dev/${dir##*/}"
  done
}

wipe_disk() {
  local disk="$1"
  while read -r partition; do
    wipefs -a -f "$partition" &> /dev/null || return 1
  done < <(disk_partitions "$disk")
  wipefs -a -f "$disk" &> /dev/null &&
    dd bs=512 count=1 if=/dev/zero of="$disk" &> /dev/null &&
    partprobe "$disk"
}

wait_for_partition() {
  local partition="$1"
  local i=0
  while :; do
    if [[ -e "$partition" ]]; then
      i+=1
    else
      i=0
    fi
    (( $i > 20 )) &&
      return
    sleep 0.1
  done
}

setup_tmp_storage() {
  local mountpoint="$1"
  local largest_harddisk="$(largest_harddisk)"
  echo 'setting up tmp storage'
  wipe_disk "$largest_harddisk" || error "wiping $largest_harddisk failed"
  if ! parted -s "$largest_harddisk" mklabel msdos ||
       ! parted -s "$largest_harddisk" mkpart primary ext4 4MiB 10244MiB; then
    error "partitioning $largest_harddisk failed"
  fi
  wait_for_partition "${largest_harddisk}1"
  mkfs.ext4 "${largest_harddisk}1" &> /dev/null || error "formatting ${largest_harddisk}1 failed"
  mount "${largest_harddisk}1" "$mountpoint" || error 'mounting ${largest_harddisk}1 failed'
}

iso_hybrid() {
  local iso="$1"
  [[ "$(dd bs=1 count=2 if="$iso" skip=510 2> /dev/null | xxd -ps)" == '55aa' ]]
}

try_to_make_iso_hybrid() {
  local iso="$1"
  "$ISOHYBRID_SCRIPT" "$iso" &> /dev/null
}

usb_disks() {
  while read -r disk; do
    usb_disk "$disk" &&
      echo "$disk"
  done < <(disks)
}

usb_disks_present() {
  set -- $(usb_disks)
  (( $# != 0 ))
}

wait_for_usb_disk() {
  usb_disks_present ||
    echo 'waiting for usb disk'
  until usb_disks_present; do sleep 1; done
}

largest_usb_disk() {
  set -- $(usb_disks)
  local largest_usb_disk="$1"
  while read -r usb_disk; do
    (( "$(disk_size "$usb_disk")" > "$(disk_size "$largest_usb_disk")" )) &&
      largest_usb_disk="$usb_disk"
  done < <(usb_disks)
  echo "$largest_usb_disk"
}

usb_disk_large_enough() {
  local usb_disk="$1"
  (( "$(disk_size "$usb_disk")" >= "$MINIMUM_USB_DISK_SIZE" ))
}

setup_harddisks() {
  local tmp_dir="$(mktemp -d)"
  echo 'setting up harddisks'
  while read -r harddisk; do
    wipe_disk "$harddisk" || error "wiping $harddisk failed"
    if ! parted -s "$harddisk" mklabel gpt ||
         ! parted -s "$harddisk" mkpart primary fat32 4MiB 8MiB ||
         ! parted -s "$harddisk" mkpart primary fat32 8MiB 520MiB ||
         ! parted -s "$harddisk" set 1 bios_grub on ||
         ! parted -s "$harddisk" set 2 boot on; then
      error "partitioning $harddisk failed"
    fi
    wait_for_partition "${harddisk}1"
    wait_for_partition "${harddisk}2"
    mkfs.vfat -F 32 -n EFIBOOT "${harddisk}2" &> /dev/null || error "formatting ${harddisk}2 failed"
    mount "${harddisk}2" "$tmp_dir" || error "mounting ${harddisk}2 failed"
    if ! grub-install --root-directory="$tmp_dir" "$harddisk" &> /dev/null ||
         ! grub-mkdevicemap --device-map="$tmp_dir/boot/grub/device.map"; then
      error "installing grub on $harddisk failed"
    fi
    cp "$MEMDISK_FILE" "$tmp_dir" || error 'copying memdisk file failed'
    umount "$tmp_dir" || error "umounting ${harddisk}2 failed"
  done < <(harddisks)
  rmdir "$tmp_dir" || error 'removing tmp dir failed'
}

grub_hdd_name() {
  local disk="$1"
  while read hdd_name link; do
    [[ "$(readlink -f "$link")" == "$disk" ]] &&
      echo "$hdd_name" &&
      return
  done < <(grub-mkdevicemap --device-map=-)
}

setup_grub() {
  local stdin="$(cat)"
  local tmp_dir="$(mktemp -d)"
  echo 'setting up grub'
  while read -r harddisk; do
    mount "${harddisk}2" "$tmp_dir" || error "mounting ${harddisk}2 failed"
    {
      echo 'default=0'
      echo 'timeout=0'
      echo 'menuentry "installiso" {'
      echo 'insmod part_msdos'
      echo "$stdin"
      echo 'boot'
      echo '}'
    } > "$tmp_dir/boot/grub/grub.cfg"
    umount "$tmp_dir" || error "umounting ${harddisk}2 failed"
  done < <(harddisks)
  rmdir "$tmp_dir" || error 'removing tmp dir failed'
}

setup_hybrid_iso_boot() {
  local usb_disk="$1"
  setup_harddisks
  {
    echo 'insmod chain'
    echo "set root=$(grub_hdd_name "$usb_disk")"
    echo 'chainloader +1'
  } | setup_grub
}

setup_usb_disk() {
  local usb_disk="$1"
  echo 'setting up usb disk'
  wipe_disk "$usb_disk" || error "wiping usb disk failed"
  if ! parted -s "$usb_disk" mklabel msdos ||
       ! parted -s "$usb_disk" mkpart primary ntfs 4MiB '100%'; then #||
       #! parted -s "$usb_disk" set 1 boot on; then
    error "partitioning usb disk failed"
  fi
  wait_for_partition "${usb_disk}1"
  mkfs.ntfs -f "${usb_disk}1" &> /dev/null || error "formatting usb disk failed"
}

extract_iso() {
  local iso="$1"
  local dest="$2"
  local tmp_dir="$(mktemp -d)"
  echo 'extracting iso'
  mount "$iso" "$tmp_dir" &> /dev/null || error 'mounting iso failed'
  rsync -rlptD "$tmp_dir/" "$dest/" || error 'extracting iso failed'
  umount "$tmp_dir" || error 'umounting iso failed'
  rmdir "$tmp_dir" || error 'removing tmp dir failed'
}

filesystem_uuid() {
  local dsk="$1"
  blkid -o value -s UUID "$dsk"
}

setup_windows_boot() {
  local dsk="$1"
  setup_harddisks
  {
    echo 'insmod ntfs'
    echo 'insmod ntldr'
    echo "search --fs-uuid $(filesystem_uuid "$dsk") --no-floppy --set=root"
    echo 'ntldr /bootmgr'
  } | setup_grub
}

setup_memdisk_boot() {
  local dsk="$1"
  local iso_name="$2"
  setup_harddisks
  {
    echo 'insmod ntfs'
    echo "search --fs-uuid $(filesystem_uuid "$dsk") --no-floppy --set=root"
    echo "initrd16 $iso_name"
    echo "linux16 memdisk"
  } | setup_grub
}

checksum="$(checksum)"
echo 3 > /proc/sys/vm/drop_caches
[[ "$(checksum)" != "$checksum" ]] && exec "$0" "$@"

(( $# == 0 )) && usage

iso_uri="$1"

iso_uri_ok "$iso_uri" || error 'invalid iso uri'
harddisks_present || error 'no harddisks present'
harddisks_large_enough || error 'harddisks are too small'

umount_disks
echo 'running dmsetup remove_all'
dmsetup remove_all || error 'dmsetup remove_all failed'
stop_md_disks

tmp_dir="$(mktemp -d)"

setup_tmp_storage "$tmp_dir" || error 'setting up tmp storage failed'

echo 'downloading iso'
curl -k -L -o "$tmp_dir/install.iso" "$iso_uri" || error 'downloading iso failed'

iso_hybrid "$tmp_dir/install.iso" || try_to_make_iso_hybrid "$tmp_dir/install.iso"

wait_for_usb_disk

largest_usb_disk="$(largest_usb_disk)"

usb_disk_large_enough "$largest_usb_disk" || error 'usb disk is too small'

if iso_hybrid "$tmp_dir/install.iso"; then
  dd bs=4M if="$tmp_dir/install.iso" of="$largest_usb_disk" &> /dev/null || error 'writing usb disk failed'
  umount "$tmp_dir" || error 'umounting tmp dir failed'
  rmdir "$tmp_dir" || error 'removing tmp dir failed'
  setup_hybrid_iso_boot "$largest_usb_disk"
else
  setup_usb_disk "$largest_usb_disk"
  usb_mnt="$(mktemp -d)"
  mount "${largest_usb_disk}1" "$usb_mnt" || error 'mounting usb disk failed'
  extract_iso "$tmp_dir/install.iso" "$usb_mnt"
  umount "$tmp_dir" || error 'umounting tmp dir failed'
  rmdir "$tmp_dir" || error 'removing tmp dir failed'
  if [[ -e "$usb_mnt/bootmgr" ]]; then
    setup_windows_boot "${largest_usb_disk}1"
  else
    tmp_file="$(mktemp -p "$usb_mnt")"
    echo 'copying iso to usb disk'
    rsync -avP "$tmp_dir/install.iso" "$tmp_file" || error 'copying iso to usb disk failed'
    setup_memdisk_boot "${largest_usb_disk}1" "${tmp_file##*/}"
  fi
  umount "$usb_mnt" || error 'umounting usb disk failed'
  rmdir "$usb_mnt" || error 'removing usb mnt dir failed'
fi

echo 'rebooting in 15 seconds'
sleep 15
reboot
