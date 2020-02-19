#!/bin/bash

#
# this script runs apache benchmarks
#
# Sebastian.Nickel@hetzner.de - 2009.03.17


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

[ "$BENCHMARK_ALLOWED" = "no" ] && exit 0

# set apache benchmark params
REQUESTS="4000"
CONCURRENT="500"

start_server() {
  echo_white "installiere apache server auf IP $(get_ip)..."
  apt-get install -y apache2 
  echo ""
  read -n1 -p "Taste druecken um zurueck zum Menue zu kommen" FAKE
}

start_client() {
  
  echo_white "starte apache benchmark..."
  SERVER_IP=""
  while [ -z "$SERVER_IP" ]; do
    read -p "Auf welcher IP (oder Hostname) laeuft der apache server? " SERVER_IP
  done
  STARTTIME="$(date +%H:%Mh)"
  echo_grey "START: $STARTTIME"
  :> $LOGDIR/apache.temp  
  ab -n $REQUESTS -c $CONCURRENT http://$SERVER_IP/ | tee -a $LOGDIR/apache.temp 
  catch_error "Apache Benchmark brachte Fehler"
  
  ENDTIME="$(date +%H:%Mh)"
  echo_grey "END: $ENDTIME"
  
  #customize log data
  echo -e "Apache Benchmark\n" > $LOGDIR/$LOGFILE
  grep "^Server Hostname" $LOGDIR/apache.temp >> $LOGDIR/$LOGFILE
  grep "^Time taken for tests:" $LOGDIR/apache.temp >> $LOGDIR/$LOGFILE 
  grep "^Requests per second:" $LOGDIR/apache.temp >> $LOGDIR/$LOGFILE
  egrep "^Time per request:.*all concurrent requests" $LOGDIR/apache.temp >> $LOGDIR/$LOGFILE
  echo "" >> $LOGDIR/$LOGFILE
  sed -ne '/Percentage of the requests/,$ p' $LOGDIR/apache.temp >> $LOGDIR/$LOGFILE

  rm -f $LOGDIR/apache.temp
  send_status "bm-apache-result"
  read -n1 -p "Beliebige Taste druecken" fake

}
  

# send abort status
#
trap "echo_red \"\n\nSending ABORT ...\n\" ; send benchmark-apache-result \"ABORT\" \"-\" \"-\" ; kill -9 $$" 1 2 9 15




while [ "$ANSWER" != "3" ]; do
  clear
  echo_yellow "\n=====  Apache Benchmark  =====\n"
  echo_white "1 .... installiere apache server
2 .... starte apache benchmark
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
