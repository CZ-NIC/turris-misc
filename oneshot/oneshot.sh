#!/bin/busybox sh

set -ex

SCRIPT_DIR=/usr/share/oneshot/scripts
COMPLETED_DIR=/usr/share/oneshot/completed

mkdir -p "$COMPLETED_DIR"

ls "$SCRIPT_DIR" | sort | while read SCRIPT ; do
	if [ ! -f "$COMPLETED_DIR/$SCRIPT" ] ; then
		echo "Running one-shot script $SCRIPT" | logger -t oneshot -p user.info
		if ! "$SCRIPT_DIR/$SCRIPT" ; then
			echo "Failed to execute $SCRIPT" | logger -t oneshot -p user.err
			# Busybox's sh doesn't work well with exit. Use this instead.
			kill -SIGABRT $$
		fi
		touch "$COMPLETED_DIR/$SCRIPT"
		echo "Script $SCRIPT comlete" | logger -t oneshot -p user.info
	fi
done
