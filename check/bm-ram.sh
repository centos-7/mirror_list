#!/bin/bash

#
# this script runs cpu benchmarks
#
# Sebastian.Nickel@hetzner.de - 2009.03.09


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

[ "$BENCHMARK_ALLOWED" = "no" ] && exit 0

# set ram benchmark directory
BIN_DIR=$BM_DIR/ramspeed

#set how often the test will be repeated
TEST_COUNT=3

# send abort status
#
trap "echo_red '\n\nSending ABORT ...\n' ; send benchmark-ram-result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  RAM Benchmark  =====\n"

STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send bm-ram-result "WAIT" "[$STARTTIME]" "-"

#start ram benchmark
echo_white "Starting RAM Benchmark\n"
cd $BIN_DIR

# check how many processes we can spawn and spawn them

CPU_COUNT=$(grep -c ^processor /proc/cpuinfo)
if [ $CPU_COUNT -gt 1 ]; then
  for i in 3 6 9 12; do
    $BIN_DIR/ramsmp -b $i -l $TEST_COUNT -p $CPU_COUNT 2>&1 | $LOG
  done
else
  for i in 3 6 9 12; do
    $BIN_DIR/ramspeed -b $i -l $TEST_COUNT 2>&1 | $LOG
  done
fi
catch_error "CPU Integer Benchmark beendete mit Fehler"

if [ -n "$ERRORMSG" ]; then
  send_status "bm-ram-result" && exit
fi

# customize output for better reading
sed -ne '/BatchRun/ p' $LOGDIR/$LOGFILE > $LOGDIR/bm-ram.temp
sed -ine '/AVERAGE/ s/$/\n/' $LOGDIR/bm-ram.temp
mv $LOGDIR/bm-ram.temp $LOGDIR/$LOGFILE

ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

send_status "bm-ram-result"
