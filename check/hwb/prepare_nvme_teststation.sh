#!/bin/bash
source /root/.oldroot/nfs/check/hwb/nvme.function

PWD="$(dirname $0)"
. $PWD/../config
. $PWD/../report.function

ipmitool raw 0x06 0x52 0x03 0xc0 0x00 0x32 0xff
ipmitool raw 0x06 0x52 0x03 0xc2 0x00 0x32 0xff

for slot in 20 19 65 66 67 68 33 34 35 36 37 38; do
  led $slot off
done

hostnamectl set-hostname nvme_teststation

chvt 8

echo "Starting live status reporting"
ps c | grep periodic || /root/.oldroot/nfs/check/periodic_livesign.sh

echo "Creating status dir"
mkdir -p /run/hdd_test_status/{running,failed,finished}
mkdir /root/hwcheck-logs

echo "Moving udev-rule to /etc/udev/rules.d/"
cp /root/.oldroot/nfs/check/hwb/11-detect-nvme.rules /etc/udev/rules.d/
sleep 1
echo "Reloading udev-rules"
udevadm control --reload
systemctl restart udev

send2 reset
send2 pnp_test

echo "Launching Worker-Screen on tty8"
# add note to motd
#
line1="\n\nHINWEIS:\n-------"
line2="Plug'n'Play-NVMeSSDTest wurde in einer screen-session gestartet."
line3="Um sich mit der screen-session zu verbinden, 'screen -x' eingeben ...\n"
grep "$line2" /etc/motd >/dev/null || echo -e "$line1\n$line2\n$line3" >>/etc/motd
# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
cat <<EOF >$screenrc
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="
EOF
# add screen windows and start screen
#
sleep 5
echo "screen -t status bash -c 'echo \"Plug'n'Play-NVMeSSDTest ready...\" && cat'" >> $screenrc
screen -mS hwb_wipe_check -c $screenrc
