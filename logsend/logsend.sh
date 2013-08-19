#!/bin/busybox sh

# Configuration

# List of daemon names. Separate by \|, it's put into the regular expression.
DAEMONS='ucollect\|updater\|watchdog'
# Where to put the logs (don't forget the question mark at the end)
BASEURL='https://securt-test.labs.nic.cz/logsend/upload.cgi?'
RID="$(atsha204cmd serial-number)"
CERT="/etc/ssl/startcom-cznic.pem"

# Grep regexp: Month date time hostname something.something daemon
logread | \
	/usr/bin/whatsnew /tmp/logs.last.sha1 | \
	grep "^[^ ][^ ]*  *[0-9][0-9]*  *[0-9:][0-9:]* [^ ][^ ]* [a-z][a-z]*\.[a-z][a-z]* \($DAEMONS\)\(\[[0-9]*\]\|\):" | \
	curl -k --cacert "$CERT" -T - "$BASEURL$RID" -X POST
