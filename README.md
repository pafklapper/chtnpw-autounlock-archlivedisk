### Purpose: 
a pluggable way to quickly unlock the builtin Administrator account on Windows. As a sysadmin working in varying environments, you can't always wait for the official techsupport to take over the machine. 

After the first login as 'Administrator' the account will be blocked again.

### Steps:
1. Run buildLivedisk.sh on an Arch machine (vanilla, not manjaro or whatever) after having installed the packages archiso and arch-iso-scripts
Proposed: pacman -Sy archiso arch-iso-script

If everything works a burnable image in the form of "archlinux-[date]-x86-64.iso" should appear in the folder "iso"

2. Burn that iso to an USB (or whatever)
Proposed: dd if=[PATH-TO-ISO-FILE] of=/dev/sd[DRVELETTER-OF-USB] bs=4M status=progress && sync

### Workings:
This repo contains two scripts which function mainly to wrap up 'chntpw':

1. windowsAutoAdminUnlock.sh does the following: 
- it searches for an available ntfs blockdevice and checks for Windows, mount it
- writes to SAM file using the awesomenes of chntpw the following:
	- unlock built-in Administrator account
	- clear it's password
- adds script autoDisableAdmin.bat to root of C:\ that disables Administrator user after first login, clears "..\CurrentVersion\Run\autoDisableAdmin" and deletes itself (Administrator must stay caged!)

Optional parameters:

   -finalizeTimeout=5 -> wait time before finalizing

   -finalizeAction="poweroff" -> select poweroff/reboot for continuation (or choose whatever oneliner to pass through to 'eval')

   -sideLoadTarget="sideload" -> change to location to which files in "sideload"-folder will be copied on Windows partition.

   -sideLoadExecutables=( "HPQFlash/HpqFlash.exe" "powerSHELL cmd /c pause | out-null") -> optional array of executables to be run once (priviliged) at next boot.Prepend powershell commands with powerSHELL, as shown in example. Make sure the executables are made available in the "sideload" directory.

2. buildLiveDisk.sh
	- it checks if archiso and arch-install-scripts are available
	- sets up livedisk working directory, then copies in .service file and windowsAutoAdminUnlock.sh
	- sets various parameters for cleanliness
	- builds iso using livedisk/build.sh (stock script from arch-install-scripts)

Optional parameters:

	- one may add files to the 'sideload' folder. These will be copied over by the livedisk to the Windows partition at the location specified by "sideLoadTarget"
