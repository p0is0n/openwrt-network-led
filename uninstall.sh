#!/bin/sh

set -eu

PROJECT="network-led"

CONFIG="/etc/config/$PROJECT"
INIT="/etc/init.d/$PROJECT"
BIN="/usr/sbin/$PROJECT"
LIB="/usr/lib/$PROJECT"
STATE="/tmp/$PROJECT"

PURGE=0

log() {
    printf '%s: %s\n' "$PROJECT" "$*"
}

fail() {
    printf '%s: ERROR: %s\n' "$PROJECT" "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: sh uninstall.sh [--purge]

Options:
  --purge     Remove configuration as well
  -h, --help  Show this help message
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --purge)
                PURGE=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                fail "unknown argument: $1"
                ;;
        esac

        shift
    done
}

check_environment() {
    [ "$(id -u)" -eq 0 ] || fail "root privileges required"
    [ -f /etc/openwrt_release ] || fail "OpenWrt is required"
}

stop_service() {
    if [ ! -f "$INIT" ]; then
        log "service is not installed"
        return 0
    fi

    log "stopping service"
    "$INIT" stop 2>/dev/null || true

    log "disabling autostart"
    "$INIT" disable 2>/dev/null || true
}

remove_files() {
    log "removing executable"
    rm -f "$BIN"

    log "removing modules"
    rm -f \
        "$LIB/core/check.sh" \
        "$LIB/core/runner.sh" \
        "$LIB/core/resolver.sh" \
        "$LIB/checks/travelmate.sh" \
        "$LIB/checks/wifi.sh" \
        "$LIB/checks/dhcp.sh" \
        "$LIB/checks/internet.sh" \
        "$LIB/outputs/rgb.sh"

    rmdir "$LIB/core" 2>/dev/null || true
    rmdir "$LIB/checks" 2>/dev/null || true
    rmdir "$LIB/outputs" 2>/dev/null || true
    rmdir "$LIB" 2>/dev/null || true

    log "removing init script"
    rm -f "$INIT"
}

remove_state() {
    if [ -d "$STATE" ]; then
        log "removing runtime state"
        rm -rf "$STATE"
    fi

    rm -f /tmp/network-led-rgb-error.*
}

remove_config() {
    if [ "$PURGE" -eq 1 ]; then
        log "removing configuration"
        rm -f "$CONFIG"
    else
        log "preserving configuration: $CONFIG"
    fi
}

main() {
    parse_args "$@"
    check_environment

    log "uninstallation started"

    stop_service
    remove_files
    remove_state
    remove_config

    log "uninstallation complete"
}

main "$@"
