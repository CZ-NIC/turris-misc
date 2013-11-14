#!/bin/sh

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
if echo "$CLIENT_ID" | grep -q '[^0-9a-fA-F]' ; then
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
