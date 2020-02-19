#!/bin/bash
wget "https://github.com/pciutils/pciids/raw/master/pci.ids" -O ${BASH_SOURCE%/*}/../misc/pci.ids
wget "https://www.smartmontools.org/export/HEAD/trunk/smartmontools/drivedb.h" -O ${BASH_SOURCE%/*}/../misc/drivedb.h
