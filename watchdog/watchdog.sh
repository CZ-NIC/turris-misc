#!/bin/sh

set -ex

# Configuration
SERVICES="ucollect nethist"
TEMPFILE=/tmp/watchdog.tmp.$$

trap 'rm "$TEMPFILE"' EXIT INT QUIT TERM

# Grap current list of processes, strip off the header and keep only the first and last column.
# Seems like our ps doesn't know how to specify format, so we have to get through the
# human-friendly crap
ps | tail -n+2 | sed -e 's/^ *\([0-9][0-9]*\)\(  *[^ ]*\)\{3\} */\1 /'>"$TEMPFILE"

for SERVICE in $SERVICES ; do
	# Get the claimed PID of the service
	PID=`cat /var/run/"$SERVICE".pid || echo 'No such PID available'`
	FILE=/tmp/watchdog-"$SERVICE"-missing
	# Look if there's a process with such name and PID in as reliable way as shell allows
	if grep "^$PID " "$TEMPFILE" | sed -e 's/^[^ ]*//' | grep "$SERVICE">/dev/null ; then
		# It runs. Remove any possible missing note from previous run.
		rm -f "$FILE"
	else
		if test -f "$FILE" ; then
			# It is not there and was not there the previous time. Restart.
			if /etc/init.d/"$SERVICE" restart ; then
				echo "Restarted $SERVICE" | logger -t watchdog -p daemon.warn
			else
				echo "Failed to restart $SERVICE" | logger -t watchdog -p daemon.err
			fi
			rm -f "$FILE"
		else
			# It was here previously, but it is not here now. Note it is
			# missing (it may be temporary state, in the middle of upgrade,
			# for example.
			touch "$FILE"
		fi
	fi
done
