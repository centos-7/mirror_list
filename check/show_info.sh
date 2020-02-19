#!/bin/bash

#
# this script shows some hardware info
#
# david.mayr@hetzner.de - 2007.08.15


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


echo_yellow "\n=====  Hardware info  =====\n"

echo_green "\nCPU:"
echo_white "$(get_cpu)"

echo_green "\nRAM:"
echo_white "$(get_ram)"

echo_green "\nHDD:"
echo_white "$(get_hdd)"

echo_green "\nRAID:"
if $(get_raid >/dev/null) ; then
  echo_white "$(get_raid)"
else
  echo_white "- no raid -"
fi

