#!/bin/busybox sh

# Configuration
set -ex

# List of daemon names. Separate by \|, it's put into the regular expression.
DAEMONS='ucollect\|updater\|watchdog\|oneshot'
# Where to put the logs (don't forget the question mark at the end)
BASEURL='https://api.turris.cz/logsend/upload.cgi?'
RID="$(atsha204cmd serial-number)"
CERT="/etc/ssl/startcom.pem"
TMPFILE="/tmp/logsend.tmp"
trap 'rm -f "$TMPFILE"' EXIT

# Don't load the server all at once. With NTP-synchronized time, and
# thousand clients, it would make spikes on the CPU graph and that's not
# nice.
sleep $(( $(tr -cd 0-9 </dev/urandom | head -c 8) % 120 ))

cp /tmp/logs.last.sha1 "$TMPFILE" || true
# Grep regexp: Month date time hostname daemon
# tail ‒ limit the size of upload
(
	cat /var/log/messages.1 || true
	cat /var/log/messages
) | \
	/usr/bin/whatsnew /tmp/logs.last.sha1 | \
	grep "^[^ ][^ ]*  *[0-9][0-9]*  *[0-9:][0-9:]* [^ ][^ ]*  *\($DAEMONS\)\(\[[0-9]*\]\|\):" | \
	tail -n 10000 \
	curl --compress --cacert "$CERT" -T - "$BASEURL$RID" -X POST
mv "$TMPFILE" /tmp/logs.last.sha1
