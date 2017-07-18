#!/bin/sh
set -ex

MODEL="$1"
BRANCH="$2"
if [ -z "$MODEL" -o -z "$BRANCH" ]; then
	echo "Usage: $0 MODEL BRANCH" >&2
	exit 1
fi

# Returns package versions in repository
updater_version() {
	[ "$1" = "deploy" ] && VBRANCH="" || VBRANCH="-$1"
	curl https://repo.turris.cz/"$MODEL$VBRANCH"/packages/turrispackages/Packages | \
		sed -n 's/^Filename: updater-ng_\([^_-]*\).*/\1/p'
	# Note: tags are in form of vVERSION but version is in form of VERSION-RELEASE
}

UPDATER_TARGET_VERSION="$(updater_version "$BRANCH")"

#################################################################################
## Prepare updater versions
# 1045373e0977e42bf8ff23fda88d1d5dade690d5 - (v30) Version used in Turris Omnia factory (Turris OS 3.2)
UPDATER_VERSIONS="1045373e0977e42bf8ff23fda88d1d5dade690d5"
# v58.4.5 - used durring migration from old updater on Turris 1.x (Turris OS 3.7.2)
UPDATER_VERSIONS="$UPDATER_VERSIONS v58.4.5"
# Version in target branch
UPDATER_VERSIONS="$UPDATER_VERSIONS v$UPDATER_TARGET_VERSION"
# Version in deploy branch
[ "$BRANCH" = "deploy" ] || \
	UPDATER_VERSIONS="$UPDATER_VERSIONS v$(updater_version deploy)"
#################################################################################

#################################################################################
## List of all userlists (for backward compatibility lists should be only added never removed)
# TODO add those in Turris 1.x
# Lists that are enabled in Turris Omnia factory (Turris OS 3.2)
LISTS_FACTORY="cacerts luci-controls lxc nas netutils shell-utils"
# All lists that we iterate trough
LISTS="$LISTS_FACTORY api-token automation dev-detect dvb honeypot i_agree_datacollect i_agree_honeypot majordomo openvpn printserver smrt-support snd squid tor webcam"
#################################################################################

#################################################################################
## List of all enabled languages
cat > l10n <<EOF
cs
en
fr
pl
sk
EOF
#################################################################################


# Get Turris OS version
[ "$BRANCH" = "deploy" ] && VBRANCH="" || VBRANCH="-$BRANCH"
VERSION="$(curl https://repo.turris.cz/"$MODEL$VBRANCH"/packages/base/Packages | sed -n 's/^Filename: turris-version_\([^_]*\)_.*/\1/p')"

# Helper function for getting project from git
git_pull() {
	if [ ! -d $1 ]; then
		git clone $2 $1
		pushd $1 >/dev/null
		git submodule update --init --recursive
		popd >/dev/null
	else
		pushd $1 >/dev/null
		git fetch --tags
		if ! git diff --quiet HEAD origin/HEAD; then
			git clean -Xdf
			git reset --hard origin/master
			git submodule update --init --recursive
		fi
		popd >/dev/null
	fi
}

# Helper function for getting files
wget_pull() {
	if [ ! -e $1 ] || [ $(expr $(date -u +%s) - $(stat -c %Z $1)) -gt 86400 ]; then
		wget $2 -O $1
	fi
}

## Prepare tools
# Usign
git_pull .usign git://git.openwrt.org/project/usign.git
if [ ! -x .usign/usign ]; then
	pushd .usign >/dev/null
	cmake .
	make
	popd >/dev/null
fi
# get-api-crl
wget_pull .get-api-crl https://gitlab.labs.nic.cz/turris/misc/raw/master/cacerts/get-api-crl
chmod +x .get-api-crl
./.get-api-crl
# Get certificates
for K in release standby test; do
	wget_pull .$K.pub https://gitlab.labs.nic.cz/turris/turris-os-packages/raw/test/cznic/cznic-repo-keys/files/$K.pub
done
# Updater
git_pull .updater https://gitlab.labs.nic.cz/turris/updater.git

mkdir -p .fake_bin
export PATH="$(readlink -f $PWD/.fake_bin):$PATH"
# Create fake reboot to not potentially reboot host if requested
echo "#!/bin/sh
echo Reboot faked!" > .fake_bin/reboot
chmod +x .fake_bin/reboot

[ "$BRANCH" = "deploy" ] && UBRANCH="" || UBRANCH="--branch $BRANCH"
run_test() {
	# Run updater and generate root
	fakeroot "$(dirname "$0")"/updater-medkit.sh --version "$VERSION" $UBRANCH --model "$MODEL" || exit 1
	# Check version of updater (should be the one from target branch)
	# TODO what if that is older version than the on in deploy
	local CONTROL="root-$MODEL$VBRANCH-$VERSION/usr/lib/opkg/info/updater-ng.control"
	[ -f "$CONTROL" ] && grep -q "Version: $UPDATER_TARGET_VERSION" "$CONTROL" || exit 1
	rm -rf "root-$MODEL$VBRANCH-$VERSION"
}
## Now build and test specified updater version
for V in $UPDATER_VERSIONS; do
	echo "== Testing with $V ========================================================"
	pushd .updater
	git checkout -f "$V"
	git submodule update --init --recursive
	git clean -xdf
	popd
	# Because we are not able to do this test with some old versions we have to patch them
	if [ -d "$(dirname "$0")"/patch-"$V" ]; then
		for F in "$(dirname "$0")"/patch-"$V"/*; do
			patch -p1 -d.updater < "$F"
		done
	fi
	make -C .updater NO_DOC=1 LUA_COMPILE:=no

	# First test with just the base userlist (base userlist should work on it's own)
	echo "== Testing base userlist =="
	echo base > userlists
	run_test
	# Now test combination in factory
	echo "== Testing factory combination =="
	for L in $LISTS_FACTORY; do # Note: base is already written
		echo "$L" >> userlists
	done
	run_test
	# Now test combination of every userlist with base
	for L in $LISTS; do
		echo "== Testing base with $L =="
		echo base > userlists
		echo "$L" >> userlists
		run_test
	done
	# Test all userlists together
	echo "== Testing all userlists together =="
	echo base > userlists
	for L in $LISTS; do
		echo "$L" >> userlists
	done
	run_test

	make -C .updater clean
done

## Do cleanups
rm -rf .fake_bin
pushd .updater
git checkout -f master
git submodule update --init --recursive
git clean -xdf
popd
rm l10n
