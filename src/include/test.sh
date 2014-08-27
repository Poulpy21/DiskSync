#!/bin/bash

#Test a partition
function test() {
	PARTITION=$1

	echo "Testing partition $PARTITION !"

	echo "Filling partition with random data files !"
	umount /dev/$PARTITION
	mkdir -p tmp
	mount -a -o rw /dev/$PARTITION tmp/

	for i in {1..5}; do
		dd if=/dev/urandom of=tmp/file_$i bs=1M count=1
	done

	umount /dev/$PARTITION
	safe-rm -Rf tmp/

	echo "Launch copy script !"
	echo
	echo
	#./event.sh $PARTITION

	exit 0
}

