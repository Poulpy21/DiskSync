#!/bin/bash

#Test a partition
function show_connected_devices() {
	vecho "Showing connected devices !"
	
	color_echo "Backup devices :" yellow
	for dev in $(cat $BACKUP_CONF_FILE); do
		decho "Checking if $dev is connected..."
		local GREP=$(blkid | grep "$dev")
		if [ "$GREP" ]; then
			color_echo "$GREP is connected" green
		else
			color_echo "$dev is not connected" red
		fi
	done
	
	echo
	color_echo "Registered devices :" yellow
	for dev in $(cat $DEVICES_CONF_FILE); do
		decho "Checking if $dev is connected..."
		local GREP=$(blkid | grep "$dev")
		if [ "$GREP" ]; then
			color_echo "$GREP is connected" green
		else
			color_echo "$dev is not connected" red
		fi
	done

	echo
	color_echo "Other connected devices :" yellow
	for dev in $(blkid | tr ' ' '$'); do
		local PRINT=1
		decho "Checking connected device $dev ..."
		for backup_dev in $(cat $BACKUP_CONF_FILE); do
			local GREP=$(echo "$dev" | grep "$backup_dev")
			if [ -n "$GREP" ]; then
				local PRINT=0
				break
			fi
		done
		for sync_dev in $(cat $DEVICES_CONF_FILE); do
			local GREP=$(echo "$dev" | grep "$sync_dev")
			if [ -n "$GREP" ]; then
				local PRINT=0
				break
			fi
		done
		[ $PRINT -eq 1 ] && echo $dev | tr '$' ' '
	done
	

}

