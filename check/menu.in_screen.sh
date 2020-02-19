#!/bin/bash


#
# startet den hwcheck in einer neuen screen-session
#


PARAM="$1"
DIR=$(dirname $0)
HWCHECK="until false ; do $DIR/menu.sh $PARAM ; done"


# add note to motd
#
line1="\n\nHINWEIS:\n-------"
line2="hwcheck wurde nach dem booten in einer screen-session gestartet."
line3="Um sich mit der screen-session zu verbinden, 'screen -x' eingeben ...\n"
grep "$line2" /etc/motd >/dev/null || echo -e "$line1\n$line2\n$line3" >>/etc/motd


# wechsle zu tty8 nach kurzer zeit
#
#if [ "$(tty)" = "/dev/tty1" ] ; then
#  ( sleep 2 ; echo -e "\n\n => Wechsle zu Konsole 8  (ALT-F8)  ...\n" >/dev/tty1 ; sleep 1 ; chvt 8 ) & 
#  echo $(tty) >> /dev/tty8
#fi


# prepare screenrc
#
screenrc="/tmp/screenrc-$(basename $0)-$$"
cat <<EOF >$screenrc
zombie on
caption always "%{WB}%?%-Lw%?%{kw}%n*%f %t%?(%u)%?%{WB}%?%+Lw%?%{Wb}"
hardstatus alwayslastline "%{= RY}%H %{BW} %l %{bW} %c %M %d%="
    
EOF


# add screen windows and start screen
#
echo "screen -t hwcheck bash -c '$HWCHECK'" >> $screenrc
screen -mS "Hardware-Check" -c $screenrc
#rm $screenrc

