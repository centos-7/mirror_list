#!/bin/bash

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
STARTTIME="$(date +%H:%Mh)"
STARTTIME_LOG="$(date)"

ARGS=`getopt -o --long ignore-error -- "$@"`

#Bad arguments
if [ $? -ne 0 ]; then
    exit 1
fi

# A little magic
eval set -- "$ARGS"

while true; do
  case "$1" in
    ignore-error)
       IGNORE_ERROR=true
       shift
       ;;
    --) shift ; break ;;
    *) echo "Internal error!" ; exit 1 ;;
  esac
done

#
# if another test is failed exit
if ( [ -z $IGNORE_ERROR ] && [ -f $LOGDIR/test_error.log ] && [ -n "$(cat $LOGDIR/test_error.log)" ] ) && [ "$(cat $LOGDIR/test_error.log | grep HDDTEST1)" ]; then
  echo "another test is failed exit"
  exit 1
fi


  #
  # check hdd values
  SMART_VALUE_ERROR='OK'
  for logfile in $(find $LOGDIR/ -name "stresstest-hddlog-first*"); do
    [[ $logfile =~ stresstest-hddlog-first-([^.]*)\. ]]
    SERIAL="${BASH_REMATCH[1]}"

    #SERIAL=$(echo "$logfile" | cut -d/ -f4 | cut -d- -f4 | cut -d. -f1)
    #LOGFILE_DIFF="$(diff $LOGDIR/stresstest-hddlog-first-$SERIAL.log $LOGDIR/stresstest-hddlog-last-$SERIAL.log)"

    SMART_FIRST="$(cat $LOGDIR/stresstest-hddlog-first-$SERIAL.log | awk '/ID/,/Logical/')" 
    SMART_LAST="$(cat $LOGDIR/stresstest-hddlog-last-$SERIAL.log | awk '/ID/,/Logical/')"

    echo -e "\n\nHDD_SERIAL: $SERIAL\n" >> $LOGDIR/stresstest-smart-value-tmp.log
    printf "%-31s\t%-10s\t%-10s\t%-5s\n" "SMART-VALUE-NAME" "HDDTEST-1" "HDDTEST-2" "RESULT" >> $LOGDIR/stresstest-smart-value-tmp.log
    echo "---------------------------------------------------------------------" >> $LOGDIR/stresstest-smart-value-tmp.log

    while read line; do 
      SMART_NAME="$(echo $line | awk '{print $2}')" 
      SMART_VALUE_FIRST="$(echo $line | awk '{print $3}')" 
      SMART_VALUE_LAST="$(echo "$SMART_LAST" | grep $SMART_NAME | awk '{print $3}')"
      SMART_VALUE_COMPARE=""
      if [ "$SMART_NAME" != "NAME" ]; then
        if [ -z "$SMART_VALUE_LAST" ] && [ -z "$SMART_VALUE_FIRST" ]; then
          SMART_VALUE_COMPARE="" 
        elif [ -z "$SMART_VALUE_LAST" ]; then
          SMART_VALUE_COMPARE="ERROR"
          SMART_VALUE_ERROR="ERROR"
        elif [ "$SMART_VALUE_LAST" -eq "$SMART_VALUE_FIRST" ]; then 
          SMART_VALUE_COMPARE="OK"
        elif [ "$SMART_VALUE_LAST" -gt "$SMART_VALUE_FIRST" ]; then 
          SMART_VALUE_COMPARE="ERROR"
          SMART_VALUE_ERROR="ERROR"
        elif [ -z "$SMART_VALUE_LAST" ] || [ -z "$SMART_VALUE_FIRST" ]; then
          SMART_VALUE_COMPARE="ERROR"
          SMART_VALUE_ERROR="ERROR"
        fi
        printf "%-31s\t%-10s\t%-10s\t%-5s\n" "$SMART_NAME" "$SMART_VALUE_FIRST" "$SMART_VALUE_LAST" "$SMART_VALUE_COMPARE" >> $LOGDIR/stresstest-smart-value-tmp.log
      fi
    done <<< "$SMART_FIRST"
    echo "---------------------------------------------------------------------" >> $LOGDIR/stresstest-smart-value-tmp.log
  done
  # save SMART_VALUE_ERROR

  echo -e "HDD-VALUE-COMPARE\n$STARTTIME_LOG\n\n" >> $LOGDIR/stresstest-smart-value.log

  if [ "$SMART_VALUE_ERROR" = "ERROR" ]; then
    echo -e "HDD-Value-Check: Errors detected - Values increasing between the tests" >> $LOGDIR/test_error.log
  fi

  echo "HDD-Value-Check: $SMART_VALUE_ERROR" >> $LOGDIR/stresstest-smart-value.log
  if [ "$SMART_VALUE_ERROR" = "ERROR" ]; then
    echo "HDD-Value-Check: Errors detected - Values increasing between the tests" >> $LOGDIR/stresstest-smart-value.log
  else
    echo "No differences between HDDTest1 and HDDTest2 found." >> $LOGDIR/stresstest-smart-value.log
  fi

  echo -n "###################### HDD-SMART-VALUE-DETAILS #####################" >> $LOGDIR/stresstest-smart-value.log
  cat $LOGDIR/stresstest-smart-value-tmp.log >> $LOGDIR/stresstest-smart-value.log
