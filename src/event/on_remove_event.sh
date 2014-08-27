#!/bin/bash

#vars to initialize terminal
export TERM="xterm-256color"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

#load utility functions
source /home/pi/DiskDumper/utils.sh

#set cleanup function when killed or exited
trap "cleanup" INT QUIT TERM EXIT

#check input arguments
if [ -z $1 ]; then
	color_echo "No partition given in input, aborting !" red
	exit 1
else
	#get connected partition informations
	PARTITION=$1
	UUID=$(get_uuid $1)
	LABEL=$(get_label $1)
fi

#check if this is the backup disk (UUID needed)
if [ -n "$UUID" ]; then
	color_echo "[$(date)] $PARTITION unplugged (UUID=$UUID) !" blue
	if [ -n "$(cat /home/pi/DiskDumper/backup.conf | grep $UUID)" ]; then
		color_echo "/dev/$PARTITION with UUID=\"$UUID\" is registered as backup data device !" yellow
		color_echo "Unmounting and removing /mnt/backup ..." blue

		umount /dev/$PARTITION
		umount /mnt/backup > /dev/null
	
		if ! [ -L /dev/backup ]; then
			safe-rm /dev/backup
		fi

		set_pin_val 7 0

		exit 0
	fi
else
	color_echo "[$(date)] $PARTITION unplugged (no uuid) !" blue
fi


#check if this is a registered device to sync (with UUID, or label)
if [ -n "$UUID" ]; then #device has UUID
	if [ -z $(cat /home/pi/DiskDumper/sync.conf | grep $UUID) ]; then
		exit 0
	fi
else #without UUID
	color_echo "Device has no UUID..." red
	color_echo "Trying with label..." blue
	
	if [ -n "$LABEL" ]; then #device has a label
		if [ -z "$(cat /home/pi/DiskDumper/sync.conf | grep $LABEL)" ]; then
			exit 0
		fi
	else #device has no uuid and no label
		color_echo "Device has no label either, aborting !" red
		exit 1
	fi
fi

umount /dev/$PARTITION

if [ -d /mnt/$PARTITION ]; then
	umount /mnt/$PARTITION
	safe-rm -Rf /mnt/$PARTITION
fi


