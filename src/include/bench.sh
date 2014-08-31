#!/bin/bash

#Hashfunc bench function

function bench() {
	vecho "Bench script !"
	
	local FUNCS="sha1sum sha224sum sha256sum sha384sum sha512sum cksum crc32"
	
	mkdir tmp

	for i in {2..4}; do
		echo "Creating 10x$((2**$i))M files..."
		for j in {1..10}; do
			dd if=/dev/urandom of="tmp/sample${i}_$j" bs=$((2**$i))M count=1 > /dev/null 2>&1
		done
	done

	for func in $FUNCS; do
		color_echo "Benching $func..." blue
		for i in {2..4}; do

			if [ $VERBOSE -eq 1 ]; then
				exec 3>&1
			else 
				exec 3>/dev/null
			fi 

			local TIME=$( (time sha1sum tmp/sample${i}_* 1>&3 2>&3) 2>&1 )

			exec 3>&-

			echo "$((2**$i))M : $TIME"
		done
	done

	safe-rm -Rf tmp

	return 0
}

