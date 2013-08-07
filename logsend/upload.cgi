#!/bin/sh

# Yes, a CGI script in shell. It's simple enough not to matter. We just need to escape stuff properly.

LOGDIR=/var/log/routers/

CLIENT_ID="$QUERY_STRING"
# Some little validation
if "$REQUEST_METHOD" != "POST" ; then
	echo 'Status: 501 Not Implemented'
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

# OK, this is not completely safe. If two requests from the same client came at the same time,
# we could get garbled output. But that won't happen in practice and the damage would be
# negligible anyway.
cat >> "$CLIENT_ID".log

# I have no words.
echo '204: No Content'
echo
