#!/bin/sh
# automatically unlock the Administrator user on computers running Windows
# WARNING: this script only supports systems running a SINGLE windows installation, more than one ntfs partition of whatever other kind is no problem.

#GLOBVARS
mountPoint="/mnt"
finalizeTimeout=10 # set finalizeTimeout to 0 to immediately reboot after script has ran 

#INTVARS
ntfsBlk=""

# bash run options
set -o pipefail
set -e -u

# trap
function finish {
sync
umount -f $mountPoint 
}
trap finish SIGINT SIGTERM EXIT


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
		echo -e "\e[31m\e[1m* \e[0m\e[30m\e[101mHit enter to halt system...\e[0m"

		read </dev/tty && poweroff
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


findAndMountWindowsPartition()
{
blkid|grep ntfs| while read ntfsLine; do
	ntfsBlk="$(echo $ntfsLine|cut -d: -f1)"

	if [ -b $ntfsBlk ]; then 
	mount -o remove_hiberfile $ntfsBlk $mountPoint

	if [ $? -gt 0 ]; then
			logp warning "Mounting harddisk $ntfsBlk failed! "
			umount -f $ntfsBlk
			ntfsfix -b -d $ntfsBlk
			if  [ ! $? -eq 0 ]; then
				logp fatal "Couldn't fix the NTFS filesystem on harddisk $ntfsBlk!"
			fi
		else
			if [ -d $mountPoint/Windows ]; then
				logp info "Found Windows-installation @ $ntfsBlk!"
				return 0
			else
				umount $mountPoint
			fi
		fi
	else
		logp fatal "Scripterror in blockdetection: variable \$ntfsblk has invalid value $ntfsBlk "
	fi
done
}

unlockAdminUser()
{

(	cp -af $mountPoint/Windows/System32/config/SAM $mountPoint/Windows/System32/config/SAM.old
chntpw -u Administrator $mountPoint/Windows/System32/config/SAM<<EOF 
1
2
q
y

EOF
) 1>/dev/null 2>/dev/null

if [ $? -eq 2 ]; then
	sync 
	return 0;
else
	sync
	return 1;
fi
}

relockAdminUserAfterFirstLogin()
{
cat>$mountPoint/autoDisableAdmin.bat<<EOF
@ECHO OFF
PowerShell.exe -NoProfile -Command "&{ start-process powershell -ArgumentList '-noprofile -command "net user Administrator /active:no"' -verb RunAs}"
(goto) 2>nul & del "%~f0"
EOF

if [ $? -gt 0 ]; then
	logp fatal "Couldn't insert script to Windows partition @ $mountPoint/autoDisableAdmin.bat! "
fi


chntpw -e $mountPoint/Windows/System32/config/SOFTWARE<<EOF 
cd Microsoft\Windows\CurrentVersion\Run
nv 1 autoDisableAdmin
ed autoDisableAdmin
C:\autoDisableAdmin.bat
q
y

EOF

	return $?
}


main()
{
	if [ ! "$(whoami)" = "root" ]; then
		logp fatal "Need root to continue!"
	fi

	clear
echo -e "\e[31m"
cat<<EOF
much love to:
__    __    ___    _     ___    __        __     ___    ____    _
 /  __) \  |   |  / |    \  |  | (__    __) |    \  |  |    |  |
|  /     |  \_/  |  |  |\ \ |  |    |  |    |     ) |  |    |  |
| |      |   _   |  |  | \ \|  |    |  |    |  __/  |  |    |  |
|  \__   |  / \  |  |  |  \    |    |  |    | |      \  \/\/  /
_\    )_/  |___|  \_|  |___\   |____|  |____| |_______\      /___
EOF
echo -e "\e[97m"

	logp info "Our purpose today: to automagically unlocking Administrator user on Windows partition.."
	logp info "(this is a chntpw wrapper script)"
	logp beginsection

	logp info "Searching and mounting Windows partition..."
	if ! findAndMountWindowsPartition; then
		logp fatal "$(lsblk -f)"
		logp fatal "No Windows partition could be found!"
	fi
	
	logp info "Unlocking user Administrator using chntpw magic..."
	if unlockAdminUser; then
		logp info "By the Gods! the Administrator is fully cooperating!"
	else
		logp fatal "No dice :("
	fi
	
	logp info "Adding script to Administrator shell:startup to auto-disable account after first login..."
	if relockAdminUserAfterFirstLogin; then
		logp info "Succesfully added script!"
	else
		logp fatal "Failed to add script to Administrator shell:startup to auto-disable account after first login!"
	fi

	logp info "Exiting in $finalizeTimeout seconds to halt system!"
	logp endsection

	sleep $finalizeTimeout && poweroff
}


main $@
