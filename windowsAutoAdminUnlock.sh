#!/bin/sh
# automatically unlock the Administrator user on computers running Windows
# WARNING: this script only supports systems running a SINGLE windows installation, more than one ntfs partition of whatever other kind is no problem.

#GLOBVARS
finalizeTimeout=15 # set finalizeTimeout to 0 to immediately reboot after script has ran 
finalizeAction="poweroff" # set to arbitary string that will be passed to 'eval' and run as last command.
sideLoadTarget="sideload" #  arbitrary folder on C:\ which will contain sideLoad files
sideLoadExecutables=("HPQFlash/HpqFlash.exe -s -a" "powerSHELL cmd /c pause | out-null") # array of execubles/commands that will be autorun once. Use spaces as seperator. Prepend a powershell command with "powerSHELL"
# EXAMPLE: sideLoadExecutables=("HPQFlash/HpqFlash.exe -s -a" "powerSHELL whoami")  

#INTVARS
ntfsBlk=""
mountPoint="/mnt"

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
			ntfsfix -d $ntfsBlk
			if  [ ! $? -eq 0 ]; then
				logp warning "Couldn't fix the NTFS filesystem on harddisk $ntfsBlk!"
				return 1
			fi
		else
			if [ -d $mountPoint/Windows/System32 ]; then
				logp info "Found Windows-installation @ $ntfsBlk!"
				return 0
			else
				umount $mountPoint
			fi
		fi
	else
		logp warning "Scripterror in blockdetection: variable \$ntfsblk has invalid value $ntfsBlk "
		return 1
	fi
done
}

unlockAdminUser()
{

( cp -af $mountPoint/Windows/System32/config/SAM $mountPoint/Windows/System32/config/SAM.old
chntpw -u Administrator $mountPoint/Windows/System32/config/SAM<<EOF 
1
2
q
y

EOF
) 1>/dev/null 2>/dev/null

# for some reason chntpw returns 2 if it runs succesfully (?)
if [ $? -eq 2 ]; then
	sync && return 0;
else
	sync && return 1;
fi
}

relockAdminUserAfterFirstLogin()
{
# scrabbled together after an hour of searching: disable Administrator, delete registry item to run, then delete itself using some true Powershell magic
# sources: DuckDuckGo is your friend :)
cat>$mountPoint/autoDisableAdmin.bat<<EOF
@ECHO OFF
PowerShell.exe -NoProfile -Command "&{ start-process powershell -ArgumentList '-noprofile -command "\$(net user Administrator /active:no) -and \$(Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "autoDisableAdmin")"' -verb RunAs}" && (goto) 2>nul & del "%~f0"
EOF

if [ $? -gt 0 ]; then
	logp warning "Couldn't insert script to Windows partition @ $mountPoint/autoDisableAdmin.bat! "
	return 1
fi

# edit registry to run the cleanup script
( chntpw -e $mountPoint/Windows/System32/config/SOFTWARE<<EOF 
cd Microsoft\Windows\CurrentVersion\Run
nv 1 autoDisableAdmin
ed autoDisableAdmin
C:\autoDisableAdmin.bat
q
y

EOF
) 1>/dev/null 2>/dev/null

if [ $? -eq 2 ]; then
	sync && return 0;
else
	sync && return 1;
fi
}


addAdditionalSideLoadExecutables() {

for exe in "${sideLoadExecutables[$@]}"; do
	sanitizedExe="$(echo $exe |sed 's/[^a-zA-Z0-9]//g')"

	echo sanitzedExe: \"$sanitizedExe\"
	echo Exe: \"$exe\"
	read

	if ! [ "$(echo $exe | grep -e "^powerSHELL")" = "" ]; then
		exe="$(echo $exe | sed  -r 's/^powerSHELL//g')"
		logp info "CMD: \'$exe\' will be run once at next boot!"
cat>$mountPoint/$sanitizedExe.bat<<EOF
@ECHO OFF
PowerShell.exe -NoProfile -Command "&{ start-process powershell -ArgumentList '-noprofile -command "\$( $exe ) -and \$(Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "$sanitizedExe")"' -verb RunAs}" && (goto) 2>nul & del "%~f0"
EOF
	else
		logp info "EXE: 'C:\\$sideLoadTarget\\$exe' will be run once at next boot!"
cat>$mountPoint/$sanitizedExe.bat<<EOF
@ECHO OFF
PowerShell.exe -NoProfile -Command "&{ start-process powershell -ArgumentList \'-noprofile -command "\$(& C:\\$sideLoadTarget\\$exe) -and \$(Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "$sanitizedExe")"\' -verb RunAs}" && (goto) 2>nul & del "%~f0"
EOF
	fi

	if ! [ $? -eq 0 ]; then
		logp warning "Failed to copy powershell script that starts additional sideload executable \'$exe\'..."
		return 1
	fi
	
( chntpw -e $mountPoint/Windows/System32/config/SOFTWARE<<EOF 
cd Microsoft\Windows\CurrentVersion\Run
nv 1 $sanitizedExe
ed $sanitizedExe
C:\\$sanitizedExe.bat
q
y

EOF
) 1>/dev/null 2>/dev/null

	if ! [ $? -eq 2 ]; then
		logp warning "Chntpw magic failed to set \'$exe\' to autolaunch via 'CurrentVersion\Run'!"
		return 1
	fi
done
}

main()
{
	if [ ! "$(whoami)" = "root" ]; then
		logp fatal "Need root to continue!"
	fi

	clear
echo -e "\e[31m"
cat<<EOF
Much love to:
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
	
	logp info "Adding cleanup script to Administrator to auto-disable account after first login..."
	if relockAdminUserAfterFirstLogin; then
		logp info "Succesfully added cleanup script!"
	else
		logp fatal "Failed to add cleanup script to Administrator shell:startup to auto-disable account after first login!"
	fi


	if [ -d /root/sideload ]; then
		logp info "Sideloading files to $sideLoadTarget..."
		if mkdir -p $mountPoint/$sideLoadTarget && cp -av /root/sideload/* $mountPoint/$sideLoadTarget && sync; then
			logp info "Files succesfully sideloaded!"
		else
			logp warning "Sideload failed to be copied over!"
		fi
	fi

	if [ ${#sideLoadExecutables[@]} -gt 0 ]; then
		logp info "Adding additional executable to be autorun at next boot..."
		if addAdditionalSideLoadExecutables; then
			logp info "Additional executables succesfully set up!"
		else
			logp fatal "Additional executables failed to be set up!"
		fi
	fi

	logp info "Finalizing in $finalizeTimeout seconds!"
	logp endsection

	sleep $finalizeTimeout && eval "$finalizeAction"
}

main $@
