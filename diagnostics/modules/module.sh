#!/bin/sh
. "$1"

case "$2" in
	help)
		# remove first and last newline
		newline="
"
		help=${help##$newline}
		help=${help%%$newline}
		echo "$help"
		;;
	run)
		run
		;;
esac
