#!/bin/sh
# run this script to build livedisk

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
		echo -e "\e[33m||||||||||||||||||||||||||||||||||||||||||||||"
	;;
	endsection)
		echo -e "\e[33m||||||||||||||||||||||||||||||||||||||||||||||"
		echo -e "\e[33m**********************************************"
	;;
esac
}

# trap
finish() {
rm -rf $livediskWD
}
trap finish EXIT SIGINT SIGTERM

clear
logp beginsection
logp info "Generating ISO, output @ $livediskOUT"
sleep 1

pacman -Qi archiso || { logp info "Installing package 'archiso'..." && pacman -Sy archiso || exit 1; }
pacman -Qi arch-install-scripts || { logp info "Installing package 'arch-install-scripts'..." && pacman -Sy arch-install-scripts || exit 1; }

cp $wd/windowsAutoAdminUnlock.service $wd/livedisk/airootfs/etc/systemd/system/
cp $wd/windowsAutoAdminUnlock.sh $wd/livedisk/airootfs/root/

mkdir -p $livediskOUT
mkdir -p $livediskWD

sh $wd/livedisk/build.sh -A "Automatic unlocker for Windows Admin account - Arch Livedisk" -L "CHNTPW" -o $livediskOUT -w $livediskWD && logp info "ISO succesfully generated!" || logp warning "ISO failed to generate!"
