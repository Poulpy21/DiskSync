#!/bin/bash

#wrapper to detach and log process
/home/pi/DiskDumper/event.sh "$1" >> /tmp/log_$1 2>&1 &
