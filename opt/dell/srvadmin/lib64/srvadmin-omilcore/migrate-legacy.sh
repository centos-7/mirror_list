#!/usr/bin/env bash

[ -z "$NO_LEGACY_MIGRATE" ] || exit 0

# this gets run multiple times during install, so we have to check each piece as we do it to skip it if we have already done it, or skip it if the new rpm hasnt yet been installed.

migrate_ini=/opt/dell/srvadmin/lib64/srvadmin-omilcore/migrate-ini-settings
migrate_nv=/opt/dell/srvadmin/lib64/srvadmin-omilcore/migrate-nv-settings
savebase=/opt/dell/srvadmin/lib64/srvadmin-omilcore/savedsettings

migrate_deng() {
    local savedir=$savebase/dataeng
    local newdir=/opt/dell/srvadmin/etc/srvadmin-deng/ini/

    [ -e $savedir ] || return 0
    [ -e $newdir/dcefdy32.ini ] || return 0

    for ini in dcefdy32.ini dcefst32.ini dcemst32.ini dcsmdy32.ini dcsmst32.ini dcsnst32.ini; do
        [ -e $savedir/$ini ] || continue
        $migrate_ini -i $savedir/$ini -o $newdir/$ini --merge-section=* --no-space-equal
    done
    
    # dcsndy32.ini is short-bus special. (mix programmatic and user settings... ugh)
    $migrate_ini -i $savedir/dcsndy32.ini -o $newdir/dcsndy32.ini --merge-section="MIB Manager" --no-space-equal

    rm -rf $savedir
}

migrate_isvc() {
    local savedir=$savebase/omsa
    local newdir=/opt/dell/srvadmin/etc/srvadmin-isvc/ini/

    [ -e $savedir ] || return 0
    [ -e $newdir/dclrdy32.ini ] || return 0

    for ini in dccody32.ini dcisdy32.ini dclrdy32.ini; do
        [ -e $savedir/$ini ] || continue
        $migrate_ini -i $savedir/$ini -o $newdir/$ini --merge-section=* --no-space-equal
    done

    rm -rf $savedir
}

migrate_iws() {
    return 0
}

migrate_omss() {
    local savedir=$savebase/srvadmin/sm/ini
    [ -e $savedir ] || return 0
    [ -e /opt/dell/srvadmin/etc/srvadmin-storage/stsvc.ini ] || return 0

    mv $savedir/smvdname.ini /opt/dell/srvadmin/etc/srvadmin-storage/smvdname.ini
    $migrate_ini --input $savedir/stsvc.ini  --output /opt/dell/srvadmin/etc/srvadmin-storage/stsvc.ini --merge-section=* --filter-section=loadvils --no-space-equal
    rm -rf $savedir
}

migrate_omcommon() {
    local savedir=$savebase/srvadmin/oma
    [ -e /opt/dell/srvadmin/etc/openmanage/oma/ini/oma.properties ] || return 0
    [ -e $savedir/ini/oma.properties ] || return 0

    $migrate_ini -i $savedir/ini/omprv32.ini -o /opt/dell/srvadmin/etc/openmanage/oma/ini/omprv.ini --merge-section=webserverconfig --merge-section=wsmanda --merge-section=non_publishing --no-space-equal
    rm -f $savedir/ini/omprv32.ini

    $migrate_nv -i $savedir/ini/oma.properties -o /opt/dell/srvadmin/etc/openmanage/oma/ini/oma.properties --copy-keys=*
    rm -f $savedir/ini/oma.properties

    omsaoem_orig=$savebase/srvadmin/wwwroot/oem/data/ini/omsaoem.ini
    $migrate_ini -i $omsaoem_orig -o /opt/dell/srvadmin/var/lib/openmanage/wwwroot/oem/data/ini/omsaoem.ini --merge-section=* --no-space-equal
    rm -rf $savebase/srvadmin/wwwroot
}
 
migrate_omacore() {
    local savedir=$savebase/srvadmin/oma
    [ -e /opt/dell/srvadmin/etc/openmanage/oma/ini/omsad.pro ] || return 0
    [ -e $savedir/ini/omsad.pro ] || return 0

    # in omacore
    omsad_pro=$savedir/ini/omsad.pro
    $migrate_nv -i $omsad_pro -o /opt/dell/srvadmin/etc/openmanage/oma/ini/omsad.pro --copy-keys=*

    rm -rf $savedir
}

migrate_deng
migrate_isvc
migrate_iws
migrate_omcommon
migrate_omacore
migrate_omss

# isvc installed after old vers of deng/hapi have been removed
[ "$1" = "srvadmin-isvc" ] && rm -rf /opt/dell/srvadmin/dataeng ||:
[ "$1" = "srvadmin-isvc" ] && rm -rf /opt/dell/srvadmin/shared ||:
[ "$1" = "srvadmin-isvc" ] && rm -rf /opt/dell/srvadmin/hapi ||:

[ "$1" = "srvadmin-storage" ] && rm -rf /opt/dell/srvadmin/sm ||:

# iws after jre
[ "$1" = "srvadmin-iws" ] && rm -rf /opt/dell/srvadmin/jre ||:

[ "$1" = "srvadmin-omacore" ] && rm -rf /opt/dell/srvadmin/omsa ||:
[ "$1" = "srvadmin-omacore" ] && rm -rf /opt/dell/srvadmin/xslroot ||:

# this happens after all upgrade is complete
if [ "$1" = "posttrans" ]; then
	# cant actually remove .../funcs because it breaks zypper upgrade on suse
	# rm -rf /opt/dell/srvadmin/funcs
	rm -rf /opt/dell/srvadmin/oma /opt/dell/srvadmin/jre > /dev/null 2>&1 ||:
fi
rmdir /opt/dell/srvadmin/oma > /dev/null 2>&1 ||:

# old symlinks
rm -f /usr/bin/dsm_om_connsvc
rm -f /usr/bin/omconfig
rm -f /usr/bin/omexec
rm -f /usr/bin/omhelp
rm -f /usr/bin/omreport
rm -f /usr/bin/omupdate
rm -f /usr/bin/srvadmin-services.sh
rm -f /usr/bin/srvadmin-uninstall.sh

rmdir /etc/srvadmin/*/* 2>/dev/null
rmdir /etc/srvadmin/* 2>/dev/null
rmdir /etc/srvadmin 2>/dev/null

# OLD OM Services were not properly unregistered on uninstall

# Init script names have changed, check if the old one (omawsd) is installed
# Older RPMs did not have init script as part of RPM, so it wasnt cleanly removed
if [ -x /etc/init.d/omawsd ]
then
   /etc/init.d/omawsd  stop
   if [ -x /usr/lib/lsb/remove_initd ]; then
      /usr/lib/lsb/remove_initd  /etc/init.d/omawsd
   else
      /sbin/chkconfig  --del /etc/init.d/omawsd
   fi
    rm -f /etc/init.d/omawsd
fi
