#!/bin/bash
. /root/.oldroot/nfs/check/hwb/lpt_led_functions

led_status running 1 &
led_status failed 0.2 &
