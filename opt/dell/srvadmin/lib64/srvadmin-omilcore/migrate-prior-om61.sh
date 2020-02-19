#!/usr/bin/env bash

# Dir where config files are to be temporarily saved.
# migrate-legacy.sh script will pick config files from this location.
BACKUP_DIR=/opt/dell/srvadmin/lib64/srvadmin-omilcore/savedsettings

# Value of this variable will get overwritten later.
PREVIOUS_INSTALLED_DIR=/opt/dell/srvadmin

# list of files to be preserved.
FileList=(iws/config/iws.ini iws/config/client_properties.ini iws/config/server_properties.ini 
iws/config/session.ini iws/config/keystore.ini iws/config/keystore.db 
wwwroot/oem/data/ini/oem.ini wwwroot/oem/data/ini/oem_200.ini
wwwroot/oem/data/ini/omsaoem.ini wwwroot/oem/data/ini/prefoem.ini
oma/ini/oma.properties oma/ini/omsad.pro omsa/log/omcmdlog.xml oma/ini/omprv32.ini
oma/lib/OMHIP.jar oma/lib/OMPREF.jar oma/lib/OMSA.jar
sm/stsvc.ini sm/smvdname.ini)

[ -d $BACKUP_DIR ] || mkdir -p $BACKUP_DIR

GetPreviousInstallDir() {
    KEY=openmanage.omilcore.installpath
    PAIR=`grep -i "^[[:space:]]*${KEY}[[:space:]]*=" $BACKUP_DIR/omreg.cfg.1`
    PREVIOUS_INSTALLED_DIR=`echo "${PAIR}" | sed 's#^[^=]*=##; s#^[[:space:]]*##; s#[[:space:]]*$##'`
}

[ -f $BACKUP_DIR/omreg.cfg.1 ] || exit 0
GetPreviousInstallDir

#Copy jar files - for 6.2.0 and above.
[ -d $BACKUP_DIR/srvadmin/iws/config ] || mkdir -p $BACKUP_DIR/srvadmin/iws/config
[ -d $BACKUP_DIR/srvadmin/oma/lib ] || mkdir -p $BACKUP_DIR/srvadmin/oma/lib

[ -f $PREVIOUS_INSTALLED_DIR/share/java/OMPREF.jar ] &&
     cp -dpf $PREVIOUS_INSTALLED_DIR/share/java/OMPREF.jar $BACKUP_DIR/srvadmin/oma/lib/ > /dev/null 2>&1
[ -f $PREVIOUS_INSTALLED_DIR/share/java/OMSA.jar ] &&
     cp -dpf $PREVIOUS_INSTALLED_DIR/share/java/OMSA.jar $BACKUP_DIR/srvadmin/oma/lib/ > /dev/null 2>&1
[ -f $PREVIOUS_INSTALLED_DIR/etc/openmanage/iws/config/keystore.db ] &&
     cp -dpf $PREVIOUS_INSTALLED_DIR/etc/openmanage/iws/config/keystore.db $BACKUP_DIR/srvadmin/iws/config/ > /dev/null 2>&1
[ -f $PREVIOUS_INSTALLED_DIR/etc/openmanage/iws/config/keystore.ini ] &&
     cp -dpf $PREVIOUS_INSTALLED_DIR/etc/openmanage/iws/config/keystore.ini $BACKUP_DIR/srvadmin/iws/config/ > /dev/null 2>&1

for file in ${FileList[*]}
do 
   DIR_NAME=`dirname $file`
   
   if [ -f $PREVIOUS_INSTALLED_DIR/$file ]; then
      [ -d $BACKUP_DIR/srvadmin/$DIR_NAME ] || mkdir -p $BACKUP_DIR/srvadmin/$DIR_NAME
      cp -dpf $PREVIOUS_INSTALLED_DIR/$file $BACKUP_DIR/srvadmin/$DIR_NAME/. > /dev/null 2>&1
   fi
done

#Extra customization is required for storage files
[ -d $BACKUP_DIR/srvadmin/sm/ini ] || mkdir -p $BACKUP_DIR/srvadmin/sm/ini
[ -f $BACKUP_DIR/srvadmin/sm/stsvc.ini ] && mv $BACKUP_DIR/srvadmin/sm/stsvc.ini $BACKUP_DIR/srvadmin/sm/ini/stsvc.ini
[ -f $BACKUP_DIR/srvadmin/sm/smvdname.ini ] && mv $BACKUP_DIR/srvadmin/sm/smvdname.ini $BACKUP_DIR/srvadmin/sm/ini/smvdname.ini

# *dy*.ini files are to be copied in a separate dir.
# Hence keeping them separately.
[ -d $BACKUP_DIR/dataeng/ini ] || mkdir -p $BACKUP_DIR/dataeng/ini
[ -d $BACKUP_DIR/omsa/ini ] || mkdir -p $BACKUP_DIR/omsa/ini
cp -dpf $PREVIOUS_INSTALLED_DIR/dataeng/ini/*dy*.ini $BACKUP_DIR/dataeng/ > /dev/null 2>&1
cp -dpf $PREVIOUS_INSTALLED_DIR/omsa/ini/*dy*.ini $BACKUP_DIR/omsa/ > /dev/null 2>&1

