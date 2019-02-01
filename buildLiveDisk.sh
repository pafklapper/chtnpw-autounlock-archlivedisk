#!/bin/sh
# run this script to build livedisk

livediskWD=`mktemp -d`

finish() {
rm -rf $livediskWD
}
trap finish EXIT SIGINT SIGTERM


pacman -Qi archiso || pacman -Sy archiso
pacman -Qi arch-install-scripts || pacman -Sy arch-install-scripts 

cp $(dirname $0)/windowsAutoAdminUnlock.service $(dirname $0)/livedisk/airootfs/etc/systemd/system/
cp $(dirname $0)/windowsAutoAdminUnlock.sh $(dirname $0)/livedisk/airootfs/root/

mkdir $(dirname $0)/ISO

sh $(dirname $0)/livedisk/build.sh -A "Automatic unlocker for Windows Admin account - Arch Livedisk" -L "CHNTPW" -o $(dirname $0)/ISO -w $livediskWD
