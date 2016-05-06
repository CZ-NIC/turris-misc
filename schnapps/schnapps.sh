#!/bin/sh
#
# Btrfs snapshots managing script
# (C) 2016 CZ.NIC, z.s.p.o.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

TMP_MNT_DIR="/mnt/.snapshots"
LOCK="/tmp/schnapps.lock"
ERR=0
KEEP_MAX=""
[ -z "`which uci`" ]    || KEEP_MAX="`uci get schnapps.keep.max 2> /dev/null`"
[ \! -f /etc/schnapps ] || . /etc/schnapps
[ -n "$KEEP_MAX" ]      || KEEP_MAX=0

show_help() {
    echo "Usage: `basename $0` command [options]"
    echo ""
    echo "Commands:"
    echo "  create [opts]           Creates snapshot of current system"
    echo "      Options:"
    echo "          -t type         Type of the snapshot - default 'single'"
    echo "                          Other options are 'time', 'rollback', 'pre' and 'post'"
    echo "          -d description  Some note about the snapshot"
    echo
    echo "  list                    Show available snapshots"
    echo
    echo "  cleanup                 Find meaningless and too old snapshots and delete them"
    echo
    echo "  delete <number> [...]   Deletes snapshot corresponding to the number(s)"
    echo "                          Numbers can be found via list command"
    echo
    echo "  modify <number> [opts]  Modify metadata of snapshot corresponding to the number"
    echo "                          Numbers can be found via list command"
    echo "      Options:"
    echo "          -t type         Type of the snapshot - default 'single'"
    echo "                          Other options are 'time', 'pre' and 'post'"
    echo "          -d description  Some note about the snapshot"
    echo
    echo "  rollback [number]       Make snapshot corresponding to the number default for next boot"
    echo "                          If called without any argument, go one step back"
    echo "                          Numbers can be found via list command"
    echo
    echo "  mount <number> [...]    Mount snapshot corresponding to the number(s)"
    echo "                          Numbers can be found via list command"
    echo
    echo "  cmp [number] [number]   Compare snapshots corresponding to the numbers"
    echo "                          Numbers can be found via list command"
}

mount_root() {
    if ! mkdir "$LOCK"; then
        echo "Another instance seems to be running!"
        exit 2
    fi
    mkdir -p "$TMP_MNT_DIR"
    if [ -n "`ls -A "$TMP_MNT_DIR"`" ]; then
        echo "ERROR: Something is already in '$TMP_MNT_DIR'"
        exit 2
    fi
    mount /dev/mmcblk0p1 -o subvol=/ "$TMP_MNT_DIR"
}

mount_snp() {
    mkdir -p /mnt/snapshot-@$1
    if [ -n "`ls -A "/mnt/snapshot-@$1"`" ]; then
        echo "ERROR: Something is already in '/mnt/snapshot-@$1'"
        exit 2
    fi
    mount /dev/mmcblk0p1 -o subvol=/@$1 /mnt/snapshot-@$1
}

umount_root() {
    umount -fl "$TMP_MNT_DIR"
    rmdir "$LOCK"
}

# Does pretty output, counts and adds enough spaces to fill desired space, arguments are:
#  $1 - what to print
#  $2 - minimal width -2
#  $3 - alignment - default is left, you can use 'R' to align to right
#  $4 - what to fill with - default is spaces
round_output() {
    WORD="$1"
    ROUND="$2"
    AL="$3"
    FILL="$4"
    OUTPUT=""
    [ -n "$FILL" ] || FILL=" "
    LEN="`echo -n "$WORD" | wc -c`"
    SPACES="`expr $ROUND - $LEN`"
    if [ "$AL" = R ]; then
        for i in `seq 1 $SPACES`; do
            OUTPUT="$OUTPUT$FILL"
        done
        SPACES="1"
    else
        OUTPUT="$OUTPUT$FILL"
    fi
    OUTPUT="$OUTPUT`echo -n "$WORD" | tr '\n\t\r' '   '`"
    for i in `seq 1 $SPACES`; do
        OUTPUT="$OUTPUT$FILL"
    done
    echo -n "$OUTPUT"
}

table_put() {
    round_output "$1"  5 R
    echo -n "|"
    round_output "$2" 10
    echo -n "|"
    round_output "$3" 20
    echo -n "| "
    echo "$4"
}

table_separator() {
    round_output "-"  5 R  "-"
    echo -n "+"
    round_output "-" 10 "" "-"
    echo -n "+"
    round_output "-" 20 "" "-"
    echo -n "+"
    round_output "-" 38 "" "-"
    echo ""
}

list() {
    cd "$TMP_MNT_DIR"
    table_put "#" Type Date Description
    table_separator
    for i in `btrfs subvolume list "$TMP_MNT_DIR" | sed -n 's|ID [0-9]* gen [0-9]* top level [0-9]* path @\([0-9][0-9]*\)$|\1|p' | sort -n`; do
        CREATED="`btrfs subvolume show "$TMP_MNT_DIR"/@$i | sed -n 's|.*Creation time:[[:blank:]]*||p'`"
        DESCRIPTION=""
        TYPE="single"
        [ \! -f "$TMP_MNT_DIR"/$i.info ] || . "$TMP_MNT_DIR"/$i.info
        table_put "$i" "$TYPE" "$CREATED" "$DESCRIPTION"
    done
}

get_next_number() {
    NUMBER="`btrfs subvolume list "$TMP_MNT_DIR" | sed -n 's|ID [0-9]* gen [0-9]* top level [0-9]* path @\([0-9][0-9]*\)$|\1|p' | sort -n | tail -n 1`"
    if [ -n "$NUMBER" ]; then
        NUMBER="`expr $NUMBER + 1`"
    else
        NUMBER=1
    fi
    echo $NUMBER
}

create() {
    TYPE="single"
    DESCRIPTION="User created snapshot"
    while [ -n "$1" ]; do
        if   [ "x$1" = "x-t" ]; then
            shift
            if [ "$1" \!= pre ] && [ "$1" \!= post ] && [ "$1" \!= time ] && [ "$1" \!= single ]; then
                echo "Incorrect snapshot type - '$1'"
                echo
                show_help
                return
            fi
            TYPE="$1"
            shift
        elif [ "x$1" = "x-d" ]; then
            shift
            DESCRIPTION="$1"
            shift
        else
            echo "Unknown create option '$1'"
            echo
            show_help
            ERR=1
            return
        fi
    done
    NUMBER="`get_next_number`"
    if btrfs subvolume snapshot "$TMP_MNT_DIR"/@ "$TMP_MNT_DIR"/@$NUMBER > /dev/null; then
        echo "TYPE=\"$TYPE\"" > "$TMP_MNT_DIR"/$NUMBER.info
        echo "DESCRIPTION=\"$DESCRIPTION\"" >> "$TMP_MNT_DIR"/$NUMBER.info
        echo "Snapshot number $NUMBER created"
    else
        echo "Error creating new snapshot"
        ERR=4
    fi
}

modify() {
    NUMBER="$1"
    shift
    if [ \! -d "$TMP_MNT_DIR"/@$NUMBER ]; then
        echo "Snapshot number $NUMBER does not exists!"
        ERR=3
        return
    fi
    TYPE="single"
    DESCRIPTION="User created snapshot"
    [ \! -f "$TMP_MNT_DIR"/$NUMBER.info ] || . "$TMP_MNT_DIR"/$NUMBER.info
    while [ -n "$1" ]; do
        if   [ "x$1" = "x-t" ]; then
            shift
            if [ "$1" \!= pre ] && [ "$1" \!= post ] && [ "$1" \!= time ] && [ "$1" \!= single ]; then
                echo "Incorrect snapshot type - '$1'"
                echo
                show_help
                return
            fi
            TYPE="$1"
            shift
        elif [ "x$1" = "x-d" ]; then
            shift
            DESCRIPTION="$1"
            shift
        else
            echo "Unknown create option '$1'"
            echo
            show_help
            ERR=1
            return
        fi
    done
    echo "TYPE=\"$TYPE\"" > "$TMP_MNT_DIR"/$NUMBER.info
    echo "DESCRIPTION=\"$DESCRIPTION\"" >> "$TMP_MNT_DIR"/$NUMBER.info
    echo "Snapshot number $NUMBER modified"
}

delete() {
    NUMBER="$1"
    if [ \! -d "$TMP_MNT_DIR"/@$NUMBER ]; then
        echo "Snapshot number $NUMBER does not exists!"
        ERR=3
        return
    fi
    if btrfs subvolume delete -c "$TMP_MNT_DIR"/@$NUMBER > /dev/null; then
        rm -f "$TMP_MNT_DIR"/$NUMBER.info
        echo "Snapshot $NUMBER deleted."
    else
        echo "Error deleting snapshot $NUMBER"
        ERR=4
    fi
}

rollback() {
    ROLL_TO="$1"
    if [ -n "$ROLL_TO" ] && [ \! -d "$TMP_MNT_DIR"/@$NUMBER ]; then
        echo "Snapshot number $NUMBER does not exists!"
        ERR=3
        return
    fi
    if [ -z "$ROLL_TO" ]; then
        SKIP_TO=""
        for i in `btrfs subvolume list "$TMP_MNT_DIR" | sed -n 's|ID [0-9]* gen [0-9]* top level [0-9]* path @\([0-9][0-9]*\)$|\1|p' | sort -n -r` factory; do
            if [ "$i" \!= factory ] && [ -n "$SKIP_TO" ] && [ "$i" -ge "$SKIP_TO" ]; then
                continue
            fi
            TYPE="single"
            [ \! -f "$TMP_MNT_DIR"/$i.info ] || . "$TMP_MNT_DIR"/$i.info
            if [ "$TYPE" = "rollback" ]; then
                SKIP_TO="$ROLL_TO"
                continue
            fi
            ROLL_TO="$i"
            break
        done
    fi
    NUMBER="`get_next_number`"
    if ! mv "$TMP_MNT_DIR"/@ "$TMP_MNT_DIR"/@$NUMBER; then
        echo "Can't make snapshot of current state"
        ERR=4
        return
    fi
    echo "TYPE=\"rollback\"" > "$TMP_MNT_DIR"/$NUMBER.info
    echo "DESCRIPTION=\"Rollback to snapshot $ROLL_TO\"" >> "$TMP_MNT_DIR"/$NUMBER.info
    echo "ROLL_TO=$ROLL_TO" >> "$TMP_MNT_DIR"/$NUMBER.info
    if btrfs subvolume snapshot "$TMP_MNT_DIR"/@$ROLL_TO "$TMP_MNT_DIR"/@ > /dev/null; then
        echo "Current state saved as snapshot number $NUMBER"
        echo "Rolled back to snapshot $ROLL_TO"
        [ -z "`which cert-backup`" ] || cert-backup -X "$TMP_MNT_DIR"/@
    else
        rm -f "$TMP_MNT_DIR"/$NUMBER.info
        mv "$TMP_MNT_DIR"/@$NUMBER "$TMP_MNT_DIR"/@
        echo "Rolling back failed!"
        ERR=4
    fi
}

my_cmp() {
    if   [    -f "$1" ] && [ \! -f "$2" ]; then
        echo " - $3"
    elif [ \! -f "$1" ] && [    -f "$2" ]; then
        echo " + $3"
    elif ! cmp "$1" "$2" > /dev/null 2>&1; then
        echo " ~ $3"
    fi
}

my_status() {
    ( cd "$TMP_MNT_DIR"/@"$1"; find . -type f;
      cd "$TMP_MNT_DIR"/@"$2"; find . -type f ) | \
    sed 's|^\.||' | sort -u | while read fl; do
        my_cmp "$TMP_MNT_DIR"/@"$1"/"$fl" "$TMP_MNT_DIR"/@"$2"/"$fl" "$fl"
    done
}

cleanup() {
    echo "Searching for snapshots without any change."
    echo "This can take a while, please be patient."
    echo
    LAST=""
    for i in `btrfs subvolume list "$TMP_MNT_DIR" | sed -n 's|ID [0-9]* gen [0-9]* top level [0-9]* path @\([0-9][0-9]*\)$|\1|p' | sort -n`; do
        if [ -z "$LAST" ]; then
            LAST="$i"
            continue
        fi
            echo " * checking snaphot $i..."
        if [ -z "`my_status "$LAST" "$i"`" ]; then
            delete "$LAST" | sed 's|^|   - |'
        fi
        LAST="$i"
    done
    if [ "$KEEP_MAX" ] && [ "$KEEP_MAX" -gt 0 ]; then
        echo
        KEEP_MAX="`expr $KEEP_MAX + 1`"
        echo "Looking for old snapshots..."
        for i in `btrfs subvolume list "$TMP_MNT_DIR" | sed -n 's|ID [0-9]* gen [0-9]* top level [0-9]* path @\([0-9][0-9]*\)$|\1|p' | sort -n -r | tail -n "+$KEEP_MAX"`; do
            delete "$i" | sed 's|^| - |'
        done
    fi
}

snp_status() {
    if [ \! -d "$TMP_MNT_DIR"/@$1 ]; then
        echo "Snapshot number $1 does not exists!"
        ERR=3
        return
    fi
    if [ \! -d "$TMP_MNT_DIR"/@$2 ]; then
        echo "Snapshot number $2 does not exists!"
        ERR=3
        return
    fi
    SNAME="$2"
    [ -n "$SNAME" ] || SNAME="current"
    echo "Comparing snapshots $1 and $SNAME"
    echo "This can take a while, please be patient."
    echo "Meaning of the lines is following:"
    echo
    echo "   - file    file present in $1 and missing in $SNAME"
    echo "   + file    file not present in $1 but exists in $SNAME"
    echo "   ~ file    file in $1 differs from file in $SNAME"
    echo
    my_status "$1" "$2"
}

trap 'umount_root; exit "$ERR"' EXIT INT QUIT TERM ABRT
mount_root
command="$1"
shift
case $command in
    create)
        create "$@"
        ;;
    create)
        modify "$@"
        ;;
    list)
        list
        ;;
    cleanup)
        cleanup
        ;;
    delete)
        for i in "$@"; do
            delete "$1"
        done
        ;;
    rollback)
        rollback "$1"
        ;;
    mount)
        for i in "$@"; do
            mount_snp "$1"
        done
        ;;
    cmp)
        if [ $# -gt 2 ]; then
            echo "Wrong number of arguments"
            echo
            ERR=3
            show_help
        else
            LAST="$1"
            [ $# -gt 0 ]   || LAST="`btrfs subvolume list "$TMP_MNT_DIR" | sed -n 's|ID [0-9]* gen [0-9]* top level [0-9]* path @\([0-9][0-9]*\)$|\1|p' | sort -n | tail -n 1`"
            [ -n "$LAST" ] || LAST="factory"
            snp_status "$LAST" "$2"
        fi
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command $command!"
        echo
        show_help
        ERR=1
        ;;
esac
exit $ERR
