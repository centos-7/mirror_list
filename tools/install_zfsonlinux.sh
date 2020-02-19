#!/bin/bash
echo -e "\e[31m\e[1mATTENTION\e[0m

This script will attempt to install the current ZFSonLinux release
which is available in the ZFSonLinux git repository to the Rescue
System. \e[31m\e[1mIf this script fails, do not contact Hetzner Support, as
it is provided AS-IS and Hetzner will not support the installation
or usage of ZFSonLinux due to License imcompatiblity (see below)\e[0m.
"

echo -e "\e[31m\e[1mLicenses of ZFS and Linux are incompatible\e[0m

ZFS is licensed under the Common Development and Distribution License (CDDL),
and the Linux kernel is licensed under the GNU General Public License Version 2
(GPL-2). While both are free open source licenses they are restrictive
licenses. The combination of them causes problems because it prevents using
pieces of code exclusively available under one license with pieces of code
exclusively available under the other in the same binary.

Please be aware that distributing of the binaries may lead to infringing.

Press \e[31m\e[1my\e[0m to accept this."
read -p "" -n 1 ;echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

cd $(mktemp -d)
wget $(curl -s https://api.github.com/repos/zfsonlinux/zfs/releases/latest| grep "browser_download_url.*tar.gz"|grep -E "tar.gz\"$"| cut -d '"' -f 4)
apt update && apt install libssl-dev uuid-dev zlib1g-dev libblkid-dev -y && tar xfv zfs*.tar.gz && rm *.tar.gz && cd zfs* && ./configure && make -j $(nproc) && make install && ldconfig && modprobe zfs || echo -e "\e[31m\e[1mInstall failed, please fix manually!\e[0m"
