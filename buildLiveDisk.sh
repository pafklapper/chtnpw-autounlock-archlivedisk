#!/bin/sh
# run this script to build livedisk

cp $(dirname $0)/windowsAutoAdminUnlock.service $(dirname $0)/livedisk/airootfs/root/
cp $(dirname $0)/windowsAutoAdminUnlock.sh $(dirname $0)/livedisk/airootfs/root/

sh $(dirname $0)/livedisk/build.sh -A "Windows Auto Admin Unlocker livedisk "
