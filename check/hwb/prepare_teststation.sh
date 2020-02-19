#!/bin/bash

PWD="$(dirname $0)"
. $PWD/../config
. $PWD/../report.function

sleep 5
pkill -f signal_status.sh
chvt 8

echo "Starting live status reporting"
ps c | grep periodic || /root/.oldroot/nfs/check/periodic_livesign.sh

echo "Creating status dir"
mkdir -p /run/hdd_test_status/{running,failed,finished}
mkdir /root/hwcheck-logs

echo "Moving udev-rule to /etc/udev/rules.d/"
cp /root/.oldroot/nfs/check/hwb/11-detect-hdd.rules /etc/udev/rules.d/
sleep 1
echo "Reloading udev-rules"
udevadm control --reload

echo "Preparing LEDs"
pport -s 2,3,4,5,6,7,8,9
sleep 2
pport -t 2,3,4,5,6,7,8,9
sleep 1
for i in {2..9}; do
  pport -t $i && sleep 0.1 && pport -t $i && sleep 0.1
done
sleep 1
/root/.oldroot/nfs/check/hwb/signal_status.sh

send2 pnp_test

echo "Launching Worker-Screen on tty8"
# add note to motd
#
line1="\n\nHINWEIS:\n-------"
line2="Plug'n'Play-HDDTest wurde in einer screen-session gestartet."
line3="Um sich mit der screen-session zu verbinden, 'screen -x' eingeben ...\n"
grep "$line2" /etc/motd >/dev/null || echo -e "$line1\n$line2\n$line3"
>>/etc/motd
# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
cat <<EOF >$screenrc
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="
EOF
# add screen windows and start screen
#
echo "screen -t status bash -c 'echo \"Plug'n'Play-HDDTest ready...\" && cat'" >> $screenrc
screen -mS hwb_wipe_check -c $screenrc
