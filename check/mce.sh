#!/bin/bash

#
# this script checks the system for EDAC and MCE related errors
#
# tommy.giesler@hetzner.com


# read configuration files and extra functions
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function
. $PWD/mce.function

#
# logfile
ras_log_file="ras_mc_ctl.log"
edac_log_file="edac.log"
journal_log_file="journal_mce.log"
ras_error_log_file="ras_mc_ctl_errors.log"

#
# report test working
MCE_CHECK_ID="$(send2 mce-check working starting)"
# Subtests
MCE_SELFTEST_ID="$(send2 subtest "$MCE_CHECK_ID" MCE-SELFTEST working starting)"
RAM_CHECK_ID="$(send2 subtest "$MCE_CHECK_ID" RAM-CHECK working starting)"
MCE_JOURNAL_CHECK="$(send2 subtest "$MCE_CHECK_ID" MCE-JOURNAL-CHECK working starting)"
MCE_ERROR_CHECK="$(send2 subtest "$MCE_CHECK_ID" MCE-ERROR-CHECK working starting)"

# send abort status
#
trap "echo_red '\n\nSending ABORT to the monitor server ...\n' ; send mce_result 'ABORT' '-' '-' ; send2 update_status $TEST_ID "ABORTED" ; kill -9 $$" 1 2 9 15

echo_yellow "\n=====  MCE-Check TEST  =====\n"

ERRORMSG=""
STARTTIME="$(date +%H:%Mh)"
echo_grey "START: $STARTTIME"
send mce_result "WORKING" "Start $STARTTIME" "-"


# saving log outputs to variables
#
ras_mc_ctl_log="$(ras-mc-ctl --summary)"
edac_log="$(read_edac_mc)"
journal_mce_log="$(journalctl -t rasdaemon -t kernel | gzip -9 | base64 -w0)"
ras_mc_ctl_error_log="$(ras-mc-ctl --errors| gzip -9 | base64 -w0)"


echo -e "MCE-CHECK\n$(date)" >> $LOGDIR/mce.sh.tmp
  #
  # write errors into logfile and report to rzadmin
  echo "$ras_mc_ctl_log" > $LOGDIR/$ras_log_file
  send2 test_log_raw "$MCE_SELFTEST_ID" "ras_mc_ctl_log" "$LOGDIR/$ras_log_file" > /dev/null
  echo "$edac_log" > $LOGDIR/$edac_log_file
  send2 test_log_raw "$RAM_CHECK_ID" "edac_log" "$LOGDIR/$edac_log_file" > /dev/null
  echo "$journal_mce_log" > $LOGDIR/$journal_log_file
  send2 test_log_raw "$MCE_JOURNAL_CHECK" "journal_mce_log" "$LOGDIR/$journal_log_file" > /dev/null
  echo "$ras_mc_ctl_error_log" > $LOGDIR/$ras_error_log_file
  send2 test_log_raw "$MCE_ERROR_CHECK" "ras_mc_ctl_error_log" "$LOGDIR/$ras_error_log_file" > /dev/null

###
ENDTIME="$(date +%H:%Mh)"
echo_grey "END: $ENDTIME"

# Finish subtests
for test_id in "$MCE_SELFTEST_ID" "$RAM_CHECK_ID" "$MCE_JOURNAL_CHECK" "$MCE_ERROR_CHECK"; do
  send2 finished "$test_id" > /dev/null
done

result="$(send2 finished "$MCE_CHECK_ID")"
