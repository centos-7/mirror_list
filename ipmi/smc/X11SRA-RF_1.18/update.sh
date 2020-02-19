#!/bin/sh

mkdir /opt/smc_ipmi/
cp socflash_x64 WS_X11AST2500_1.18.bin -t /opt/smc_ipmi/
cd /opt/smc_ipmi/
echo y | ./socflash_x64 -s WS_X11AST2500_1.18.bin
