#!/bin/sh
bin_file=$(readlink -f "$0")
install_root=
license_accept=0
while [ $# -gt 0 ]
do
    case $1 in
    "--accept")
        license_accept=1
    esac
    shift
done

if [ $# -gt 0 ] #Check for any remaining options
then
    echo "Unknown option $1."
    exit 1
fi

cur_usr=$(whoami)
cur_grp=
(groups | grep -w root) > /dev/null 2>&1
if [ $? -eq 0 ]
then
    cur_grp=root
fi

if [ "$cur_usr" != "root" -a "$cur_grp" != "root" ]
then
    echo "You require root privilege to remove the package."
    exit 1
fi

install_dir_base=$install_root/opt/toshiba
install_dir_prod=$install_dir_base/tsbdrv
install_bindir=$install_dir_prod/bin
install_libdir=$install_dir_prod/lib64
USR_BIN_DIR=/usr/bin
USR_LIB_DIR=/usr/lib64
SYS_LIB_DIR=/lib64
install_tmp_file=/tmp/tsbdrvd.log
install_etcdir=$install_dir_prod/etc
server_conf_file=$install_etcdir/tsbdrvd.conf.json
SYS_INITD_DIR=/etc/init.d
SYS_PAMD_DIR=/etc/pam.d
if [ -f /etc/debian_version ]
then
    arch_tag=i386
    if [ x64 = "x64" ]
    then
        arch_tag=x86_64
    fi
    USR_LIB_DIR=/usr/lib/$arch_tag-linux-gnu
    SYS_LIB_DIR=/lib/$arch_tag-linux-gnu
fi

if [ ! -e "$install_dir_prod" -o ! -d "$install_dir_prod" ]
then
    echo "Invalid installation path. Product directory does not exit"
    exit 1
fi
pchk_dir=$install_dir_prod

check_success()
{
    if [ $1 -ne 0 ]
    then
        shift
        echo
        echo "    $*"
        echo
        echo "***tsbdrv "uninstall" failed!"
        echo
        exit 1
    fi
}

echo "tsbdrv will be removed from the system."
while [ 1 -eq 1 ]
do
    echo -n "Are you sure to remove tsbdrv? [y/n] "
    read USER_CHOICE
    if [ -n "$USER_CHOICE" ]
    then
        if [ "$USER_CHOICE" = "y" -o "$USER_CHOICE" = "Y" ]
        then
            break
        elif [ "$USER_CHOICE" = "n" -o "$USER_CHOICE" = "N" ]
        then
            echo "Uninstallation has been cancelled!!"
            exit 0
        fi
    fi
    echo "Invalid choice! Please try again..."
done

rm -f "$USR_BIN_DIR/tsbdrv" > /dev/null 2>&1
check_success $? "Can not remove tsbdrv files."

rm -f "$USR_LIB_DIR/libtsblib.so" > /dev/null 2>&1
check_success $? "Can not remove tsbdrv files."

if [ -f "$USR_BIN_DIR/tsbdrvd" ]
then
    rm -f "$USR_BIN_DIR/tsbdrvd" > /dev/null 2>&1
    check_success $? "Can not remove tsbdrv files."
fi

if [ -f "$SYS_PAMD_DIR/tsbdrvd" ]
then
    rm -f "$SYS_PAMD_DIR/tsbdrvd" > /dev/null 2>&1
    check_success $? "Can not remove tsbdrv files."
fi

if [ -f "$USR_LIB_DIR/libcpprest.so.2.9" ]
then
    rm -f "$USR_LIB_DIR/libcpprest.so.2.9" > /dev/null 2>&1
    check_success $? "Can not remove tsbdrv files."
fi

if [ -f "$SYS_INITD_DIR/tsbdrvd" ]
then
    # Stop and unconfigure service
    service tsbdrvd stop
    grep -i ubuntu /etc/os-release > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        update-rc.d -f tsbdrvd remove > /dev/null 2>&1
    else
        chkconfig --del tsbdrvd > /dev/null 2>&1
    fi

    rm -f "$SYS_INITD_DIR/tsbdrvd" > /dev/null 2>&1
    check_success $? "Can not remove tsbdrv files."
fi

rm -rf "$install_dir_prod" > /dev/null 2>&1
check_success $? "Can not remove $install_dir_prod."

grep -i ubuntu /etc/os-release > /dev/null 2>&1
if [ $? -ne 0 ]
then
    systemctl daemon-reload > /dev/null 2>&1
fi

echo "tsbdrv removed from the system successfully."

exit 0
