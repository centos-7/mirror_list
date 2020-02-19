#!/usr/bin/env bash
###############################################################################
#
#          Dell Inc. PROPRIETARY INFORMATION
# This software is supplied under the terms of a license agreement or
# nondisclosure agreement with Dell Inc. and may not
# be copied or disclosed except in accordance with the terms of that
# agreement.
#
# Copyright (c) 2000-2009 Dell Inc. All Rights Reserved.
#
# Abstract/Purpose:
#
#   This Script will start/stop/restart/status all the services installed
#   by Systems Management.
#
###############################################################################
 
# ensure sbin utilities are available in path, so that su will also work
export PATH=/usr/kerberos/sbin:/usr/local/sbin:/sbin:/usr/sbin:$PATH
PATH="${PATH}:/sbin:/usr/sbin:/bin:/usr/bin"

# Server Administrator package prefix
SRVADMIN_STR="Server Administrator"

startDeps=(mptctl)

# list of services start
#dsm_om_shrsvc service is removed from list, will be added to list when service is enabled
arrayStart=(racsvc instsvcdrv dataeng dsm_om_connsvc racser racvnc racsrvc)

# list of services to stop
#dsm_om_shrsvc service is removed from list, will be added to list when service is enabled
arrayStop=(racsvc dsm_om_connsvc racser racvnc racsrvc dataeng instsvcdrv)

# list of services to find status
#dsm_om_shrsvc service is removed from list, will be added to list when service is enabled
arrayStatus=(racsvc instsvcdrv dataeng dsm_om_connsvc racser racvnc racsrvc)

#include DSM Shared services in start/stop/status array when DMS Shared service is enabled
checkDSMSharedService() {
result=1
if [ -x /sbin/chkconfig ]; then
    /sbin/chkconfig 2>/dev/null | grep dsm_om_shrsvc | grep on >/dev/null 2>&1
    result=$?
elif [ -x /usr/bin/systemctl ]; then
    # rhel/sles
    /usr/bin/systemctl is-enabled dsm_om_shrsvc >/dev/null 2>&1
    result=$?
elif [ -x /bin/systemctl ]; then
    # ubuntu
    /bin/systemctl is-enabled dsm_om_shrsvc >/dev/null 2>&1
    result=$?
fi

if [ $result -eq 0 ]; then
    arrayStart+=('dsm_om_shrsvc')
    arrayStop+=('dsm_om_shrsvc')
    arrayStatus+=('dsm_om_shrsvc')
fi
}

#
# start/stop/status for multiple services
#
serviceAction() {
    action=$1
    shift
    services=$@
    RET=0
    for svc in $services; do
        if [ -e /etc/init.d/$svc ]; then
            /etc/init.d/$svc $action
	    RET=$?
        fi
    done
    return $RET
}

#
# enable/disable multiple services
#
serviceCtl () {
    ctl=$1
    shift
    services=$@
    for svc in $services
    do
        chkconfig --list $svc 2>/dev/null || continue
        chkconfig $svc $ctl
    done
}

##
## Usage
##
function Usage {
    cat <<EOF
Usage: srvadmin-services.sh {start|stop|status|restart|enable|disable|help}
  start  : starts ${SRVADMIN_STR} services
  stop   : stops ${SRVADMIN_STR} services
  status : display status of ${SRVADMIN_STR} services
  restart: restart ${SRVADMIN_STR} services
  enable : Enable ${SRVADMIN_STR} services in runlevels 2, 3, 4, and 5
  disable: Disable ${SRVADMIN_STR} services in runlevels 2, 3, 4, and 5
  help   : Displays this help text
EOF
    exit 1
}

# make sure services dont busy out any mountpoints
cd /

# check for root privileges
if [ "${UID}" != "0" ]; then
    echo "This utility requires root privileges"
    exit 1
fi

action=$1
shift

checkDSMSharedService
# Note the ${@:- ... } set up this way so that we either stop/start/etc full
# set of services, or specific service if passed. ${@} is set to cmdline
# params. If these are not set, then the stuff after :- is used as a default.
if [ "${action}" == "start" ]; then
    serviceAction start ${@:-${startDeps[*]} ${arrayStart[*]}}

elif [ "${action}" == "stop" ]; then
    serviceAction stop ${@:-${arrayStop[*]}}

elif [ "${action}" == "status" ]; then
    serviceAction status ${@:-${arrayStatus[*]}}

elif [ "${action}" == "restart" ]; then
    serviceAction stop ${@:-${arrayStop[*]}}
    serviceAction start ${@:-${startDeps[*]} ${arrayStart[*]}}

elif [ "${action}" == "freeze" ]; then
    for service in ${@:-${startDeps[*]} ${arrayStart[*]}}; do
    	if serviceAction status $service; then
		touch /opt/dell/srvadmin/var/run/freeze-$service
    		serviceAction stop $service
	fi
    done

elif [ "${action}" == "thaw" ]; then
    for service in ${@:-${startDeps[*]} ${arrayStart[*]}}; do
	if [ -e /opt/dell/srvadmin/var/run/freeze-$service ]; then
		rm -f /opt/dell/srvadmin/var/run/freeze-$service
    		serviceAction start $service
	fi
    done

elif [ "${action}" == "condrestart" ]; then
    # condrestart will restart a service if it is running, else noop
    # used in rpm %post
    for service in ${@:-${startDeps[*]} ${arrayStart[*]}}; do
    	if serviceAction status $service; then
    		serviceAction stop $service
    		serviceAction start $service
	fi
    done

elif [ "${action}" == "enable" ]; then
    serviceCtl on ${@:-${arrayStatus[*]} ipmi}

elif [ "${action}" == "disable" ]; then
    serviceCtl off ${@:-${arrayStatus[*]} ipmi}

else
    [ -z "${action}" ] || echo -e "Invalid option '${action}', please see the usage below\n"
    Usage
fi

