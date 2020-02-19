#!/bin/bash

#
# this script runs cpu benchmarks
#
# Sebastian.Nickel@hetzner.de - 2007.08.23


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

[ "$BENCHMARK_ALLOWED" = "no" ] && exit 0

# overwrite send status function to display custom message
#
send_status() {
  RESULTNAME=$1
  local MESSAGE="$2"
  LOGDATA="$(get_logdata)"
  if [ -z "$ERRORMSG" ] ; then
    echo_green "=====> OK  -  Sending status to monitor server ... "
    send $RESULTNAME "OK" "[$STARTTIME-$ENDTIME] $MESSAGE" "$LOGDATA"
  else
    echo_red "=====> ERROR  -  Sending status to monitor server ... "
    send $RESULTNAME "ERROR" "$ERRORMSG  [$STARTTIME-$ENDTIME]" "$LOGDATA"
  fi
}

# set cpu benchmark directory
BIN_DIR=$BM_DIR/byte
PBZIP_DIR=$BM_DIR/pbzip2
DATA_DIR="/root/.oldroot/nfs/check/data"

# send abort status
#
trap "echo_red '\n\nSending ABORT ...\n' ; send benchmark-cpu-result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  CPU Benchmark  =====\n"

STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send bm-cpu-result "WAIT" "[$STARTTIME]" "-"

#start cpu benchmark
echo_white "Starting CPU Benchmark\n"
cd $BIN_DIR
$BIN_DIR/Run speed 2>&1 | $LOG 
catch_error "CPU Benchmark beendete mit Fehler"

# edit logfile to display only important things
sed -ie '1,/====*/ d' $LOGDIR/$LOGFILE

# do some compressing and measure time
echo -e "\nCompressing a 500MB file (bzip2) with possible multicores...\n" | $LOG
echo -e "\nCreating 500MB File" | $LOG

dd if=/dev/urandom of=/tmp/test.dat bs=1M count=500 2>&1 >/dev/null

# time redirects to stderr, so spwan a new shell and redirect to stdout
if [ -e /tmp/test.dat ]; then
  duration=$(bash 2>&1 -c "time $PBZIP_DIR/pbzip2 -c /tmp/test.dat  > /dev/null")
  catch_error "Komprimierung beendete mit Fehler"

  echo -n "Used time: " | $LOG 
  # only show real time
  real=$(echo $duration | cut -d' ' -f2)

  echo $real | $LOG
  
  
  rm -f /tmp/test.dat

  ENDTIME="$(date +%H:%Mh)"
  echo_grey "END: $ENDTIME"

else
  ERRORMSG="Konnte Testfile nicht anlegen...exit"
fi

#find out index and display it
index=$(sed -ne '/AVERAGE/ s/\s*AVERAGE\s*//g p' $LOGDIR/$LOGFILE)
send_status "bm-cpu-result" "Index: $index BZIP-TIME: $real"
