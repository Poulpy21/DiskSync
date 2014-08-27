#!/bin/bash

#bash color print ($1=string, $2=color)
function color_echo() {
    local exp=$1;
    local color=$2;
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput setaf $color;
    echo $exp;
    tput sgr0;
}

function is_in() {
	local VAR="$1"
	local LIST="$2"

	if [[ "$LIST" =~ (^| )"$VAR"($| ) ]]; then
		return 1
	else
		return 0
	fi
}

#list paritions (excludes raspberry OS SD card partition)
function get_partitions() {
	lsblk -o NAME | grep -v 'mmcblk0' | grep '└─' | sed 's\└─\\g'
}

#check is partition is mounted ($1=partition)
function is_mounted() {
	local GREP=$(df | grep $1)
	if [ -n "$GREP" ]; then
		return 1
	else
		return 0 
	fi
}

function get_uuid() {
	blkid | grep "$1" | xargs -n 1 | grep 'UUID' | cut -d'=' -f2
}

function get_label() {
	blkid | grep "$1" | grep -o 'LABEL="[a-zA-Z0-9_-]*"' | cut -d'"' -f2
}

#get total partition size ($1=partition name, [$2=dh flags])
function get_tot_size() {
	df $2 | grep $1 | xargs -n 1 | xargs | cut -d' ' -f4
}

#get used partition size ($1=partition name, [$2=dh flags])
function get_used_size() {
	df $2 | grep $1 | xargs -n 1 | xargs | cut -d' ' -f3
}

#get used partition size in % ($1=partition name, [$2=dh flags])
function get_used_percent() {
	df $2 | grep $1 | xargs -n 1 | xargs | cut -d' ' -f5 | sed 's/%//g'
}

#get mount location ($1=partition name)
function get_mount_location() {
	df | grep $1 | xargs -n 1 | tail -1
}

#get read/write partition flag ($1=partition name)
function get_read_write_rights() {
	cat /proc/mounts | grep $1 | xargs -n 1 | tail -3 | head -1 | cut -d, -f1
}

#check last error return code, print message and exit if error ($1=message)
function check_error() {
	if [ $? -ne 0 ]; then
		color_echo "$0" red
		exit 1;
	fi
}

#escape '/' into '\/' in input string $@
function escape_string() {
	echo "$@" | sed 's/\//\\\//g'
}

#safe raspberry gpio LED IO settingn, !SLOW! ($1=BCM PIN NUMBER, $2=VALUE)
function set_pin_val() {
	gpio -g mode $1 out
	gpio -g write $1 $2
}

#raspberry gpio LED blinking ($1=BCM PIN NUMBER)
function blink() {
	gpio -g mode $1 out
		
	while true; do
		gpio -g write $1 0
		sleep "$2s"
		gpio -g write $1 1
		sleep "$2s"
	done
}


#VERBOSE PRINT
function vecho() {
	if [ $VERBOSE -eq 1 ]; then
		color_echo "$1" "$2"
	fi
}

#DEBUG PRINT
function decho() {
	if [ $DEBUG -eq 1 ]; then
		color_echo "$1" "$2"
	fi
}

#ERROR PRINT
function errecho() {
	color_echo "$@" red 1>&2;
	exit 1
}

#WARN PRINT
function warnecho() {
	color_echo "$@" yellow 1>&2;
}
