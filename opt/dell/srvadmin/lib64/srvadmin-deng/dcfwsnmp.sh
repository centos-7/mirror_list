#!/usr/bin/env bash
###############################################################################
#
#          Dell Inc. PROPRIETARY INFORMATION
# This software is supplied under the terms of a license agreement or
# nondisclosure agreement with Dell Inc. and may not
# be copied or disclosed except in accordance with the terms of that
# agreement.
#
# Copyright (c) 2000-2011 Dell Inc. All Rights Reserved.
#
# Module Name:
#
#   dcfwsnmp.sh
#
# Abstract/Purpose:
#
#   Shell script to check firewall configuration to see if SNMP port is open
#
#   Return zero if SNMP port is open; else return non-zero
#
# Environment:
#
#   Linux
#
###############################################################################

PATH=/sbin:/usr/sbin:/bin:/usr/bin:${PATH}

IPCHAINS_MSG_OK="accepted"
WS="[ \t]*"

# See if SNMP agent was started with the port parameter (-p)
SNMP_PORT=`
ps -eo args |
egrep "snmpd${WS}-p${WS}[[:digit:]]+" |
sed 's/.*-p//' |
awk '{print $1}'`
if [ -z ${SNMP_PORT} ];
then
	SNMP_PORT=161
fi

# See if ipchains kernel module is loaded
ipchains -C input -s 0 0 -d 0 ${SNMP_PORT} -p udp -i lo >/dev/null 2>&1
if [ $? != 0 ];
then
	# ipchains appears to return zero if the ipchains kernel module is loaded
	# and non-zero if not loaded.  If the kernel module is not loaded, we
	# can't use the ipchains utility to check the SNMP port.  In that case,
	# we say the SNMP port is open because the kernel module must be loaded
	# for the firewall to work.  We don't want to cause the kernel module
	# to be loaded.
	exit 0
fi

# Get list of interfaces to check (except for local loopback)
INTERFACE_LIST=`ifconfig | egrep ".*Link encap" | egrep -v "lo" | awk '{print $1}'`
if [ ! -z "${INTERFACE_LIST}" ];
then
	# See if there's an interface that accepts data on SNMP port
	# from any source address
	for INTERFACE in ${INTERFACE_LIST}
	do
		# Note: ipchains returns zero for "accepted" and "rejected"
		ipchains -C input -s 0 0 -d 0 ${SNMP_PORT} -p udp -i ${INTERFACE} |
		grep -i ${IPCHAINS_MSG_OK} >/dev/null 2>&1
		if [ $? = 0 ];
		then
			# We found an interface that accepts data on SNMP port
			# from any source address
			exit 0
		fi
	done

	# Get list of specific source addresses to check (except for 0.0.0.0)
	SOURCE_ADDR_LIST=`
	ipchains -L input -n |
	egrep -i "^ACCEPT${WS}" |
	awk '{print $4}' |
	egrep -iv "^0.0.0.0"`
	if [ ! -z "${SOURCE_ADDR_LIST}"  ];
	then
		# See if there's an interface that accepts data on SNMP port
		# from any source address
		for SOURCE_ADDR in ${SOURCE_ADDR_LIST}
		do
			for INTERFACE in ${INTERFACE_LIST}
			do
				# Note: ipchains returns zero for "accepted" and "rejected"
				ipchains -C input -s ${SOURCE_ADDR} 0 -d 0 ${SNMP_PORT} -p udp -i ${INTERFACE} |
				grep -i ${IPCHAINS_MSG_OK} >/dev/null 2>&1
				if [ $? = 0 ];
				then
					# We found an interface that accepts data on SNMP port
					# from a specific address
					exit 0
				fi
			done
		done
	fi
fi

# It looks like the SNMP port is not open to the outside world
exit 1


###############################################################################
# End Script
###############################################################################

