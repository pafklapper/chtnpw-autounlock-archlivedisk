#!/bin/sh
# automatically unlock the Administrator user on computers running Windows
# WARNING: this script only supports systems running a SINGLE windows installation, more than one ntfs partition of whatever other kind is no problem.


#GLOBVARS
mountPoint="/mnt"

# bash run options
set -o pipefail

# trap
function finish {
sync
umount -f $mountPoint 
}
trap finish SIGINT SIGTERM EXIT


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
		echo -e "\e[31m\e[1m* \e[0m\e[30m\e[101mHit enter to reboot...\e[0m"

		read </dev/tty && reboot
	;;
	beginsection)
		echo -e "\e[33m**********************************************"
		echo -e "\e[33m||||||||||||||||||||||||||||||||||||||||||||||"
	;;
	endsection)
		echo -e "\e[33m||||||||||||||||||||||||||||||||||||||||||||||"
		echo -e "\e[33m**********************************************"
	;;
	notify)
		# as ripped from: https://www.forsomedefinition.com/automation/creating-telegram-bot-notifications/
		if [ -n "$TELEGRAMCHATID" ] && [ -n "$TELEGRAMTOKEN" ]; then
			local curlTimeOut="10"
			local URL="https://api.telegram.org/bot$TELEGRAMTOKEN/sendMessage"
			local TEXT="$2"
	
			curl -s --max-time $curlTimeOut -d "chat_id=$TELEGRAMCHATID&disable_web_page_preview=1&text=$TEXT" $URL >/dev/null
		fi
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
			if  [ $? -eq 0 ]; then
				logp info "NTFS filesystem on harddisk $ntfsBlk was succesfully fixed!"
			else
				logp fatal "Couldn't fixe the NTFS filesystem on harddisk $ntfsBlk!"
			fi
		else
			if [ -d $mountPoint/Windows ]; then
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
chntpw -u Administrator <<EOF 
1
2
q
y

EOF
sync
}


main()
{
	if [ ! "$(whoami)" = "root" ]; then
		logp fatal "Need root to continue..!"
	fi

	logp beginsection
	logp info "Our purpose today: to automagically unlocking Administrator user on Windows partition.."
	logp info "(this is a chntpw wrapper script)"

	logp info "Searching and mounting Windows partition..."
	if findAndMountWindowsPartition; then
		logp info "Found Windwos partion on $ntfsBlk"
	else 
		logp fatal "$(lsblk -f)"
		logp fatal "No Windows partitions could be found"
	fi
	
	logp info "unlocking user Administrator using chntpw magic..."
	if unlockAdminUser; then
		logp info "succesfully unlocked Administrator"
	else
		logp fatal "No dice :("
	fi
	logp info "Exiting now to halt!"
	logp endsection

	# sleep 1 && poweroff
}


main $@
