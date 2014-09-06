#!/bin/bash

#wrapper to detach and log process
/opt/ds/src/event/event.sh "$1" >> "/tmp/log_$1" 2>&1 &
