#!/bin/bash

#Test a partition
function test() {
	PARTITION="$1"
	DEVICE="$DEVICE_FOLDER$PARTITION" 
	DIR="$DEVICE_MOUNT_FOLDER$PARTITION"

	echo "Testing partition $DEVICE !"

	umount "$DEVICE"
	mkdir -p "$DIR"
	mount -a -o rw "$DEVICE" "$DIR"

	FILES=$(find $DIR -type f)
	if [ "$FILES" ]; then
		echo "Partition has data, skipping data generation."
	else
		echo "Partition has no data, filling partition with random data files !"

		for i in {1..5}; do
			dd if=/dev/urandom of="$DIR/file_$i" bs=1M count=1
		done
	fi

	umount $DEVICE
	safe-rm -Rf $DIR

	echo "Launch copy script !"
	echo
	echo
	$EVENT_PATH/event.sh $PARTITION

	exit 0
}

