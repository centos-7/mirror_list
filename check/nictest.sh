#!/bin/bash

#
# this script tests the NIC of this machine
#
# david.mayr@hetzner.de - 2007.08.06


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send nic_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15


echo_yellow "\n=====  NETWORK TEST  =====\n"


ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send nic_result "WORKING" "Start $STARTTIME" "-"


# create md5sum
#
echo_white "Creating MD5sum of  $PWD/$TESTFILE  ... "
md5sum $PWD/$TESTFILE | cut -d\  -f1 > /tmp/$(basename $TESTFILE).md5sum 2>> $LOGDIR/$LOGFILE


# compare md5sum
#
diff  $PWD/$TESTFILE.md5sum  /tmp/$(basename $TESTFILE).md5sum #>/dev/null
[ $? -ne 0 ] && ERROR=1
if [ "$ERROR" == "1" ]; then
  echo "nictest:error:nic:error at networkcard test"
  catch_error "Fehler beim Netzwerkkarten-Test" "ERROR"
fi



###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# evaluate ERRORMSG, eventually filled by catch_error()
#
send_status "nic_result"


