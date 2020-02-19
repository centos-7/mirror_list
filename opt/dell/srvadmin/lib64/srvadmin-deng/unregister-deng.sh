#!/bin/bash

######################################################
# Remove Ndx,snmp registration with the Data Engine.
######################################################
/opt/dell/srvadmin/sbin/dcecfg command=removedareg prefix=de
/opt/dell/srvadmin/sbin/dcecfg command=disablesnmp

# unregister the control script
. /opt/dell/srvadmin/lib64/srvadmin-omilcore/Funcs.sh
UnInstallInitScript dataeng
