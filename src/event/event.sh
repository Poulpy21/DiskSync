#!/bin/bash

#vars to initialize terminal
export TERM="xterm-256color"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DC_HOME='/opt/dc'
SRC_PATH="$DC_HOME/src"
INCLUDE_PATH="$SRC_PATH/include"
DEFAULT_PATH="$SRC_PATH/default"
DEFAULT_VARS="$DEFAULT_PATH/default_vars.sh"
VARS="$INCLUDE_PATH/vars.sh"
UTILS="$INCLUDE_PATH/utils.sh"

function include() {
	if [ -e "$@" ]; then
		source "$@"
	else
		echo "The file "$@" does not exist, aborting !"
		exit 1
	fi
}

if [ -e $VARS ]; then
	source $VARS
else
	echo "The file $VARS does not exist, resetting it to default !"
	if [ -e $DEFAULT_VARS ]; then
		cp $DEFAULT_VARS $VARS
		if [ -e $VARS ]; then
			source $VARS
		else
			echo "Failed to create $VARS, aborting !"
			exit 1
		fi
	else
		echo "The file $DEFAULT_VARS does not exist either, aborting !"
		exit 1
	fi
fi

include $UTILS

#check input arguments
if [ -z "$@" ]; then
	color_echo "No partition given in input, aborting !" red
	exit 1
else
	#get connected partition informations
	PARTITION=$1
	UUID=$(get_uuid $1)
	LABEL=$(get_label $1)
fi

#CLEANUP FUNC : kill all child processes, LED off, update logs
cleanup() {
	local pids=$(jobs -pr)
	[ -n "$pids" ] && kill $pids

	echo
	echo
	
	if [ $LOG -eq 1 ] && [ -e $LOG_FOLDER$LOG_PREFIX$1 ]; then
		mkdir -p $LOG_FOLDER
		cat "$LOG_FOLDER$LOG_PREFIX$1" >> "$LOG_FOLDER$LOG_FILE"
		safe-rm "$LOG_FOLDER$LOG_PREFIX$1"
	fi

	sleep 1
	set_pin_val $STATUS_LED 0
}

#set cleanup function when killed or exited
trap "cleanup $PARTITION" INT QUIT TERM EXIT

#start led blinking
if [ $STATUS_LED -eq 1 ]; then
	( blink $STATUS_LED 0$(echo "scale=2; 0.5/$STATUS_LED_FREQ" | bc -l) ) & #fork LED blinking function
	BLINK_PID="$!"
fi

#check if this is the backup disk (UUID needed)
BACKUP_ALIAS_PATH="$DEVICE_FOLDER$BACKUP_PARTITION_ALIAS"
BACKUP_MOUNT_FOLDER="$BACKUP_MOUNT_FOLDER$BACKUP_PARTITION_ALIAS"
PARTITION_PATH="$DEVICE_FOLDER$PARTITION"
DEVICE_MOUNT_FOLDER="$DEVICE_MOUNT_FOLDER$PARTITION"

if [ -n "$UUID" ]; then
	color_echo "[$(date)] $PARTITION_PATH plugged in (UUID=$UUID) !" blue
	if [ -n "$(cat /home/pi/DiskDumper/backup.conf | grep $UUID)" ]; then
		color_echo "$PARTITION_PATH with UUID=\"$UUID\" is registered as backup data device !" yellow
		color_echo "Mounting it to $BACKUP_MOUNT_FOLDER ..." blue

		mkdir -p $BACKUP_MOUNT_FOLDER
		umount $PARTITION_PATH
		mount -t ntfs-3g -o rw $PARTITION_PATH $BACKUP_MOUNT_FOLDER
		check_error 'Mounting failed !'
	
		RIGHTS=$(get_read_write_rights "$PARTITION")
		if [ "$RIGHTS" = "rw" ]; then
			color_echo "Backup disk has read/write rights !" green
		else
			color_echo "Backup disk has read only rights ($RIGHTS), aborting !" red
			exit 1
		fi

		if ! [ -L $BACKUP_ALIAS_PATH ]; then
			ln -s $PARTITION_PATH $BACKUP_ALIAS_PATH
		fi
		
		[ $BACKUP_CONNECTED_LED -eq 1 ] && set_pin_val $BACKUP_CONNECTED_LED_PIN 1

		exit 0
	fi
else
	color_echo "[$(date)] $PARTITION_PATH plugged in (no uuid) !" blue
fi

#check if this is a registered device to sync (with UUID, or label)
if [ -n "$UUID" ]; then #device has UUID
	if [ -z $(cat /home/pi/DiskDumper/sync.conf | grep $UUID) ]; then
		color_echo "$PARTITION_PATH with UUID=\"$UUID\" is not registered for backups !" yellow
		color_echo "Add the UUID to sync.conf if you want to backup this partition." yellow
		exit 0
	else
		color_echo "$PARTITION_PATH with UUID=\"$UUID\" is registered for backups !" yellow
	fi
else #without UUID
	color_echo "Device has no UUID..." red
	color_echo "Trying with label..." blue
	
	if [ -n "$LABEL" ]; then #device has a label
		if [ -z "$(cat /home/pi/DiskDumper/sync.conf | grep $LABEL)" ]; then
			color_echo "$PARTITION_PATH (label=$LABEL) seems not to be registered for backups !" yellow
			color_echo "Add the label to sync.conf if you want to backup this partition." yellow
			exit 0
		else
			color_echo "$PARTITION_PATH (label=$LABEL) seems to be registered for backups !" yellow
		fi
	else #device has no uuid and no label
		color_echo "Device has no label either, aborting !" red
		exit 1
	fi
fi

#wait 120s for mounting the data partition if not already mounted (concurrent execution on boot and hot plug)
if ! [ -L $BACKUP_ALIAS_PATH ]; then
	color_echo "Waiting for data partition to be mounted..." red
	for i in $(seq 1 $MAX_WAITING_TIME); do 
		if [ -L $BACKUP_ALIAS_PATH ]; then
			color_echo "Waited $i seconds !" yellow
			break
		fi

		if [ $i -eq $MAX_WAITING_TIME ]; then
			color_echo "Waited $MAX_WAITING_TIME seconds and the backup disk is still not connected, aborting !" red
			exit 1
		fi

		sleep 1
	done

	#check if device was not removed while waiting...
	if [ -n "$(blkid | grep $PARTITION)" ]; then
		color_echo "Source partition $PARTITION_PATH is still there !" green
	else
		color_echo "Source partition $PARTITION_PATH has been removed while waiting, aborting !" red
	fi
fi




#check if backup disk is connected and mounted
if [ -L $BACKUP_ALIAS_PATH  ]; then
	BACKUP=$(readlink $BACKUP_ALIAS_PATH)
	color_echo "Backup disk $BACKUP_ALIAS_PATH (/dev/$BACKUP) is connected !" green
	RIGHTS=$(get_read_write_rights "$BACKUP")
	if [ "$RIGHTS" = "rw" ]; then
		color_echo "Backup disk has read/write rights !" green
	else
		color_echo "Backup disk has read only rights ($RIGHTS), aborting !" red
		exit 1
	fi

else
	color_echo "Backup disk $BACKUP_ALIAS_PATH is not connected, aborting !" red
	exit 1
fi

#mount source partition
SRC_PATH="$DEVICE_MOUNT_FOLDER/"
ESCAPED_SRC_PATH="\/media\/$PARTITION\/" #TODO
color_echo "Mounting source partition $PARTITION_PATH in read only to $SRC_PATH..." blue

#dirty unmount to be sure noone is using source
umount $PARTITION_PATH > /dev/null 2>&1

#mount in read only, automatic file system
mkdir -p $SRC_PATH
mount -a -v -o ro $PARTITION_PATH $SRC_PATH
check_error 'Failed to mount source partition !'
	
RIGHTS=$(get_read_write_rights "$PARTITION_PATH")
if [ "$RIGHTS" = "ro" ]; then
	color_echo "Source partition has read only rights !" green
else
	color_echo "Source partition has not read only rights ($RIGHTS), aborting !" red
	exit 1
fi

#check if there is anything to copy
FILES=$(find $SRC_PATH -type f 2> /dev/null | xargs)
SRC_COUNT=$(find $SRC_PATH -type f 2> /dev/null | wc -l)

if [ $SRC_COUNT -gt 0 ]; then
	color_echo "Found $SRC_COUNT source files !" yellow
else
	color_echo "No source file found, exciting !" yellow
	exit 0
fi

#look for last directory and create new one
color_echo "Creating destination folder..." blue
FOLDERS=$(find $BACKUP_MOUNT_FOLDER/ -maxdepth 1 -type d 2> /dev/null)
LAST_ID=$(echo $FOLDERS | sed "'s/$(escape_string $BACKUP_MOUNT_FOLDER)//g'" | grep -o '[1-9][0-9]*' | sort -rn | head -1)
	
#if not directory present
if [ -z $LAST_ID ]; then
		LAST_ID=0 #-1 cause bug with upper regex grep
fi

#while for tricky parallel scripts
while true; do 
	NEXT_ID=$((LAST_ID+1))
	DST_PATH="$BACKUP_MOUNT_FOLDER/$(printf '%04d' $NEXT_ID)/"

	if [ $LAST_ID -eq 9999 ]; then
		color_echo "Last folder id was $(printf '%04d' $LAST_ID) !" yellow
		color_echo "Maximum folder number achieved (9999), aborting !" red
		exit 1
	else
		if [ $LAST_ID -gt 0 ]; then
			color_echo "Last folder id was $(printf '%04d' $LAST_ID), creating folder $DST_PATH !" yellow
		else
			color_echo "There was no folders, creating folder $DST_PATH !" yellow
		fi

		if [ -d $DST_PATH ]; then #folder already exists
			LAST_ID=$NEXT_ID
			color_echo "$DST_PATH already exists, trying with $(printf '%04d' $((LAST_ID+1)))/ !" white
		else	
			mkdir $DST_PATH
			check_error 'Error while creating folder !'
			
			DST_COUNT=$(find $DST_PATH -type f 2> /dev/null | wc -l)
			if [ $DST_COUNT -gt 0 ]; then #folders created at the same time by concurrent scripts
				LAST_ID=$NEXT_ID
				color_echo "Files already present in destination, trying with $(printf '%04d' $((LAST_ID+1)))/ !" white
			else
				#all is ok
				break
			fi
		fi
	fi
done

#basic prechecks
if ! [ -d $DST_PATH ]; then
	color_echo "Destination folder $DST_PATH does not exist, aborting !"
	exit 1
fi

if ! [ -d $SRC_PATH ]; then
	color_echo "Source folder $SRC_PATH does not exist, aborting !"
	exit 1
fi

#TODO check size left on device

#copy files
color_echo "Copying files..." blue
rsync -avr $SRC_PATH/* $DST_PATH


#basic postchecks
DST_COUNT=$(find $DST_PATH -type f 2> /dev/null | wc -l)
if [ $DST_COUNT -gt 0 ]; then
	color_echo "Successfully copied $DST_COUNT files !" green
	if [ $DST_COUNT -eq $SRC_COUNT ]; then  
		color_echo "File count ok !" green
	else
		if [ $SRC_COUNT -gt $DST_COUNT ]; then
			color_echo "$((SRC_COUNT - DST_COUNT)) files could not be copied !" red
		else
			color_echo "$((DST_COUNT - SRC_COUNT)) files came from a parallel universe !" red
		fi
	fi
else
	color_echo "No files were copied, aborting !" red
fi

#check integrity
color_echo "Checking integrity..." blue

FILES=$(find $SRC_PATH -type f 2> /dev/null | xargs)
HASHFUNC="sha1sum"

COUNTER=0
VALID_COUNTER=0
CORRUPTED_COUNTER=0
NOT_PRESENT_COUNTER=0
LAST_PERCENT=-1

VALID_LIST=""
CORRUPTED_LIST=""
NOT_PRESENT_LIST=""

for SRC_FILE in $FILES; 
do 
	FILE=$(echo $SRC_FILE | sed 's/'$ESCAPED_SRC_PATH'//g')
	DST_FILE="$DST_PATH$FILE"
	
	PERCENT=$((100*COUNTER/SRC_COUNT))
	if [ $((PERCENT%5)) -eq 0 ] && [ $PERCENT -ne $LAST_PERCENT ]; then
		color_echo "verified $PERCENT% ($COUNTER / $SRC_COUNT)" blue
		LAST_PERCENT=$PERCENT
	fi

	if [ -f $DST_FILE ];
	then 
		HASH1=`$HASHFUNC $SRC_FILE | cut -d ' ' -f 1`
		HASH2=`$HASHFUNC $DST_FILE | cut -d ' ' -f 1`

		if [ "$HASH1" == "$HASH2" ]; then 
			color_echo "$FILE ok !" green
			VALID_COUNTER=$((VALID_COUNTER+1))
			VALID_LIST="$VALID_LIST $SRC_FILE"
		else 
			color_echo "$FILE is corrupted !" red
			color_echo "$HASH1 differs from $HASH2 !" red
			CORRUPTED_COUNTER=$((CORRUPTED_COUNTER+1))
			CORRUPTED_LIST="$CORRUPTED_LIST $SRC_FILE"
		fi
		
	else	
		color_echo "The file $FILE doesn't even exist on destination !" red
		NOT_PRESENT_COUNTER=$((NOT_PRESENT_COUNTER+1))
		NOT_PRESENT_LIST="$NOT_PRESENT_LIST $SRC_FILE"
	fi
		
	COUNTER=$((COUNTER+1))
done;

if [ $LAST_PERCENT -ne 100 ]; then
	color_echo "verified 100% ($COUNTER / $SRC_COUNT)" blue
fi

echo

#check results
color_echo "COPIED FILES : $VALID_COUNTER" green
echo $VALID_LIST
if [ -n "$VALID_COUNTER" ]; then echo; fi

color_echo "CORRUPTED FILES : $CORRUPTED_COUNTER" red
echo $CORRUPTED_LIST
if [ -n "$CORRUPTED_LIST" ]; then echo; fi

color_echo "NOT COPIED FILES : $NOT_PRESENT_COUNTER" red
echo $NOT_PRESENT_LIST
if [ -n "$NOT_PRESENT_LIST" ]; then echo; fi

if [ $VALID_COUNTER -eq $SRC_COUNT ]; then
	color_echo "Cloning successfull !" green
	color_echo "Remounting source in write mode to delete data..." blue

	umount $PARTITION_PATH
	mount -av -o rw $PARTITION_PATH $DEVICE_MOUNT_FOLDER
	check_error "Failed to remount partition, aborting !"

	RIGHTS=$(get_read_write_rights "$PARTITION")
	if [ "$RIGHTS" = "rw" ]; then
		color_echo "Partition got read/write rights !" green
	else
		color_echo "Failed to get read/write rights, aborting !" red
		exit 1
	fi

	color_echo "Deleting data..." blue
	#safe-rm -Rf $DEVICE_MOUNT_FOLDER/* TODO FORMAT
else
	color_echo "There were errors while cloning !" red
fi

color_echo "Cleaning..." blue
umount -v $PARTITION_PATH/
safe-rm -Rf "$DEVICE_MOUNT_FOLDER/"

color_echo "Job done !" yellow

[ $BLINK_PID -gt 0 ] && kill $BLINK_PID > /dev/null #kill LED blinking child process (LED blinking)

exit 0

