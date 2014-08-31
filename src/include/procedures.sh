#!/bin/bash

#ADD
function add_src_disk() {
	vecho "Adding source partition $@..." blue

	if [ -z "$@" ]; then
		errecho "Cannot add a void source partition !"
	fi
	
	local PART="$@"
	local SYNC_PARTS=$(cat "$DEVICES_CONF_FILE")
	local BACKUP_PARTS=$(cat "$BACKUP_CONF_FILE")
	decho "PART $PART"
	decho "SYNC_PARTS $SYNC_PARTS"
	decho "BACKUP_PARTS $BACKUP_PARTS"
	
	is_in "$PART" "$BACKUP_PARTS"
	if [ $? -eq 1 ]; then
		errecho "$@ is already configurated as a backup device, aborting !"
		exit 1
	fi
	
	is_in "$PART" "$SYNC_PARTS"
	if [ $? -eq 1 ]; then
		warnecho "$@ was already configurated as a sync device !"
		return 1
	fi

	echo "$PART" >> "$DEVICES_CONF_FILE"
	return 0
}

function add_dst_disk() {
	vecho "Adding destination partition $@..." blue

	if [ -z "$@" ]; then
		errecho "Cannot add a void backup partition !"
	fi

	local PART="$@"
	local SYNC_PARTS=$(cat "$DEVICES_CONF_FILE")
	local BACKUP_PARTS=$(cat "$BACKUP_CONF_FILE")
	decho "PART $PART"
	decho "SYNC_PARTS $SYNC_PARTS"
	decho "BACKUP_PARTS $BACKUP_PARTS"

	is_in "$PART" "$SYNC_PARTS"
	if [ $? -eq 1 ]; then
		errecho "$@ is already configurated as a sync device !"
		exit 1
	fi
	
	is_in "$PART" "$BACKUP_PARTS"
	if [ $? -eq 1 ]; then
		warnecho "$@ was already configurated as a backup device !"
		return 1
	fi

	echo "$PART" >> "$BACKUP_CONF_FILE"
	return 0
}

#REMOVE
function remove_src_disk() {
	vecho "Removing source partition $@..." blue
	
	local PART="$@"
	local PARTS=$(cat "$DEVICES_CONF_FILE" | xargs)
	
	decho "PART=$PART"
	decho "PARTS=$PARTS"

	is_in "$PART" "$PARTS"
	if [ $? -eq 1 ]; then
		vecho "Partition $PART is a source partition, deleting..."
		sed -i "/$PART/d" "$DEVICES_CONF_FILE"
	else
		warnecho "Partition $PART is not a source partition, ignoring..."
		return 1
	fi

	return 0
}

function remove_dst_disk() {
	vecho "Removing destination partition $@..." blue
	
	local PART="$@"
	local PARTS=$(cat "$BACKUP_CONF_FILE" | xargs)
	
	decho "PART=$PART"
	decho "PARTS=$PARTS"

	is_in "$PART" "$PARTS"
	if [ $? -eq 1 ]; then
		vecho "Partition $PART is a backup partition, deleting..."
		sed -i "/$PART/d" "$BACKUP_CONF_FILE"
	else
		warnecho "Partition $PART is not a destination partition, ignoring..."
		return 1
	fi

	return 0
}

#RESET
function change_var() {
	local FILE=$1
	local VAR=$2
	local VALUE=$3

	local LINE=$(cat "$FILE" | grep "$VAR=")
	local NEW_LINE="$VAR=$VALUE"

	if [ -z "$LINE" ]; then
		warnecho "$VAR not found in file $FILE, ignoring !"
		return 1
	fi
	
	decho "OLD_LINE: $LINE"
	decho "NEW_LINE: $NEW_LINE"

	sed -i s/"$LINE"/"$NEW_LINE"/ "$FILE"

	return 0
}

function print_all() {
	vecho "Full print..." blue
	print_all_devices
	print_all_vars
	return $?
}
function print_all_devices() {
	vecho "Printing all devices..." blue
	print_all_destination_devices
	print_all_source_devices
	return $?
}
function print_all_destination_devices() {
	vecho "Printing all destination devices..." blue

	if [ -e "$BACKUP_CONF_FILE" ]; then
		cat "$BACKUP_CONF_FILE"
	else
		errecho "Failed to open configuration file $BACKUP_CONF_FILE !"
		exit 1
	fi

	return 0
}
function print_all_source_devices() {
	vecho "Printing all source devices..." blue

	if [ -e "$DEVICES_CONF_FILE" ]; then
		cat "$DEVICES_CONF_FILE"
	else
		errecho "Failed to open configuration file $DEVICES_CONF_FILE !"
		exit 1
	fi

	return 0
}
function print_all_vars() {
	vecho "Printing all variables..." blue

	if [ -e "$VARS" ]; then
		cat "$VARS"
	else
		errecho "Failed to open file $VARS !"
		exit 1
	fi

	return 0
}

function print_vars() {
	vecho "Printing variable $@..." blue

	for arg in $@; do 
		local VAR_NAMES=$(cat "$DEFAULT_VARS" | grep -o '[A-Z_]\+=' | sed 's/=//g' | xargs)

		if ! [[ $VAR_NAMES =~ (^| )$arg($| ) ]]; then
			warnecho "$arg is not a known variable, ignoring !"
			return 1
		else
			decho "$arg is a known variable !"
			cat "$VARS" | grep "$arg="
		fi
	done

	return 0
}

function reset_all() { 
	vecho "Full reset..." blue
	reset_all_devices
	reset_all_vars
	return $?
}
function reset_all_devices() {
	vecho "Resetting all devices..." blue
	reset_all_destination_devices
	reset_all_source_devices
	return $?
}
function reset_all_destination_devices() {
	vecho "Resetting all destination devices..." blue

	[ -e "$BACKUP_CONF_FILE" ] && rm "$BACKUP_CONF_FILE" && vecho "Deleted configuration file $BACKUP_CONF_FILE !"
	[ -e "$BACKUP_CONF_FILE" ] && errecho "Failed to delete file $BACKUP_CONF_FILE !"
	
	touch "$BACKUP_CONF_FILE"

	if [ -e "$BACKUP_CONF_FILE" ]; then
		vecho "Created file $BACKUP_CONF_FILE !"
	else
		errecho "Failed to create file $BACKUP_CONF_FILE !"
		exit 1
	fi

	return 0
}
function reset_all_source_devices() {
	vecho "Resetting all source devices..." blue

	[ -e "$DEVICES_CONF_FILE" ] && rm "$DEVICES_CONF_FILE" && vecho "Deleted configuration file $DEVICES_CONF_FILE !"
	[ -e "$DEVICES_CONF_FILE" ] && errecho "Failed to delete file $DEVICES_CONF_FILE !"
	
	touch "$DEVICES_CONF_FILE"

	if [ -e "$DEVICES_CONF_FILE" ]; then
		vecho "Created file $DEVICES_CONF_FILE !"
	else
		errecho "Failed to create file $DEVICES_CONF_FILE !"
		exit 1
	fi

	return 0
}
function reset_all_vars() {
	vecho "Resetting all variables..." blue

	if [ -e "$DEFAULT_VARS" ]; then
		if [ -e "$VARS" ]; then
			rm "$VARS"
			if [ -e "$VARS" ]; then
				errecho "Failed to delete file $VARS !"
			fi
		fi

		cp "$DEFAULT_VARS" "$VARS"
	
		if ! [ -e "$VARS" ]; then
			errecho "Failed to restore default variables !"
			exit 1
		fi	
	else
		errecho "Cannot find the file $DEFAULT_VARS, aborting !"	
		exit 1
	fi

	return 0
}
function reset_vars() {
	vecho "Resetting variables $@..." blue

	local VAR_NAMES=$(cat "$DEFAULT_VARS" | grep -o '[A-Z_]\+=' | sed 's/=//g' | xargs)
	
	for VAR in $(echo $@ | tr ',' '\n'); do
		vecho "Resetting $VAR..."

		if ! [[ $VAR_NAMES =~ (^| )$VAR($| ) ]]; then
			warnecho "$VAR is not a known variable, ignoring !"
			continue
		fi

		local DEFAULT_VALUE=$(cat "$DEFAULT_VARS" | grep "$VAR=" | sed s/"$VAR="//g)
		decho "$VAR is a known variable, default value is $DEFAULT_VALUE !"

		change_var "$VARS" "$VAR" "$DEFAULT_VALUE"
	done
	return 0
}

#SET
function set_destination_devices() {
	vecho "Setting all destination devices to $@..." blue

	if [ -e "$BACKUP_CONF_FILE" ]; then
		rm "$BACKUP_CONF_FILE"
		if [ -e "$BACKUP_CONF_FILE" ]; then
			errecho "Failed to delete file $BACKUP_CONF_FILE !"
		fi
	fi

	touch "$BACKUP_CONF_FILE"
	if ! [ -e "$BACKUP_CONF_FILE" ]; then
		errecho "Failed to create file $BACKUP_CONF_FILE !"
	fi
	
	for part in $(echo "$@" | sed "s/,/\n/g"); do
		vecho "Adding destination device $part !"
		echo "$part" >> "$BACKUP_CONF_FILE"
	done

	return 0
}

function set_source_devices() {
	vecho "Setting all source devices to $@..." blue

	if [ -e "$DEVICES_CONF_FILE" ]; then
		rm "$DEVICES_CONF_FILE"
		if [ -e "$DEVICES_CONF_FILE" ]; then
			errecho "Failed to delete file $DEVICES_CONF_FILE !"
		fi
	fi

	touch "$DEVICES_CONF_FILE"
	if ! [ -e "$DEVICES_CONF_FILE" ]; then
		errecho "Failed to create file $DEVICES_CONF_FILE !"
	fi
	
	for part in $(echo "$@" | sed "s/,/\n/g"); do
		vecho "Adding destination device $part !"
		echo "$part" >> "$DEVICES_CONF_FILE"
	done

	return 0
}

function set_var() {
	vecho "Setting variable $@..." blue
	if [ -z "$(echo "$@" | grep '=')" ]; then
		vecho "Can not parse variable $@ (wrong format) !"
		vecho "Try with VAR=value !"
		warnecho "Ignoring variable set $@ (syntax error)!" 
	fi
	
	local VAR=$(echo "$arg" | cut -d'=' -f1)
	local VALUE=$(echo "$arg" | cut -d'=' -f2)
	local VAR_NAMES=$(cat "$DEFAULT_VARS" | grep -o '[A-Z_]\+=' | sed 's/=//g' | xargs)

	if ! [[ $VAR_NAMES =~ (^| )$VAR($| ) ]]; then
		warnecho "$VAR is not a known variable, ignoring !"
		return 1
	else
		decho "$VAR is a known variable !"
	fi

	change_var "$VARS" "$VAR" "$VALUE"

	return 0
}

