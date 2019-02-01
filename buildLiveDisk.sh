#!/bin/sh
# run this script to build livedisk

pacman -Sy archiso arch-install-scripts

cp $(dirname $0)/windowsAutoAdminUnlock.service $(dirname $0)/livedisk/airootfs/etc/systemd/system/
cp $(dirname $0)/windowsAutoAdminUnlock.sh $(dirname $0)/livedisk/airootfs/root/

sh $(dirname $0)/livedisk/build.sh -A "Windows Auto Admin Unlocker livedisk "
