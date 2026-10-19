#!/bin/sh

# Standard check exit codes.
NL_CHECK_OK=0
NL_CHECK_FAIL=1
NL_CHECK_PENDING=2
NL_CHECK_UNKNOWN=3

NL_CHECK_DIR="/usr/lib/network-led/checks"

# Execute a check and return its normalized status.
#
# Arguments:
#   $1 - check name
#   $2 - execution timeout in seconds (default: 5)
#
# Output:
#   ok | fail | pending | unknown
#
# Checks are independent executables.
# They must return one of the standard exit codes.

nl_check_run() {
    local name="$1"
    local timeout_seconds="${2:-5}"
    local file
    local result

    case "$name" in
        ""|*[!a-zA-Z0-9_-]*)
            printf '%s\n' "unknown"
            return 0
            ;;
    esac

    case "$timeout_seconds" in
        ""|*[!0-9]*|0)
            timeout_seconds=5
            ;;
    esac

    file="${NL_CHECK_DIR}/${name}.sh"

    if [ ! -f "$file" ]; then
        printf '%s\n' "unknown"
        return 0
    fi

    timeout "$timeout_seconds" /bin/sh "$file" \
        >/dev/null 2>&1

    result=$?

    case "$result" in
        "$NL_CHECK_OK")
            printf '%s\n' "ok"
            ;;
        "$NL_CHECK_FAIL")
            printf '%s\n' "fail"
            ;;
        "$NL_CHECK_PENDING")
            printf '%s\n' "pending"
            ;;
        *)
            printf '%s\n' "unknown"
            ;;
    esac

    return 0
}
