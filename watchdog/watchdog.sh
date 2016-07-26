#!/bin/busybox ash

# Copyright (c) 2013-2015, CZ.NIC, z.s.p.o. (http://www.nic.cz/)
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
COND_SERVICES="nethist lcollect resolver ucollect"
SERVICES=""
for S in $COND_SERVICES ; do
	if test -x "/etc/init.d/$S" && "/etc/init.d/$S" enabled ; then
		SERVICES="$SERVICES $S"
	fi
done
TEMPFILE=/tmp/watchdog.tmp.$$

trap 'rm "$TEMPFILE"' EXIT INT QUIT TERM

# Grab current list of processes, strip off the header and keep only the first and last column.
# Seems like our ps doesn't know how to specify format, so we have to get through the
# human-friendly crap
busybox ps | tail -n+2 | sed -e 's/^ *\([0-9][0-9]*\)\(  *[^ ]*\)\{3\} */\1 /'>"$TEMPFILE"

for SERVICE in $SERVICES ; do
	# Get the claimed PID of the service
	PID=`cat /var/run/"$SERVICE".pid || echo 'No such PID available'`
	FILE=/tmp/watchdog-"$SERVICE"-missing
	EXTRA=true # In case unbound/kresd is running but not working, try to reset it
	if [ "$SERVICE" = "resolver" ] ; then
		if ! ping -c 2 turris.cz ; then
			EXTRA=false
		fi
	fi
	# Look if there's a process with such name and PID in as reliable way as shell allows
	if grep "^$PID " "$TEMPFILE" | sed -e 's/^[^ ]*//' | grep "$SERVICE">/dev/null && $EXTRA ; then
		# It runs. Remove any possible missing note from previous run.
		rm -f "$FILE"
	else
		if test -f "$FILE" ; then
			# It is not there, but we are forbidden from restarting it
			if uci get -q -d '
' watchdog.@services[0].norestart | grep -q -x -F "$SERVICE" ; then
				echo "Service $SERVICE not restarted as it is disabled in config" | logger -t watchdog -p daemon.info
			# It is not there and was not there the previous time. Restart.
			elif /etc/init.d/"$SERVICE" restart ; then
				echo "Restarted $SERVICE" | logger -t watchdog -p daemon.warn
				rm -f "$FILE"
			else
				echo "Failed to restart $SERVICE" | logger -t watchdog -p daemon.err
			fi
		else
			# It was here previously, but it is not here now. Note it is
			# missing (it may be temporary state, in the middle of upgrade,
			# for example.
			touch "$FILE"
		fi
	fi
done
