#!/bin/bash

#ADD
function add_src_disk() {
	vecho "Adding source partition $@..." blue

	if [ -z "$@" ]; then
		errecho "Cannot add a void source partition !"
	fi

	local GREP=$(cat "$BACKUP_CONF_FILE" | grep "$")
	decho "GREP= $GREP"
	if [ -n "$GREP" ]; then
		errecho "$@ is already configurated as a backup device, aborting !"
		exit 1
	fi
	
	local GREP=$(cat "$DEVICES_CONF_FILE" | grep "$@")
	decho "GREP= $GREP"
	if [ -n "$GREP" ]; then
		warnecho "$@ was already configurated as a sync device !"
		return 0
	fi

	echo "$@" >> "$DEVICES_CONF_FILE"
	return 0
}

function add_dst_disk() {
	vecho "Adding destination partition $@..." blue
	
	if [ -z "$@" ]; then
		errecho "Cannot add a void backup partition !"
	fi

	local GREP=$(cat "$DEVICES_CONF_FILE" | grep "$@")
	decho "GREP= $GREP"
	if [ -n "$GREP" ]; then
		errecho "$@ is already configurated as a sync device !"
		exit 1
	fi
	
	local GREP=$(cat "$BACKUP_CONF_FILE" | grep "$@")
	decho "GREP= $GREP"
	if [ -n "$GREP" ]; then
		warnecho "$@ was already configurated as a backup device !"
		return 0
	fi

	echo "$@" >> "$BACKUP_CONF_FILE"
	return 0
}

#REMOVE
function remove_src_disk() {
	vecho "Removing source partition $@..." blue
	
	local PART="$@"
	local PARTS=$(cat "$DEVICES_CONF_FILE" | xargs)
	
	is_in "$PART" "$PARTS"
	if [ $? -eq 1 ]; then
		vecho "Partition $PART is a source partition, deleting..."
		sed -i "/$PART/d" "$DEVICES_CONF_FILE"
	else
		warnecho "Partition $PART is not a source partition, ignoring..."
		return 0
	fi

	return 0
}

function remove_dst_disk() {
	vecho "Removing destination partition $@..." blue
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
		return 0
	fi
	
	decho "OLD_LINE: $LINE"
	decho "NEW_LINE: $NEW_LINE"

	sed -i s/"$LINE"/"$NEW_LINE"/ "$FILE"
}

function reset_all() { 
	vecho "Full reset..." blue
	reset_all_devices
	reset_all_vars
	return 0
}
function reset_all_devices() {
	vecho "Resetting all devices..." blue
	reset_all_destination_devices
	reset_all_source_devices
	return 0
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
	fi

	return 0
}
function reset_all_vars() {
	vecho "Resetting all variables..." blue

	if [ -e "$DEFAULT_VARS" ]; then
		cp "$DEFAULT_VARS" "$VARS"
	else
		errecho "Cannot find the file $DEFAULT_VARS, aborting !"	
		exit 1
	fi

	if ! [ -e "$VARS" ]; then
		errecho "Failed to restore default variables !"
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
	return 0
}
function set_source_devices() {
	vecho "Setting all source devices to $@..." blue
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
		return 0
	else
		decho "$VAR is a known variable !"
	fi

	change_var "$VARS" "$VAR" "$VALUE"

	return 0
}

