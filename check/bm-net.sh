#!/bin/bash

#
# this script runs net benchmarks
#
# Sebastian.Nickel@hetzner.de - 2009.03.11


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

[ "$BENCHMARK_ALLOWED" = "no" ] && exit 0

# set cpu benchmark directory
BIN_DIR=$BM_DIR/iperf

# shows if we are in client or server mode
MODE=""

start_server() {
  MODE="server"
  echo ""
  echo_white "starting iperf server auf IP $(get_ip)..."
  $BIN_DIR/iperf -s -B $(get_ip)
}

start_client() {
  
  MODE="client"
  echo_white "starting iperf client..."
  SERVER_IP=""
  while [ -z "$SERVER_IP" ]; do
    read -p "Auf welcher IP (oder Hostname) läuft der iperf server? " SERVER_IP
  done
  STARTTIME="$(date +%H:%Mh)"
  echo_grey "START: $STARTTIME"
  send bm-net-result "WAIT" "[$STARTTIME]" "-"
  
  for i in 1 2 3; do
    echo "Starting Benchmark Nr. $i" | $LOG
    echo "" | $LOG
    $BIN_DIR/iperf -c $SERVER_IP -t 30 | $LOG
    echo "" | $LOG
  done
  ENDTIME="$(date +%H:%Mh)"
  echo_grey "END: $ENDTIME"
  
  #customize log data
  sed -ine '/^-----/,/[ID]/ d' $LOGDIR/$LOGFILE 


  catch_error "NET Benchmark beendete mit Fehler"
  send_status "bm-net-result"
  read -n1 -p "Beliebige Taste druecken" fake

}
  

# send abort status
#
trap "[ \"$MODE\" = \"client\" ] && ( echo_red \"\n\nSending ABORT ...\n\" ; send benchmark-net-result \"ABORT\" \"-\" \"-\" ; kill -9 $$)" 1 2 9 15




while [ "$ANSWER" != "3" ]; do
  clear
  echo_yellow "\n=====  NET Benchmark  =====\n"
  echo_white "1 .... start iperf server
2 .... start iperf client
3 .... exit to main menu"
 read -n1 -p "Bitte wählen: " ANSWER
 clear
 case "$ANSWER" in
   1)
     start_server
   ;;
   2)
     start_client
   ;;
   3)
     exit 0
   ;;
 esac
done
