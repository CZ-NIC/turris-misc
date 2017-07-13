#!/bin/sh
set -ex

MODEL=omnia
BRANCH=
while [ $# -gt 0 ]; do
	case "$1" in
		--version)
			shift
			VERSION="$1"
			;;
		--model)
			shift
			MODEL="$1"
			;;
		--branch)
			shift
			BRANCH="$1"
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
	shift
done

if [ -z "$VERSION" ]; then
	echo "Missing --version argument!" >&2
	exit 1
fi

ROOT=root-$MODEL
[ -n "$BRANCH" ] && ROOT=$ROOT-$BRANCH
ROOT=$ROOT-$VERSION
rm -rf $ROOT
mkdir $ROOT

## Create base filesystem for updater
ln -s tmp $ROOT/var
# Create lock required by updater
mkdir -p $ROOT/tmp/lock
# Create opkg status file and info file
mkdir -p $ROOT/usr/lib/opkg/info
touch $ROOT/usr/lib/opkg/status
# And updater directory
mkdir -p $ROOT/usr/share/updater
# Copy additional files
[ -e files/* ] && cp -r files/* $ROOT/


# TODO we migh need base files installed first

ABSOUT="$(readlink -f $ROOT)"
## Dump our entry file
UPDATER_CONF=".entry-$MODEL-$BRANCH.lua"
rm -f "$UPDATER_CONF" && touch "$UPDATER_CONF"
if [ -e l10n ]; then
	echo "l10n = {" >> "$UPDATER_CONF"
	while read L; do
		echo "'$L'," >> "$UPDATER_CONF"
	done < l10n
	echo "}" >> "$UPDATER_CONF"
else
	# Use no localizations
	echo "l10n = {} -- table with selected localizations" >> "$UPDATER_CONF"
fi
[ -n "$BRANCH" ] && CBRANCH="/$BRANCH"
echo "if Export then
	Export 'l10n'
	-- This is helper function for including localization packages.
	function for_l10n(fragment)
		for _, lang in pairs(l10n or {}) do
			Install(fragment .. lang, {ignore = {'missing'}})
		end
	end
	Export 'for_l10n'
end

local script_options = {
	security = 'Remote',
	ca = 'file://$PWD/.updater/updater.pem',
	crl = 'file:///tmp/crl.pem',
	ocsp = false,
	pubkey = {
		'file://$PWD/.release.pub',
		'file://$PWD/.standby.pub',
		'file://$PWD/.test.pub'
	}
}
base_url = 'https://api.turris.cz/updater-defs/$VERSION/$MODEL$CBRANCH/'

Script('base',  base_url .. 'base.lua', script_options)
" >> "$UPDATER_CONF"
if [ -e userlists ]; then
	while read L; do
		echo "Script('userlist-$L', base_url .. 'userlists/$L.lua', script_options)" >> "$UPDATER_CONF"
	done < userlists
fi
# Run updater to pull in packages from base list
.updater/bin/pkgupdate --no-replan --usign=.usign/usign -R $ABSOUT --batch file://$UPDATER_CONF

# Do cleanups
rm -rf "$ROOT"
rm -f $UPDATER_CONF
