#!/bin/bash

disk=$1
serials=$2

# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/hddtest_smart.functions

nvme_worker "$@"
