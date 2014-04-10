#!/bin/busybox sh

# Copyright (c) 2013-2014, CZ.NIC, z.s.p.o. (http://www.nic.cz/)
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

# Configuration
set -ex

# List of daemon names. Separate by \|, it's put into the regular expression.
DAEMONS='ucollect\|updater\|watchdog\|oneshot\|nikola\|nethist'

BRANCH=$(getbranch || echo 'unknown')

if [ "$BRANCH" = "test" -o "$BRANCH" = "master" ] ; then
	# We are using one of the development branches here. Therefore we send
	# slightly more logs than usual.
	DAEMONS="$DAEMONS"'\|updater-user\|updater-consolidator'
fi
# Where to put the logs (don't forget the question mark at the end)
BASEURL='https://api.turris.cz/logsend/upload.cgi?'
RID="$(atsha204cmd serial-number)"
CERT="/etc/ssl/startcom.pem"
CRL="/etc/ssl/crl.pem"
TMPFILE="/tmp/logsend.tmp"
BUFFER="/tmp/logsend.buffer"
trap 'rm -f "$TMPFILE" "$BUFFER"' EXIT ABRT QUIT TERM

# Don't load the server all at once. With NTP-synchronized time, and
# thousand clients, it would make spikes on the CPU graph and that's not
# nice.
sleep $(( $(tr -cd 0-9 </dev/urandom | head -c 8 | sed -e 's/^0*//' ) % 120 ))

cp /tmp/logs.last.sha1 "$TMPFILE" || true
# Grep regexp: Month date time hostname daemon
# tail ‒ limit the size of upload
(
	cat /var/log/messages.1 || true
	cat /var/log/messages
) | \
	/usr/bin/whatsnew "$TMPFILE" | \
	grep "^[^ ][^ ]* *[a-z][a-z]* *\($DAEMONS\)\(\[[0-9]*\]\|\):" | \
	tail -n 10000 >"$BUFFER"

(
	atsha204cmd file-challenge-response <"$BUFFER"
	cat "$BUFFER"
) | curl --compress --cacert "$CERT" --crlfile "$CRL" -T - "$BASEURL$RID" -X POST -f
mv "$TMPFILE" /tmp/logs.last.sha1
