#!/bin/bash

#
# this script generates a testfile for the nictest.
# it is not intended to be run on the computer to tested,
# but once on the test-server.
#
# david.mayr@hetzner.de - 2007.08.08
#



# use first parameter as testfile-size or use default
#
if [ -z "$1" ] ; then
  size="1024"
else
  size="$1"
fi
filename="data/TESTFILE_$size""M"



# create testfile
#
dd bs=1M count=$size if=/dev/urandom of=$filename



# create md5sum
#
md5sum $filename | cut -d\  -f1 > $filename.md5sum



