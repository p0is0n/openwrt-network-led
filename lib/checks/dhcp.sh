#!/bin/sh

# WWAN DHCP / IPv4 address check.
#
# Exit codes:
#   0 - OK: interface is up and has IPv4
#   1 - FAIL: interface is up but has no IPv4
#   2 - PENDING: interface is down or configuring
#   3 - UNKNOWN: unable to determine state

INTERFACE="wwan"

command -v ubus >/dev/null 2>&1 || exit 3
[ -r /usr/share/libubox/jshn.sh ] || exit 3

. /usr/share/libubox/jshn.sh

status="$(ubus call "network.interface.$INTERFACE" status 2>/dev/null)" ||
    exit 3

json_load "$status" || exit 3

json_get_var available available
json_get_var pending pending
json_get_var up up

if [ "$available" != "1" ]; then
    exit 2
fi

if [ "$pending" = "1" ]; then
    exit 2
fi

if [ "$up" != "1" ]; then
    exit 2
fi

json_select "ipv4-address" || exit 3
json_get_keys addresses

if [ -n "$addresses" ]; then
    exit 0
fi

exit 1
