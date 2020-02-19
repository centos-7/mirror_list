#!/bin/bash

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config

if [ -f $LOGDIR/rebuild_check.sh ]; then
  if [ "$(cat $LOGDIR/test_error.log | grep -i rebuild)" ]; then
    echo "Rebuild Check: ERROR (rebuild is running)" >> $LOGDIR/summary.log
  else
    echo "Reubild Check: OK" >> $LOGDIR/summary.log
  fi
fi


if [ "$(ls $LOGDIR | grep stresstest-hddlog-first)" ]; then
  if [ "$(cat $LOGDIR/test_error.log | grep -i HDDTEST1)" ]; then
    echo "HDDTEST 1: ERROR" >> $LOGDIR/summary.log
  else
    echo "HDDTEST 1: OK" >> $LOGDIR/summary.log
  fi
fi

if [ -f $LOGDIR/stressapptest.log ]; then
  if [ "$(cat $LOGDIR/test_error.log | grep -i Stresstest)" ]; then
    echo "Stresstest: ERROR" >> $LOGDIR/summary.log
  else
    echo "Stresstest: OK" >> $LOGDIR/summary.log
  fi
fi

if [ -f $LOGDIR/stressapptest.log ]; then
  if [ "$(cat $LOGDIR/test_error.log | grep -i Temperatur)" ]; then
    TEST_STATUS="$(cat $LOGDIR/test_error.log | grep -i Temperatur | grep -Eo '(WARNING|ERROR)')"
    echo "Core Temperatur: $TEST_STATUS" >> $LOGDIR/summary.log
  else
    echo "Core Temperatur: OK" >> $LOGDIR/summary.log
  fi
fi

if [ "$(ls $LOGDIR | grep stresstest-hddlog-first)" ]; then
  if [ "$(cat $LOGDIR/test_error.log | grep -i HDDTEST2)" ]; then
    echo "HDDTEST 2: ERROR" >> $LOGDIR/summary.log
  else
    echo "HDDTEST 2: OK" >> $LOGDIR/summary.log
  fi
fi

if [ -f $LOGDIR/stresstest_compare_hdd_values.sh ]; then
  if [ "$(cat $LOGDIR/test_error.log | grep -i HDD-Value )" ]; then
    echo "HDDTEST-Value-Compare: ERROR" >> $LOGDIR/summary.log
  else
    echo "HDDTEST-Value-Compare: OK" >> $LOGDIR/summary.log
  fi
fi

