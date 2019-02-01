#!/bin/sh
# automatically unlock the Administrator user on computers running Windows
# WARNING: this script only supports systems running a SINGLE windows installation, more than one ntfs partition of whatever other kind is no problem.


#GLOBVARS
mountPoint="/mnt"

#INTVARS
ntfsBlk=""


# bash run options
set -o pipefail

# trap
function finish {
sync
umount -f $mountPoint 
}
trap finish SIGINT SIGTERM EXIT


# global functions
include globalFunctions


findAndMountWindowsPartition()
{
blkid|grep ntfs| while read ntfsLine; do
	export ntfsBlk="$(echo $ntfsLine|cut -d: -f1)"

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
cp -a $mountPoint/Windows/System32/config/SAM $mountPoint/Windows/System32/config/SAM.old
chntpw -u Administrator $mountPoint/Windows/System32/config/SAM<<EOF 
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
		logp fatal "Need root to continue!"
	fi

	clear && logp beginsection
	logp info "Our purpose today: to automagically unlocking Administrator user on Windows partition.."
	logp info "(this is a chntpw wrapper script)"

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
	logp info "Exiting now to halt system!"
	logp endsection

	# sleep 1 && poweroff
}


main $@
