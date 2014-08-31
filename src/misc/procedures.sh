#!/bin/bash

function guess_partitions() {

	echo "Checking available partitions..."
	lsblk -o NAME,TYPE,FSTYPE,LABEL,MOUNTPOINT

	echo "Guessing partitions..."
	local PARTITIONS=$(get_partitions)
	local PART_1=$(echo "$PARTITIONS" | head -1)
	local PART_2=$(echo "$PARTITIONS" | tail -1)

	#silent mount to check size
	mount -a -o ro /dev/$PART_1 $SRC_DIR/ > /dev/null 2>&1
	mount -a -o ro /dev/$PART_2 $DST_DIR/ > /dev/null 2>&1

	local TOT_SIZE_1=$(get_tot_size $PART_1) 
	local USED_SIZE_1=$(get_used_size $PART_1) 
	local USED_PERCENT_1=$(get_used_percent $PART_1)

	local USED_SIZE_2=$(get_used_size $PART_2) 
	local TOT_SIZE_2=$(get_tot_size $PART_2) 
	local USED_PERCENT_2=$(get_used_percent $PART_2)

	umount /dev/$PART_1
	umount /dev/$PART_2

	color_echo "/dev/$PART_1 tot_size=$TOT_SIZE_1 used_size=$USED_SIZE_1  $USED_PERCENT_1%" blue
	color_echo "/dev/$PART_2 tot_size=$TOT_SIZE_2 used_size=$USED_SIZE_2  $USED_PERCENT_2%" blue

	if [ $USED_PERCENT_2 -gt $USED_PERCENT_1 ]; then
		if [ $USED_SIZE_2 -gt $TOT_SIZE_1 ]; then
			echo "$PART_2 can't be the source partition (not enough space on $PART_1) !"
			if [ $USED_SIZE_1 -gt $TOT_SIZE_2 ]; then #impossible but rather check
				echo "$PART_1 can't be the source partition (not enough space on $PART_2) !"
				color_echo "The impossible happened !" red
				exit 1
			else
				SRC_PART=$PART_1
				DST_PART=$PART_2
			fi
		else
			SRC_PART=$PART_2
			DST_PART=$PART_1
		fi
	else
		if [ $USED_SIZE_1 -gt $TOT_SIZE_2 ]; then
			echo "$PART_1 can't be the source partition (not enough space on $PART_2) !"
			if [ $USED_SIZE_2 -gt $TOT_SIZE_1 ]; then #impossible but rather check
				echo "$PART_2 can't be the source partition (not enough space on $PART_1) !"
				color_echo "The impossible happened !" red
				exit 1
			else
				SRC_PART=$PART_2
				DST_PART=$PART_1
			fi
		else
			SRC_PART=$PART_1
			DST_PART=$PART_2
		fi
	fi

	echo -e "Source partition will be \e[1m\e[31m$SRC_PART\e[0m"
	echo -e "Destination partition will be \e[1m\e[31m$DST_PART\e[0m"
}

function mount_and_check_flags() {
	echo "Mounting partitions..."

	#mount source partition
	local SRC_MOUNT_LOCATION=$(get_mount_location $SRC_PART)

	if [ $SRC_MOUNT_LOCATION != "/" ]; then #already mounted
		echo "Partition /dev/$SRC_PART is already mounted, unmounting..."
		umount -v /dev/$SRC_PART
	fi

	echo "Mounting /dev/$SRC_PART to $WORKING_DIRECTORY/$SRC_DIR in read only..."
	mount -a -o ro /dev/$SRC_PART $WORKING_DIRECTORY/$SRC_DIR
	check_error 'Failed to mount source partition !'

	#mount destination partition
	local DST_MOUNT_LOCATION=$(get_mount_location $DST_PART)

	if [ $DST_MOUNT_LOCATION != "/" ]; then #already mounted
		echo "Partition /dev/$DST_PART is already mounted, unmounting..."
		umount -v /dev/$DST_PART
	fi

	echo "Mounting /dev/$DST_PART to $WORKING_DIRECTORY/$DST_DIR in read only..."
	mount -a -o rw /dev/$DST_PART $WORKING_DIRECTORY/$SDST_DIR
	check_error "Failed to mount destination partition !"
}

function check_input() {
	while [ "$CONTINUE" != "yes" ] && [ "$CONTINUE" != "no" ]; do
		color_echo "Are you sure you want to continue ? [yes/no] " yellow
		read CONTINUE
	done;

	if [ "$CONTINUE" == "no" ]; then
		color_echo "User stopped program !" red
		exit 0
	fi

	if ! [ -d $SRC_DIR ]; then
		color_echo "Source directory '$SRC_DIR' does not exist !" red
		exit 1
	fi

	if ! [ -d $DST_DIR ]; then
		color_echo "Destination directory '$DST_DIR' does not exist !" red
		exit 1
	fi
}
