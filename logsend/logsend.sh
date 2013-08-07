#!/bin/busybox sh

# Configuration

# List of daemon names. Separate by \|, it's put into the regular expression.
DAEMONS='ucollect\|updater\|watchdog'
# Where to put the logs (don't forget the question mark at the end)
BASEURL='http://securt-test.labs.nic.cz/logsend/upload.cgi?'
# TODO: Get the router ID
RID=12345

# Grep regexp: Month date time hostname something.something daemon
logread | \
	grep "^[^ ][^ ]*  *[0-9][0-9]*  *[0-9:][0-9:]* [^ ][^ ]* [a-z][a-z]*\.[a-z][a-z]* \($DAEMONS\)\(\[[0-9]*\]\|\):" | \
	curl -T - "$BASEURL$RID" -X POST
