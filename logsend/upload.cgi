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

# Yes, a CGI script in shell. It's simple enough not to matter. We just need to escape stuff properly.

LOGDIR=/var/log/routers/current/
AUTHENTICATOR=localhost:8888

CLIENT_ID="$QUERY_STRING"
# Some little validation
if [ "$REQUEST_METHOD" != "POST" ] ; then
	echo 'Status: 405 Method Not Allowed'
	echo
	exit
fi

# That doesn't look like client ID (a hexadecimal number). That is likely attempt to trick us
# to overwrite some unrelated files. Of course we refuse to do that.
if [ -z "$CLIENT_ID" ] || echo "$CLIENT_ID" | grep -q '[^0-9a-fA-F]' ; then
	echo 'Status: 403 Forbidden'
	echo
	exit
fi

cd "$LOGDIR"

read SIGNATURE
TMPFILE=
trap 'rm -f "$TMPFILE"' EXIT ABRT QUIT TERM
TMPFILE="$(tempfile)"
cat >"$TMPFILE"
HASH="`sha256sum "$TMPFILE" | cut -f1 -d\ `"
OK="`(echo AUTH "$CLIENT_ID" "$HASH" "$SIGNATURE" ; echo QUIT ) |  socat STDIO TCP-CONNECT:$AUTHENTICATOR`"

if [ "$OK" != "YES" ] ; then
	# Any idea for better status code? 401 Unauthorized would be nice, but it requires
	# a header with challenge sent back. 403 Forbidden is not right either, because
	# it says authentication will make no difference, but it will.
	echo 'Status: 409 Conflict'
	echo
	echo "Bad auth from $CLIENT_ID" >&2
	exit
fi

# OK, this is not completely safe. If two requests from the same client came at the same time,
# we could get garbled output. But that won't happen in practice and the damage would be
# negligible anyway.
cat "$TMPFILE" >> "$CLIENT_ID".log

# I have no words.
echo '204: No Content'
echo
