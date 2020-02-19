#!/bin/sh

disable_beastie=0

while getopts ":b" opt; do
  case $opt in
    b)
      disable_beastie=1
      ;;
  esac
done

if [ $disable_beastie -eq 1 ] ; then
  # disable beastie
  sed -i "" '/^beastie_disable.*/d' /boot/loader.conf > /dev/null
  echo "beastie_disable=\"YES\"" >> /boot/loader.conf
fi

# patch sshd-config to allow root login
sed -i "" 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config > /dev/null

# update microcode
freebsd-update fetch >> /dev/null && freebsd-update install

exit 0
