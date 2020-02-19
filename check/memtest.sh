#!/bin/bash

#
# this script calls 'memtest' (from debian package 'memtester')
# with parameters 
#
# david.mayr@hetzner.de - 2007.08.06


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config


# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send ram_result 'ABORT' '-' '-' ; kill -9 $$" 1 2 9 15



echo_yellow "\n=====  MEMORY TEST  =====\n"

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send ram_result "WORKING" "Start $STARTTIME" "-"


# calculate how much memory (in MB) to test
# we need to leave enough memory free in order not to hit the lowmem_reserve
# limit for the various zone (DMA, DMA32, Normal or DMA, Normal, Highmem) see
# mm/page_alloc.c or Documentation/sysctl/vm.txt
# The actual calculations are a little bit more complex (default 1/32 pages for
# DMA, 1/256 for Normal/DMA32 and Highmem. This is approximate to about 1% of
# the memory
FREE="$( free -m | grep / | tr -s ' ' | cut -d\  -f4 )"
FREEMEM=$(echo "$FREE * 0.019" | bc -q | cut -d '.' -f1)

if [ $FREEMEM -lt $MEM_REMAIN ]; then
  TESTMEM=$(($FREE - $MEM_REMAIN))
else
  TESTMEM=$(($FREE - $FREEMEM))
fi

#TESTMEM="$(( $FREE - $MEM_REMAIN ))"
#
# use less memory on 24G servers
#[ $TESTMEM -gt 20000 ] && TESTMEM="$(( $TESTMEM - 100 ))"


# call memtester
#
echo_white "Run $MEMTESTCOUNT time(s) for $TESTMEM""MB of memory:\n"
memtester $TESTMEM $MEMTESTCOUNT  2>&1 | $LOG
if [ $? -ne 0 ]; then
  ERROR=1
else
  ERROR=0
fi
if [ "$ERROR" -eq 1 ]; then
  catch_error "Memtest beendete mit Fehler" "ERROR"
  echo "memtest:error:ram:memtest exit with error" >> $ROBOT_LOGFILE
fi



###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"



# eavluate ERRORMSG, eventually filled by catch_error()
#
send_status "ram_result"


