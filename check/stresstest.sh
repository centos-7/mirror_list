#!/bin/bash

#
# this script runs stress test
#
# Patrick.Tausch@hetzner.de - 2013.02.28

show_warning() {
  echo_red "===>  !WARNING!    !WARNING!    !WARNING!    !WARNING!  <==="
  echo_red "------------------------------------------------------------\n"
  echo_red "YOU ARE RUNNING THE STRESSTEST IN DESTRUCTIVE MODE!\n"
  echo_red "THIS WIPES YOUR DISKS!\n"
  sleep_dots 30 
}

with_hddtest() {
  if [ "$WITH_HDDTEST" == "hddtest" ] || [ "$WITH_HDDTEST" == "true" ]; then
    return 0
  else
    return 1
  fi
}

abort() {
  echo_red '\n\nABORTING ...\n' 1>&2
  sleep 1
}

check_parameter() {
  if [ -z "$DURATION" ]; then
    echo -e "wrong parameter\n"
    echo "Usage: stresstest.sh <duration> [ <true|false> <ro|rw> ]"
    echo "true|false = with hddtest before and after the stresstest"
    echo "ro|rw = stresstest in destructive mode (write on hdd) or not"
    exit
  fi
}

check_preconditions() {
  if [ "$(uname -m)" != "x86_64" ]; then
    echo "Sorry, stresstest is only available for 64 bit architecture."
    sleep 5;
    exit;
  fi
  if [ "$(stressapptest -h > /dev/null 2> /dev/null ; echo $?)" == "127" ]; then
    echo "Sorry, stresstest not available - please reboot rescue system."
    sleep 5;
    exit;
  fi
}

check_preconditions

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
STARTTIME="$(date +%H:%Mh)"
DURATION=$1
WITH_HDDTEST=$2 ; [ -z "$WITH_HDDTEST" ] && WITH_HDDTEST="hddtest" ;
mode=$3

if [ "$mode" == "rw" ]; then
  destructive_opt="--destructive"
  show_warning
else
  destructive_opt=""
fi

trap "abort ; kill -9 $$" 1 2 9 15
check_parameter

echo_yellow "\n=====  Stresstest  =====\n"
echo_grey "START: $STARTTIME"

###
### Rebuild Check
###

$PWD/rebuild_check.sh


###
### START HDDTEST FIRST
###
#if [ -z "$(cat $LOGDIR/test_error.log)" ]; then
  $PWD/hddtest_smart_v2.0.4.sh short "1"
#fi

exit 1
###
### START HDDWIPE
###

###
### catch logfiles of hddtest
###
#if [ -z "$(cat $LOGDIR/test_error.log)" ]; then
  $PWD/stresstest_catch_hddlog.sh stresstest-hddlog-first
#fi


###
### start Stressapptest
###
#if [ -z "$(cat $LOGDIR/test_error.log)" ]; then
  echo $DURATION 
  read
  $PWD/stressapptest.sh $DURATION rw
#fi

###
### START HDDTEST LAST
###
#if [ -z "$(cat $LOGDIR/test_error.log)" ]; then
  $PWD/hddtest_smart_v2.0.4.sh short "2"
#fi

###
### catch logfiles of hddtest
###
#if [ -z "$(cat $LOGDIR/test_error.log)" ]; then
  $PWD/stresstest_catch_hddlog.sh stresstest-hddlog-last
#fi


###
### compare first and last logfile of hddtest
###
#if [ -z "$(cat $LOGDIR/test_error.log)" ]; then
  $PWD/stresstest_compare_hdd_values.sh
#fi

###
### DMESG Check
###


