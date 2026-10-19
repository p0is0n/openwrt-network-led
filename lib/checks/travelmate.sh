#!/bin/sh

# Travelmate status check.
#
# Exit codes:
#   0 - OK: uplink connected
#   1 - FAIL: no uplink connected
#   2 - PENDING: processing
#   3 - UNKNOWN: error, stopped, or invalid status

SERVICE="/etc/init.d/travelmate"

if [ ! -x "$SERVICE" ]; then
    exit 3
fi

status="$("$SERVICE" status 2>/dev/null)" || exit 3

state="$(
    printf '%s\n' "$status" |
        sed -n 's/.*travelmate_status[[:space:]]*:[[:space:]]*//p' |
        head -n 1
)"

case "$state" in
    connected*)
        exit 0
        ;;
    processing*)
        exit 2
        ;;
    "not connected"*)
        exit 1
        ;;
    "program error"* | *)
        exit 3
        ;;
esac
