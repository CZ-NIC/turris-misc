#!/bin/sh

set -e

exit 1 # See below
SALT='<enter-some-salt-here-when-deploying>'

echo 'Content-Type: text/plain; charset=ascii'
echo ''

(
	echo "$SALT"
	date +%d%m%y
	echo "$SALT"
) | sha256sum | cut -f1 -d\ 
