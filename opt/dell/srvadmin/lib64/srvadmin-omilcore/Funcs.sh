#!/usr/bin/env bash

[ -n "${OMIDEBUG}" ] && set -x
umask 077
PATH=/sbin:/bin:/usr/sbin:/usr/bin

##
## Retrieve the value from a filename and registry key
##
GetRegVal() {
  FILE="${1}"
  KEY="${2}"

  [ ! -f "${FILE}" ] && echo "" && return 1

  GetVal "`grep -i "^[[:space:]]*${KEY}[[:space:]]*=" ${FILE}`"
  return 0
}


##
## Retrieve the value portion from a key=value pair
##
GetVal() {
  PAIR="${1}"

  echo "${PAIR}" | sed 's#^[^=]*=##; s#^[[:space:]]*##; s#[[:space:]]*$##'
}


##
## Execute proper command to install an init script
##
InstallInitScript()
{
    INIT_SCRIPT_NAME="${1}"	
    if [ -x /sbin/chkconfig ];
    then
        # this is a Red Hat type install
        /sbin/chkconfig --add ${INIT_SCRIPT_NAME}
    # check for lsb install
    elif [ -x /usr/lib/lsb/install_initd ];
    then
        # this is an lsb install
        /usr/lib/lsb/install_initd /etc/init.d/${INIT_SCRIPT_NAME} >/dev/null 2>&1
    elif [ -x /usr/sbin/update-rc.d ];
    then
        # Debian/Ubuntu install
        if [ -x /etc/init.d/${INIT_SCRIPT_NAME} ];
        then
            /usr/sbin/update-rc.d ${INIT_SCRIPT_NAME} defaults
        fi
    fi
    return 0
}

##
## Execute proper command to delete an init script
##
UnInstallInitScript()
{
    INIT_SCRIPT_NAME="${1}"
    if [ -x /etc/init.d/${INIT_SCRIPT_NAME} ]; then
        /etc/init.d/${INIT_SCRIPT_NAME} stop
    fi
    if [ -x /usr/lib/lsb/remove_initd ]; then
         /usr/lib/lsb/remove_initd /etc/init.d/${INIT_SCRIPT_NAME} >/dev/null 2>&1
    elif [ -x /sbin/chkconfig ]; then
        /sbin/chkconfig --del ${INIT_SCRIPT_NAME}
    elif [ -x /usr/sbin/update-rc.d ]; then
        # Debian/Ubuntu uninstall
        if [ -x /etc/init.d/${INIT_SCRIPT_NAME} ];
        then
            /usr/sbin/update-rc.d -f ${INIT_SCRIPT_NAME} remove
        fi
    fi
    return 0
}

## Execute the smbios-sys-info-lite utility
## return system id
GetSysId() {
    if [ -z "$OM_SYSTEM_ID" ]; then
        # execute system id utility if no override
        OM_SYSTEM_ID=$(/usr/sbin/smbios-sys-info-lite | grep "^System ID" | sed 's#^.*0x##; s#[[:space:]].*$##')		
    fi
    echo ${OM_SYSTEM_ID}
    [ -n "${OM_SYSTEM_ID}" ] || return 1
    return 0
}




if [ "$1" = "test" ]; then
    GetSysId
fi

##
## Retrieve the key portion from a key=value pair
##
GetKey() {
  PAIR="${1}"

  echo "${PAIR}" | sed 's#=.*$##; s#^[[:space:]]*##; s#[[:space:]]*$##'
}

##
## returns a safe temporary filename (respecting any $TMP directory given)
##
GetTemp() {
  GETTEMPFILE=`mktemp ${TMP:-/var/tmp}/ominstall.XXXXXXX`
  [ $? -ne 0 ] && ErrorMsg "error: cannot create temp file, exiting..." && exit 1
  chmod 600 ${GETTEMPFILE} && chown root.root ${GETTEMPFILE}
  echo "${GETTEMPFILE}"
  return 0
}


MakeFile() {
  MAKEFILE="${1}"
  [ ! -f "${MAKEFILE}" ] && touch ${MAKEFILE} && chmod 664 ${MAKEFILE} && chown root.root ${MAKEFILE}
}


CheckRACInstall() {
    FILE="${1}"
    OMREG_SYSIDCHECKUTIL_KEY="${2}"
    OMREG_SYSLISTFILE_KEY="${3}"
    PACKAGE_NAME="${4}"
    OPTION="${5}"
    OMREG_8GSYSLISTFILE_KEY="${6}"
    OMREG_9GSYSLISTFILE_KEY="${7}"
    OMREG_IDRAC_SYSLISTFILE_KEY="${8}"

    # check SYSID to be ignored, then return success now!
    [ -n "${OMIIGNORESYSID}" ] && return 0

    SYSIDFILEPATH=`GetRegVal "${FILE}" "${OMREG_SYSLISTFILE_KEY}"`

    #Allow DRAC3 installs on Non-8G systems, Block DRAC3 installs on 8G and 9G systems
    #Allow DRAC4 installs on 8G systems, Block DRAC4 installs on Non-8G systems
    #Allow DRAC5 installs on 9G systems, Block DRAC5 installs on Non-9G systems
    #Allow iDRAC installs on 11G systems, Block iDRAC installs on Pre-11G systems

    if [ -n "${OPTION}" ];
    then
        SYSIDFILEPATH8G=`GetRegVal "${FILE}" "${OMREG_8GSYSLISTFILE_KEY}"`
        SYSIDFILEPATH9G=`GetRegVal "${FILE}" "${OMREG_9GSYSLISTFILE_KEY}"`

        if [ "${OPTION}" == "DRAC4" ];
        then
            #Allow DRAC4 installs on 8G systems, Block DRAC4 installs on Non-8G systems
            SYSID=`GetSysId` 
            VAL=`GetRegVal "${SYSIDFILEPATH8G}" "${SYSID}"`

           if [ -z "${VAL}" ]; 
           then
             if [ ${SYSID} != "023C" ]; 
             then
               return 1
             fi
           else
               return 0
	   fi
        elif [ "${OPTION}" == "DRAC5" ];
        then
      #Allow DRAC5 installs on 9G systems, Block DRAC5 insalls on Non-9G systems
           SYSID=`GetSysId` 
           VAL=`GetRegVal "${SYSIDFILEPATH9G}" "${SYSID}"`
            if [ -z "${VAL}" ] 
            then 
              return 1
            else
              return 0
	    fi

        elif [ "${OPTION}" == "IDRAC" ];
        then
            #Allow iDRAC installs on 11G systems, Block iDRAC installs on Pre-11G systems
            SYSID=`GetSysId` 
            SYSID_HEX="0x$SYSID"
            SYSID_DEC=`printf "%d" $SYSID_HEX`

            MIN_IDRAC_SYSID_HEX=0x0235
            MIN_IDRAC_SYSID_DEC=`printf "%d" $MIN_IDRAC_SYSID_HEX`

          if [ $SYSID_DEC -ge $MIN_IDRAC_SYSID_DEC ]; then
          # system is iDRAC 
            TEST8G=`GetRegVal "${SYSIDFILEPATH8G}" "${SYSID}"`
            TEST9G=`GetRegVal "${SYSIDFILEPATH9G}" "${SYSID}"`
              
            if [ -z $TEST8G ] && [ -z $TEST9G ]
            then
              return 0
            else  
              return 1 
	    fi
          fi
       fi
    fi
    return 1
}


##
## Update a file with a key=value pair.
## adds the pair if it doesnt exist
## if the key already exists, append the value to the end of already existing 
## values (with blank space in between)
## updates the value with the current registry prefix if provided
##
UpdateRegSvcList() {
  FILE="${1}"
  PREFIX="${2}"
  shift
  shift

  svc_present="FALSE"

  # if the file doesnt exist, create it
  MakeFile "${FILE}"

  for PAIR in ${*} ;
  do
    TMP_KEY=`GetKey "${PAIR}"`
    TMP_VAL=`GetVal "${PAIR}"`

    if [ -n "${TMP_VAL}" -a -n "${PREFIX}" ];
    then
        NEW_VALUE="${PREFIX}/${TMP_VAL}"
    else
        NEW_VALUE="${PREFIX}${TMP_VAL}"
    fi

    #Check whether the service is already in the list.
    #If already present, do nothing.
    grep -qi "^[[:space:]]*${TMP_KEY}[[:space:]]*=" ${FILE}
    key_present=$?
    if [[ $key_present == 0 ]]; then

       pattern=`grep -i "^[[:space:]]*${TMP_KEY}[[:space:]]*=" ${FILE}`
       ret=`echo $pattern | awk -F"=" '{print $2}'`
       echo " $ret " | grep -qi " ${NEW_VALUE} "

       if [[ $? == 0 ]]; then
          svc_present="TRUE"
       fi
    fi

    if [[ $svc_present == "FALSE" ]]; then
       # strip old from the regentry, then add new
       TEMPFILE=`GetTemp`

       grep -iv "^[[:space:]]*${TMP_KEY}[[:space:]]*=" ${FILE} > ${TEMPFILE}
       if [[ $key_present == 0 ]]; then
           echo "`grep -i "^[[:space:]]*${TMP_KEY}[[:space:]]*=" ${FILE}` $NEW_VALUE" >> ${TEMPFILE} &&
           sort ${TEMPFILE} > ${FILE} ||
           ErrorMsg "unable to update ${FILE}"
       else
           echo "${TMP_KEY}=${NEW_VALUE}" >> ${TEMPFILE} &&
           sort ${TEMPFILE} > ${FILE} ||
           ErrorMsg "unable to update ${FILE}"
       fi

       rm -f ${TEMPFILE}
    fi

  done
  return 0
}


##
## Remove a service from the list of registry services.
## Example : RemoveRegSvc "/tmp/omreg.cfg" "upgrade.relocation=svc1"
## This removes the service "svc1" from the list of services.
## If no more services exist, the key also will be removed from the registry.
## if the file is empty after the deletion, the file is removed as well.
##
RemoveRegSvc() {
  FILE="${1}"
  shift

  [ ! -f "${FILE}" ] && return 0

  for PAIR in ${*} ;
  do
    TMP_KEY=`GetKey "${PAIR}"`
    TMP_VAL=`GetVal "${PAIR}"`

    # strip old from the regentry
    TEMPFILE=`GetTemp`
    grep -iv "^[[:space:]]*${TMP_KEY}[[:space:]]*=" ${FILE} > ${TEMPFILE}

    #Strip off $TMP_VAL from the service list
    New_SvcList=`grep -i "^[[:space:]]*${TMP_KEY}[[:space:]]*=" ${FILE} | awk -F"=" '{print $2}' | \
                       sed -e "s/ $TMP_VAL / /g" -e "s/^$TMP_VAL //g" -e "s/ $TMP_VAL$//g" \
                           -e "s/^$TMP_VAL$//g" -e 's/^[[:space:]]*//;s/[[:space:]]*$//'`

    if [[ -n $New_SvcList ]]; then
       echo "${TMP_KEY}=${New_SvcList}" >> ${TEMPFILE} 
    fi

    sort ${TEMPFILE} > ${FILE} ||
        ErrorMsg "unable to update ${FILE}"
    rm -f ${TEMPFILE}
  done

  # if now empty, remove the file
  [ ! -s "${FILE}" ] && rm -f ${FILE}
  return 0
}

