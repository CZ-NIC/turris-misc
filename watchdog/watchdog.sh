#!/bin/sh

# Copyright (c) 2013, CZ.NIC
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the CZ.NIC nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL CZ.NIC BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
