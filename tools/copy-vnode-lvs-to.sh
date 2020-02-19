#!/bin/bash

#
#
# copy all LVM LVs matching a specific pattern to another machine
#
#


# setting and definitions
#
self="$(basename $0)"
date="$(date +%Y.%m.%d\ %H:%M.%S)"
ip="$(ifconfig eth0 | head -n2 | tail -n1 | tr -s " " | cut -d " " -f3 | cut -d: -f2)"

ssh="ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no -p222"


# param check
#
host="$1"
if [ -z "$host" ] ; then
  echo -e "\nUSAGE: $self <destination>"
  echo -e "where <destination> is something like 192.168.99.1 or e.g. node5\n"
  exit 1
fi
if ! ping -q -c1 -w1 $host >/dev/null ; then
  echo "Cannot ping $host - Abort."
  exit 2
fi

apt-get -y install mbuffer

# ssh public key check
#
if [ ! -f /root/.ssh/id_rsa.pub ] ; then
  echo "No ssh key found in /root/.ssh/ - running ssh-keygen..."
  ssh-keygen
fi
#
until $ssh $host true ; do
  echo -e "\n\nAppend this ssh public key to /root/.ssh/authorized_keys at the destination host:\n"
  echo -e "$(cat /root/.ssh/id_rsa.pub) [$self on $ip at $date]"
  echo -en "\nPress ENTER after this is done..."
  read
  echo
done


# local IP check
#
ipeth1="ifconfig eth1 | grep -qi 'inet ad'"
if [ "$ipeth1" ] ; then
  echo "IP on eth1 already configured: $ipeth1"
else
  echo -n "No IP configured on eth1 - will do now. Enter internal node ID: [1-29] "
  read internalnodeid
  if [ -n "$internalnodeid" -a $internalnodeid -gt 0 -a $internalnodeid -lt 30 ] ; then
    ifconfig eth1 192.168.99.$internalnodeid netmask 255.255.255.0
    echo "IP on eth1 configured."
  else
    echo "wrong internalnodeid - abort"
  fi
fi

# list LVs
#
lvlist="$(LC_ALL=C lvs --all --unbuffered --noheadings --separator : | tr -s " " | sed "s/^ //" | egrep ^[0-9]+:)"
lvs="$(echo "$lvlist" | cut -d: -f1)"
lvs=""
for lvdata in $lvlist ; do
  lv="$(echo $lvdata | cut -d: -f1)"
  vg="$(echo $lvdata | cut -d: -f2)"
  size="$(echo $lvdata | cut -d: -f4)"
  lvs="$lvs $lv"
  sizes[$lv]="$size"
  vgs[$lv]="$vg"
done
echo -e "The following LVs will be copied:\n$lvlist\n"
echo -en "\nPress ENTER if this is OK, enter 'ask' to ask for each LV individually before copying..."
read ask


# create LVs on new host and doing the actual copy of data
#
echo -e "\nCreating and copying LVs on destination host ..."
for lv in $lvs ; do

  # ask for each lv?
  if [ "$ask" = "ask" ] ; then
    echo -en "\n\nDo you want to to copy LV $lv (${sizes[$lv]}) to $host? [Y|n] "
    read -n1 answer
    [ "$answer" = "n" -o "$answer" = "N" ] && continue
  fi

  # do the work
  echo -e "\n\nCreate LV ======> $lv"
  if $ssh $host "lvcreate --name $lv --size ${sizes[$lv]} ${vgs[$lv]}" ; then
    echo -e "\nCopy LV  $lv  (${sizes[$lv]}) - please be patient:"
    dev="/dev/${vgs[$lv]}/$lv"
    pvcmd="pv -ptrbe -s $(echo ${sizes[$lv]} | sed s/\.00//)"
    mbuffer="mbuffer -q -f -m256M -s16M -b16 -r120M -R120M -u15000"
    dd bs=16M status=noxfer if=$dev 2>/dev/null | $mbuffer 2>/dev/null | $pvcmd | ssh -p222 -carcfour $host "$mbuffer 2>/dev/null | dd bs=16M status=noxfer of=$dev 2>/dev/null"
    echo -e "Done - run something like this in the virtapi console NOW to start VM on new host:"
    int_id="$(echo $host | cut -d. -f4)"
    echo -e "  d = Disk.find( $lv ).domain  ;  n = Node.find_by_name( \"$int_id.#{d.pool.id}\" )"
    echo -e "  d.update_attribute( :node, n ) ; d.define ; d.firewall(:reset) ; d.start ; sleep 1 ; d.state\n"
  else
    echo "Error while creating LV - maybe already existing. Skipping LV $lv ..."
  fi

done
echo

