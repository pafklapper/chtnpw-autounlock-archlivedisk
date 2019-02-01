#!/bin/sh
# run this script to build livedisk

# GLOBVARS
wd="$(dirname $0)"
livediskWD="$wd/wd"
livediskOUT="$wd/iso"

# trap
finish() {
rm -rf $livediskWD
}
trap finish EXIT SIGINT SIGTERM

logp beginsection
logp info "Generating ISO, output @ $livediskOUT"

pacman -Qi archiso || logp info "Installing package 'archiso'..." && pacman -Sy archiso
pacman -Qi arch-install-scripts || logp info "Installing package 'arch-install-scripts'..." && pacman -Sy arch-install-scripts 

cp $wd/windowsAutoAdminUnlock.service $wd/livedisk/airootfs/etc/systemd/system/
cp $wd/windowsAutoAdminUnlock.sh $wd/livedisk/airootfs/root/

mkdir -p $livediskOUT
mkdir -p $livediskWD

sh $wd/livedisk/build.sh -A "Automatic unlocker for Windows Admin account - Arch Livedisk" -L "CHNTPW" -o $livediskOUT -w $livediskWD && logp info "ISO succesfully generated!" || logp warning "ISO failed to generate!"
