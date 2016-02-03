#!/bin/sh
#
# Turris Knot Resolver Installer
# Copyright (c) 2015 CZ.NIC, z. s. p. o. <https://www.nic.cz/>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of Turris Knot Resolver Installer nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
set -e
DEBUG=0
[ "$1" == "-d" ] && { DEBUG=1 ; set -x; }

INSTALLER_VERSION=1
INSTALLATION_DIR=/tmp/knot-resolver-installer

echo "Turris Knot Resolver Installer v$INSTALLER_VERSION"
echo
echo "This installer will install a development version of Knot Resolver"
echo "for the Turris 1.0 and 1.1 routers."
echo
echo "Pro tip: you can run the installation process step-by-step in debug"
echo "mode by running the script as $0 -d"
echo
echo "WARNING: This version is highly experimental and installation of it"
echo "may break standard operation of the device. Also, it currently does"
echo "NOT support DNSSEC validation for LAN clients (local resolving will"
echo "be still handled by unbound)!"
echo
echo "Proceed only if you understand all the risks."
echo
read -p "Do you really want to continue? [y/N]: "

debug() {
	echo "INSTALLER: $1"
	[ "$DEBUG" == "1" ] && read -n1 -p "Press any key to continue." || true
}

for dep in libgnutls libnettle knot-libknot; do
	opkg list-installed | grep -q "^$dep" && {
		echo -e "\nPackage $dep is already installed. Replacing it with" \
			"the development version can break other applications."
		read -p "Do you want to continue? [y/N]: " CONT
		if [ "$CONT" != "y" ] && [ "$CONT" != "Y" ]; then
			exit 1
		fi
	}
done


debug "Running opkg update."
opkg update

debug "Installing dependencies from the main repository."
opkg install libgmp liburcu jansson

debug "Cleaning opkg lists."
# needed to avoid hash collisions with "hacked-in" packages
rm -rf /tmp/opkg-lists


rm -rf "$INSTALLATION_DIR"
mkdir -p "$INSTALLATION_DIR"

# prepare backups of UCI configs and trap errors
[ -f /etc/config/kresd ] && cp /etc/config/kresd ${INSTALLATION_DIR}/kresd.bak
cp /etc/config/firewall ${INSTALLATION_DIR}/firewall.bak

error_handler() {
	debug "Installation failed. Try running the script with the -d flag to see what happens."
	[ -f ${INSTALLATION_DIR}/kresd.bak ] && cp ${INSTALLATION_DIR}/kresd.bak /etc/config/kresd
	cp ${INSTALLATION_DIR}/firewall.bak /etc/config/firewall
	rm -rf "$INSTALLATION_DIR"
}
trap error_handler INT QUIT TERM ABRT


debug "Downloading packages from the development repository."

silent_wget() {
	wget $@ 2>/dev/null || echo "Failed to run wget $@"
}

cd "$INSTALLATION_DIR"
silent_wget https://api.turris.cz/knot/knot-libdnssec_2.0.1-213-gc1353ef-1_mpc85xx.ipk
silent_wget https://api.turris.cz/knot/knot-libknot_2.0.1-213-gc1353ef-1_mpc85xx.ipk
silent_wget https://api.turris.cz/knot/knot-resolver_1.0.0-beta2-91-g3bbdca3-1_mpc85xx.ipk
silent_wget https://api.turris.cz/knot/libgnutls_3.4.5-1_mpc85xx.ipk
silent_wget https://api.turris.cz/knot/libnettle_3.1.1-1_mpc85xx.ipk
silent_wget https://api.turris.cz/knot/libuv_1.6.1-1_mpc85xx.ipk
silent_wget https://api.turris.cz/knot/luajit_2.0.4-1_mpc85xx.ipk


debug "Removing old packages."
# remove only packages from the development repository first
# using --force-reinstall sometimes raises a segfault
opkg remove --force-depends knot-libdnsssec knot-libknot knot-resolver libgnutls libnettle libuv luajit

debug "Installing packages from the development repository."
opkg install *.ipk


IP_ADDR=$(ip addr show dev br-lan | grep "inet " | sed -r 's;.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/.*;\1;')

read -p "Detected LAN IP address is $IP_ADDR - is it correct? [Y/n]: " CONT
if [ "$CONT" != "" ] && [ "$CONT" != "y" ] && [ "$CONT" != "Y" ]; then
	read -p "Please enter this device's LAN address: " IP_ADDR
fi

debug "Updating knot-resolver UCI configuration."
uci del kresd.@kresd[0].addr
uci add_list kresd.@kresd[0].addr="${IP_ADDR}#5353"
uci commit

debug "Updating firewall UCI configuration."
uci add firewall redirect
uci set firewall.@redirect[-1]=redirect
uci set firewall.@redirect[-1].name="knot-resolver redirect"
uci set firewall.@redirect[-1].target=DNAT
uci set firewall.@redirect[-1].proto=tcpudp
uci set firewall.@redirect[-1].src=lan
uci set firewall.@redirect[-1].src_dport=53
uci set firewall.@redirect[-1].dest=lan
uci set firewall.@redirect[-1].dest_port=5353
uci commit

debug "Restarting and enabling services."
/etc/init.d/firewall reload
/etc/init.d/kresd enable
/etc/init.d/kresd start

debug "Performing final cleanup."
cd /
rm -rf "$INSTALLATION_DIR"

debug "Saving installation log."
curdate=$(date +%s)
echo "$curdate:$INSTALLER_VERSION" >> /usr/share/kresd-installer.log

echo "Knot Resolver installation finished successfully."
