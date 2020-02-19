#!/bin/bash

#
# catch the hddtest logfiles and rename it on input parameters
#
# parameters
#  $1 rename pattern

# read in configuration file
#
 PWD="$(dirname $0)"
 . $PWD/config
 STARTTIME="$(date +%H:%Mh)"

for logfile in $(find $LOGDIR/ -name "hddtest-*"); do
  #filename=$(basename "$file")
  #
  ##
  ## remove extention
  #tmp="${filename%.*}"
  #
  ##
  ## remove hddtest
  ##SERIAL=$(echo "$logfile" | cut -d/ -f4 | cut -d- -f2 | cut -d. -f1)
  #SERIAL="${filename#hddtest-}"

  [[ $logfile =~ hddtest-([^.]*)\. ]]
  SERIAL=${BASH_REMATCH[1]}

  mv $logfile /root/hwcheck-logs/$1-$SERIAL.log
done
