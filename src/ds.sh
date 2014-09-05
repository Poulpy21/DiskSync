#!/bin/bash

TIMEFORMAT='%9R'

## INCLUDES ##

DC_HOME='/opt/ds'
SRC_PATH="$DC_HOME/src"
INCLUDE_PATH="$SRC_PATH/include"
DEFAULT_PATH="$SRC_PATH/default"
EVENT_PATH="$SRC_PATH/event"
DEFAULT_VARS="$DEFAULT_PATH/default_vars.sh"
VARS="$INCLUDE_PATH/vars.sh"
UTILS="$INCLUDE_PATH/utils.sh"
HELP="$INCLUDE_PATH/help.sh"
TEST="$INCLUDE_PATH/test.sh"
INSTALL="$INCLUDE_PATH/install.sh"
BENCH="$INCLUDE_PATH/bench.sh"
SHOW="$INCLUDE_PATH/show.sh"
PROCEDURES="$INCLUDE_PATH/procedures.sh"
	
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
include $HELP
include $TEST
include $INSTALL
include $SHOW
include $BENCH
include $PROCEDURES

##(0) define vars ##
VERBOSE=0
DEBUG=0
SHOW=0
INIT=0
BENCH=0
ADD_SRC_ARGS=""
ADD_DST_ARGS=""
REMOVE_SRC_ARGS=""
REMOVE_DST_ARGS=""
SET_ARGS=""
RESET_ARGS=""
TEST_ARGS=""
PRINT_ARGS=""

##(1)parse inputs ##

if [ -z "$1" ]; then
	help
	exit 1
fi

while getopts "vDbShia:A:r:R:s:d:t:p:" opt; do
	case $opt in
		h)
			decho "-h (help) was triggered" 
			help
			exit 0
			;;
		v)
			VERBOSE=1	
			decho "-v (verbose) was triggered" 
			;;
		D)
			DEBUG=1	
			VERBOSE=1
			decho "-D (debug) was triggered (implies verbose mode -v)" 
			;;
		b)
			BENCH=1
			decho "-b (bench) was triggered (implies verbose mode -v)" 
			;;
		S)
			SHOW=1
			decho "-S (show) was triggered" 
			;;
		i)
			INIT=1
			decho "-i (init) was triggered" 
			;;
		r)
			decho "-r (remove source disk) was triggered, Parameter: $OPTARG" 
			[ -z "$OPTARG" ] && warnecho "Option -r needs a non-void argument !" && exit 1
			REMOVE_SRC_ARGS=$(echo -e "$REMOVE_SRC_ARGS\n$OPTARG")
			;;
		R)
			decho "-r (remove destination disk) was triggered, Parameter: $OPTARG" 
			[ -z "$OPTARG" ] && warnecho "Option -R needs a non-void argument !" && exit 1
			REMOVE_DST_ARGS=$(echo -e "$REMOVE_DST_ARGS\n$OPTARG")
			;;
		a)
			decho "-a (add source disk) was triggered, Parameter: $OPTARG" 
			[ -z "$OPTARG" ] && warnecho "Option -a needs a non-void argument !" && exit 1
			ADD_SRC_ARGS=$(echo -e "$ADD_SRC_ARGS\n$OPTARG")
			;;
		A)
			decho "-A (add destination disk) was triggered, Parameter: $OPTARG" 
			[ -z "$OPTARG" ] && warnecho "Option -A needs a non-void argument !" && exit 1
			ADD_DST_ARGS=$(echo -e "$ADD_DST_ARGS\n$OPTARG")
			;;
		s)
			decho "-s (set) was triggered, Parameter: $OPTARG" 
			[ -z "$OPTARG" ] && warnecho "Option -s needs a non-void argument !" && exit 1
			SET_ARGS=$(echo -e "$SET_ARGS\n$OPTARG")
			;;
		d)
			decho "-d (reset to default value) was triggered, Parameter: $OPTARG" 
			[ -z $OPTARG ] && warnecho "Option -d needs a non-void argument !" && exit 1
			RESET_ARGS=$(echo -e "$RESET_ARGS\n$OPTARG")
			;;
		t)
			decho "-t (test) was triggered, Parameter: $OPTARG" 
			[ -z $OPTARG ] && warnecho "Option -t needs a non-void argument !" && exit 1
			TEST_ARGS="$OPTARG"
			;;
		p)
			decho "-p (print) was triggered, Parameter: $OPTARG" 
			[ -z $OPTARG ] && warnecho "Option -p needs a non-void argument !" && exit 1
			PRINT_ARGS=$(echo -e "$PRINT_ARGS\n$OPTARG")
			;;
		\?)
			errecho "Invalid option: -$OPTARG"
			help
			exit 1
			;;
		:)
			errecho "Option -$OPTARG requires an argument."
			exit 1
			;;
	esac
done

decho "VERBOSE = $VERBOSE"
decho "DEBUG = $DEBUG"
decho "SHOW = $SHOW"
decho "BENCH = $BENCH"
decho "INIT = $INIT"
decho "ADD_SRC = $ADD_SRC_ARGS"
decho "ADD_DST = $ADD_DST_ARGS"
decho "REMOVE_SRC = $REMOVE_SRC_ARGS"
decho "REMOVE_DST = $REMOVE_DST_ARGS"
decho "SET = $SET_ARGS"
decho "RESET = $RESET_ARGS"
decho "TEST = $TEST_ARGS"
decho "PRINT = $PRINT_ARGS"

##(2) basic input checks ##

#HELP done previously
#SHOW
[ "$SHOW" -eq 1 ] && decho "Checking show flag conditions..." && ([ "$BENCH" -eq 1 ] || [ "$INIT" -eq 1 ] || [ "$PRINT_ARGS" ] || [ "$TEST_ARGS" ] || [ "$ADD_SRC_ARGS" ] || [ "$ADD_DST_ARGS" ] || [ "$REMOVE_SRC_ARGS" ] || [ "$REMOVE_DST_ARGS" ] || [ "$SET_ARGS" ] || [ "$RESET_ARGS" ]) && errecho "Error too many arguments with option -S (show) !" && help && exit 1
#INIT
[ "$INIT" -eq 1 ] && decho "Checking initialize flag conditions..." && ([ "$BENCH" -eq 1 ] || [ "$SHOW" -eq 1 ] || [ "$PRINT_ARGS" ] || [ "$TEST_ARGS" ] || [ "$ADD_SRC_ARGS" ] || [ "$ADD_DST_ARGS" ] || [ "$REMOVE_SRC_ARGS" ] || [ "$REMOVE_DST_ARGS" ] || [ "$SET_ARGS" ] || [ "$RESET_ARGS" ]) && errecho "Error too many arguments with option -i (initialize) !" && help && exit 1
#PRINT
[ "$PRINT_ARGS" ] && decho "Checking print flag conditions..." && ([ "$BENCH" -eq 1 ] || [ "$SHOW" -eq 1 ] || [ $INIT -eq 1 ] || [ "$TEST_ARGS" ] ) && errecho "Error too many arguments with option -p (print) !" && help && exit 1
#TEST
[ "$TEST_ARGS" ] && decho "Checking test flag conditions..." && ([ "$BENCH" -eq 1 ] || [ "$SHOW" -eq 1 ] || [ "$INIT" -eq 1 ] || [ "$PRINT_ARGS" ] || [ "$ADD_SRC_ARGS" ] || [ "$ADD_DST_ARGS" ] || [ "$REMOVE_SRC_ARGS" ] || [ "$REMOVE_DST_ARGS" ] || [ "$SET_ARGS" ] || [ "$RESET_ARGS" ]) && errecho "Error too many arguments with option -t (test) !" && help && exit 1
#BENCH
[ "$BENCH" -eq 1 ] && decho "Checking bench flag conditions..." && ([ "$INIT" -eq 1 ] || [ "$SHOW" -eq 1 ] || [ "$PRINT_ARGS" ] || [ "$TEST_ARGS" ] || [ "$ADD_SRC_ARGS" ] || [ "$ADD_DST_ARGS" ] || [ "$REMOVE_SRC_ARGS" ] || [ "$REMOVE_DST_ARGS" ] || [ "$SET_ARGS" ] || [ "$RESET_ARGS" ]) && errecho "Error too many arguments with option -b (bench) !" && help && exit 1
#ADD/REMOVE/SET/RESET ARGS no more restrictions at this point


##(3) parse arguments and call funcs##
#ORDER => SHOW || BENCH || INIT || TEST || RESET SET REMOVE_DST ADD_DST REMOVE_SRC ADD_SRC PRINT

#SHOW
[ $SHOW -eq 1 ] && show_connected_devices && exit 0

#INIT
[ $INIT -eq 1 ] && initialize && exit 0

#TEST
[ "$TEST_ARGS" ] && test "$TEST_ARGS" && exit 0

#BENCH
[ $BENCH -eq 1 ] && bench && exit 0

#RESET : '[--all --devices --source --destination --vars VAR]' **semi-colon** separated
for arg_line in $RESET_ARGS; do
	for args in $(echo $arg_line | tr ';' '\n'); do
		case "$args" in
			--all)          reset_all;;
			--devices)      reset_all_devices;;
			--source)       reset_all_source_devices;;
			--destination)  reset_all_destination_devices;;
			--vars)		reset_all_vars;;
			*)		reset_vars "$args";;
		esac
	done
done

#SET : '[--source=LIST; --destination=LIST; VAR=LIST]' **semi-colon** separated, ARG comma separated
for arg_line in $SET_ARGS; do
	for arg in $(echo $arg_line | tr ';' '\n'); do
		case "$arg" in
			--destination=*)  set_destination_devices "$(echo $arg | sed 's/--destination=//g')";;
			--source=*)       set_source_devices "$(echo $arg | sed 's/--source=//g')";;
			*)		  set_var "$arg";;
		esac
	done
done

#ADD/REMOVE DST DISK : '[label/uuid/part]' comma separated
for arg_line in $REMOVE_DST_ARGS; do
	for arg in $(echo $arg_line | tr ',' '\n'); do
		remove_dst_disk "$arg"
	done
done
for arg_line in $ADD_DST_ARGS; do
	for arg in $(echo $arg_line | tr ',' '\n'); do
		add_dst_disk "$arg"
	done
done

#ADD/REMOVE SRC DISK : '[uuid/part]' comma separated
for arg_line in $REMOVE_SRC_ARGS; do
	for arg in $(echo $arg_line | tr ',' '\n'); do
		remove_src_disk "$arg"
	done
done
for arg_line in $ADD_SRC_ARGS; do
	for arg in $(echo $arg_line | tr ',' '\n'); do
		add_src_disk "$arg"
	done
done

#PRINT
if [ "$PRINT_ARGS" ]; then
	for arg in $(echo $PRINT_ARGS | tr ';' '\n'); do
		case "$arg" in
			--all)          print_all;;
			--devices)      print_all_devices;;
			--source)       print_all_source_devices;;
			--destination)  print_all_destination_devices;;
			--vars)		print_all_vars;;
			*)		print_vars "$arg";;
		esac
	done
fi


exit 0
