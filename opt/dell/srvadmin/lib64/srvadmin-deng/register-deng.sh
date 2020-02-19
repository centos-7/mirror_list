#!/bin/bash

# fixup omreg
cat /opt/dell/srvadmin/etc/omreg.d/*.cfg /etc/compat-omreg.cfg > /opt/dell/srvadmin/etc/omreg.cfg 2>/dev/null ||:

###############################################
# Configure and Register Data Engine components
###############################################

# Prepare file access
/opt/dell/srvadmin/sbin/dcecfg command=prepfileaccess dirpath=/opt/dell/srvadmin/etc/srvadmin-deng/ini
/opt/dell/srvadmin/sbin/dcecfg command=prepfileaccess dirpath=/opt/dell/srvadmin/etc/srvadmin-deng/ndx

#Register Ndx info
/opt/dell/srvadmin/sbin/dcecfg command=adddareg prefix=de product=OMDataEngine enable=true

#Enable SNMP support
/opt/dell/srvadmin/sbin/dcecfg command=enablesnmp

. /opt/dell/srvadmin/lib64/srvadmin-omilcore/Funcs.sh
InstallInitScript dataeng

exit 0
