if ! echo ${PATH} | /bin/grep -q /opt/dell/srvadmin/bin ; then
	PATH=${PATH}:/opt/dell/srvadmin/bin
fi
if ! echo ${PATH} | /bin/grep -q /opt/dell/srvadmin/sbin ; then
	if [ `/usr/bin/id -u` = 0 ] ; then
		PATH=${PATH}:/opt/dell/srvadmin/sbin
	fi
fi
