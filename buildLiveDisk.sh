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

pacman -Qi archiso 1>/dev/null || logp fatal "Package 'archiso' is not installed! Be warned: Arch derivatives like Manjaro don't have this package in repo :( \n Proposed: pacman -S archiso "
pacman -Qi arch-install-scripts 1>/dev/null || logp fatal "Package 'archiso' is not installed! Be warned: Arch derivatives like Manjaro don't have this package in repo :( \n Proposed: pacman -S arch-install-scripts"

if [ -d /usr/share/archiso/configs/releng ]; then
	
	logp info "Setting up livedisk parameters..."
	cp -r -n /usr/share/archiso/configs/releng/* $wd/livedisk/
	retVal=0
	retVal=$(($retVal + $?))

	cp $wd/windowsAutoAdminUnlock.service $wd/livedisk/airootfs/etc/systemd/system/
	retVal=$(($retVal + $?))

	cp $wd/windowsAutoAdminUnlock.sh $wd/livedisk/airootfs/root/
	retVal=$(($retVal + $?))

	if find "$wd/sideload" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
		logp info "Copying over sideload files..."
		mkdir -p $wd/livedisk/airootfs/root/sideload
		retVal=$(($retVal + $?))

		cp -av $wd/sideload/* $wd/livedisk/airootfs/root/sideload/
		retVal=$(($retVal + $?))
	fi

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
		logp info "Generating ISO, resulting image can be found @ $livediskOUT"
		sleep 1
		sh $wd/livedisk/build.sh -A "Automatic unlocker for Windows Admin account - Arch Livedisk" -L "CHNTPW" -o $livediskOUT -w $livediskWD && logp info "ISO succesfully generated! ISO @ $livediskOUT" || logp fatal "ISO failed to generate!"
	else
		logp fatal "Failed to setup livedisk environment!"
	fi

	logp endsection
else
	logp fatal "Archiso profile directory could not be found!"
fi
