#!/bin/sh
# run this script to build livedisk

# bash run options
set -o pipefail
set -e -u

# GLOBVARS
wd="$(dirname $0)"
livediskWD="$wd/wd"
livediskOUT="$wd/iso"

# GLOBFUNCS
logp()
{
case "$1" in
	info)
		echo -e "\e[32m\e[1m* \e[0m$2"
	;;
	warning)
		echo -e "\033[31m\e[1m* \e[0m$2"
	;;
	fatal)
		echo -e "\e[31m\e[1m* \e[0m\e[30m\e[101m$2"
		echo -e "\e[31m\e[1m* \e[0m\e[30m\e[101mHit enter to continue...\e[0m"

		read </dev/tty
	;;
	beginsection)
		echo -e "\e[33m**********************************************"
		echo -e "\e[33m||||||||||||||||||||||||||||||||||||||||||||||\e[0m"
	;;
	endsection)
		echo -e "\e[33m||||||||||||||||||||||||||||||||||||||||||||||"
		echo -e "\e[33m**********************************************\e[0m"
	;;
esac
}

# trap
finish() {
rm -rf $livediskWD
}
trap finish EXIT SIGINT SIGTERM

clear
logp info "Our purpose today: generating an ISO that will auto unlock the Administrator user on detected Windows partitions"
logp beginsection
logp info "Generating ISO, output @ $livediskOUT"
sleep 1

pacman -Qi archiso || { logp info "Installing package 'archiso'..." && pacman -Sy archiso || exit 1; }
pacman -Qi arch-install-scripts || { logp info "Installing package 'arch-install-scripts'..." && pacman -Sy arch-install-scripts || exit 1; }


if [ -d /usr/share/archiso/configs/releng ]; then
	
	logp info "Setting up livedisk parameters..."
	cp -r -n /usr/share/archiso/configs/releng/* $wd/livedisk/
	retVal=0
	retVal=$(($retVal + $?))

	cp $wd/windowsAutoAdminUnlock.service $wd/livedisk/airootfs/etc/systemd/system/
	retVal=$(($retVal + $?))

	cp $wd/windowsAutoAdminUnlock.sh $wd/livedisk/airootfs/root/
	retVal=$(($retVal + $?))

	sed -i '/^APPEND/ s/$/ quiet splash vga=current loglevel=0 systemd.show_status=false udev.log_priority=0/' $wd/livedisk/syslinux/archiso_sys.cfg
	retVal=$(($retVal + $?))

	sed -i '/^options/ s/$/ quiet splash vga=current loglevel=0 systemd.show_status=false udev.log_priority=0/' $wd/livedisk/efiboot/loader/entries/*.conf
	retVal=$(($retVal + $?))

	sed -i '/timeout/c\timeout 1' $wd/livedisk/efiboot/loader/loader.conf
	retVal=$(($retVal + $?))

	echo CHNTPW > $wd/livedisk/airootfs/etc/hostname
	retVal=$(($retVal + $?))

	mkdir -p $livediskOUT
	retVal=$(($retVal + $?))

	mkdir -p $livediskWD
	retVal=$(($retVal + $?))
	
	if [ $retVal -eq 0 ]; then
		sh $wd/livedisk/build.sh -A "Automatic unlocker for Windows Admin account - Arch Livedisk" -L "CHNTPW" -o $livediskOUT -w $livediskWD && logp info "ISO succesfully generated!" || logp fatal "ISO failed to generate!"
	else
		logp fatal "failed to setup livedisk environment!"
	fi

	logp endsection
else
	logp fatal "Archiso profile directory could not be found! (archiso is only available in vanilla Archlinux, not in Manjaro or other derivates!)"
fi
