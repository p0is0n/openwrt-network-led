#!/bin/sh

# Internet connectivity check over WWAN.
#
# Exit codes:
#   0 - OK: at least one target responds
#   1 - FAIL: all targets are unreachable
#   2 - PENDING: WWAN is not ready
#   3 - UNKNOWN: configuration or execution error

INTERFACE="wwan"
CONFIG="network-led"

command -v ping >/dev/null 2>&1 || exit 3
command -v ifstatus >/dev/null 2>&1 || exit 3

[ -r /usr/share/libubox/jshn.sh ] || exit 3
. /usr/share/libubox/jshn.sh

status="$(ifstatus "$INTERFACE" 2>/dev/null)" || exit 3
json_load "$status" || exit 3

json_get_var up up
json_get_var pending pending
json_get_var device l3_device

[ "$pending" = "1" ] && exit 2
[ "$up" = "1" ] || exit 2
[ -n "$device" ] || exit 3

targets="$(uci -q get "${CONFIG}.internet.target" 2>/dev/null)"

# UCI list options must be read through the config API.
# Collect targets using the UCI shell library.
[ -r /lib/functions.sh ] || exit 3
. /lib/functions.sh

config_load "$CONFIG"

get_targets() {
    config_list_foreach "$1" target check_target
}

check_target() {
    case "$1" in
        *[!0-9.]*|"")
            return
            ;;
    esac

    case "$1" in
        *.*)
            ping -I "$device" -c 1 -W 1 "$1" \
                >/dev/null 2>&1 && exit 0
            ;;
    esac
}

config_foreach get_targets check

exit 1
