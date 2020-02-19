#!/bin/bash
# find and wipe USB sticks, in a screen session
# 16.10.2018 10:10 jukka.lehto

USB=($(for devlink in /dev/disk/by-id/usb*; do readlink -f ${devlink}|grep '/dev/sd'|egrep -v 'sd..'; done))
[ -z $USB ] && exit
i=0
screenrc=/tmp/screenrc-$RANDOM-usb
cat <<EOF >$screenrc
## zombie on
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="
#
EOF

while [ "${USB[$i]}" != "" ]; do
  MD=${USB[$i]}
  i=$((++i))
  echo "screen -t \"USB $MD\" bash -c 'shred -fvzn2 $MD'" >> $screenrc
done

screen -mS "USB wipe" -c $screenrc
rm $screenrc
