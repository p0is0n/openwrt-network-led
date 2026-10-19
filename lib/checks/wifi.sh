#!/bin/sh

# Wi-Fi station association check.
#
# Exit codes:
#   0 - OK: associated with an access point
#   1 - FAIL: station exists but is disconnected
#   2 - PENDING: station interface is not available
#   3 - UNKNOWN: unable to determine state

command -v iw >/dev/null 2>&1 || exit 3

interfaces="$(iw dev 2>/dev/null)" || exit 3

stations="$(
    printf '%s\n' "$interfaces" |
        awk '
            $1 == "Interface" {
                iface = $2
            }

            $1 == "type" && $2 == "managed" {
                if (iface != "") {
                    print iface
                }
            }
        '
)"

[ -n "$stations" ] || exit 2

disconnected=0
unknown=0

for iface in $stations; do
    link="$(iw dev "$iface" link 2>/dev/null)"

    if [ $? -ne 0 ]; then
        unknown=1
        continue
    fi

    case "$link" in
        "Connected to "*)
            exit 0
            ;;
        "Not connected."*)
            disconnected=1
            ;;
        *)
            unknown=1
            ;;
    esac
done

if [ "$disconnected" -eq 1 ]; then
    exit 1
fi

exit 3
