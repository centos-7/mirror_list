TARGETS = mountkernfs.sh udev keyboard-setup.sh mountdevsubfs.sh cryptdisks cryptdisks-early hostname.sh checkfs.sh mountall.sh mountall-bootclean.sh mountnfs.sh mountnfs-bootclean.sh hwclock.sh checkroot.sh lvm2 networking urandom brightness bootlogd procps x11-common checkroot-bootclean.sh bootmisc.sh lm-sensors stop-bootlogd-single screen-cleanup kmod
INTERACTIVE = udev keyboard-setup.sh cryptdisks cryptdisks-early checkfs.sh checkroot.sh
udev: mountkernfs.sh
keyboard-setup.sh: mountkernfs.sh
mountdevsubfs.sh: udev
cryptdisks: udev checkroot.sh cryptdisks-early lvm2
cryptdisks-early: udev checkroot.sh
hostname.sh: bootlogd
checkfs.sh: cryptdisks
mountall.sh: checkfs.sh checkroot-bootclean.sh
mountall-bootclean.sh: mountall.sh
mountnfs.sh: mountall.sh mountall-bootclean.sh networking
mountnfs-bootclean.sh: mountall.sh mountall-bootclean.sh mountnfs.sh
hwclock.sh: mountdevsubfs.sh bootlogd
checkroot.sh: mountdevsubfs.sh keyboard-setup.sh hwclock.sh hostname.sh bootlogd
lvm2: mountdevsubfs.sh cryptdisks-early bootlogd
networking: mountkernfs.sh mountall.sh mountall-bootclean.sh urandom procps
urandom: mountall.sh mountall-bootclean.sh hwclock.sh
brightness: mountall.sh mountall-bootclean.sh
bootlogd: mountdevsubfs.sh
procps: udev mountall.sh mountall-bootclean.sh bootlogd
x11-common: mountnfs.sh mountnfs-bootclean.sh
checkroot-bootclean.sh: checkroot.sh
bootmisc.sh: udev mountnfs-bootclean.sh checkroot-bootclean.sh mountall-bootclean.sh mountnfs.sh mountall.sh
lm-sensors: mountnfs.sh mountnfs-bootclean.sh
stop-bootlogd-single: mountall.sh mountall-bootclean.sh
screen-cleanup: mountnfs.sh mountnfs-bootclean.sh
kmod: checkroot.sh
