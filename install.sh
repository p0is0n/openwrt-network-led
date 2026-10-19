#!/bin/sh

set -eu

PROJECT="network-led"

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

CONFIG="/etc/config/$PROJECT"
INIT="/etc/init.d/$PROJECT"
BIN="/usr/sbin/$PROJECT"
LIB="/usr/lib/$PROJECT"

log() {
    printf '%s: %s\n' "$PROJECT" "$*"
}

fail() {
    printf '%s: ERROR: %s\n' "$PROJECT" "$*" >&2
    exit 1
}

check_environment() {
    [ "$(id -u)" -eq 0 ] || fail "root privileges required"
    [ -f /etc/openwrt_release ] || fail "OpenWrt is required"

    for command in uci ubus iw ping timeout logger; do
        command -v "$command" >/dev/null 2>&1 ||
            fail "missing dependency: $command"
    done
}

check_sources() {
    for file in \
        config/network-led \
        init.d/network-led \
        sbin/network-led \
        lib/core/check.sh \
        lib/core/runner.sh \
        lib/core/resolver.sh \
        lib/checks/travelmate.sh \
        lib/checks/wifi.sh \
        lib/checks/dhcp.sh \
        lib/checks/internet.sh \
        lib/outputs/rgb.sh
    do
        [ -f "$ROOT/$file" ] ||
            fail "missing source: $file"
    done

    for file in \
        "$ROOT/init.d/network-led" \
        "$ROOT/sbin/network-led" \
        "$ROOT"/lib/core/*.sh \
        "$ROOT"/lib/checks/*.sh \
        "$ROOT"/lib/outputs/*.sh
    do
        sh -n "$file" || fail "syntax error: $file"
    done
}

stop_service() {
    if [ -x "$INIT" ]; then
        log "stopping service"
        "$INIT" stop 2>/dev/null || true
    fi
}

install_files() {
    log "installing files"

    mkdir -p \
        /etc/config \
        /etc/init.d \
        /usr/sbin \
        "$LIB/core" \
        "$LIB/checks" \
        "$LIB/outputs"

    if [ ! -e "$CONFIG" ]; then
        cp "$ROOT/config/network-led" "$CONFIG"
        chmod 600 "$CONFIG"
        log "configuration installed"
    else
        log "existing configuration preserved"
    fi

    cp "$ROOT/init.d/network-led" "$INIT"
    cp "$ROOT/sbin/network-led" "$BIN"

    cp "$ROOT"/lib/core/*.sh "$LIB/core/"
    cp "$ROOT"/lib/checks/*.sh "$LIB/checks/"
    cp "$ROOT"/lib/outputs/*.sh "$LIB/outputs/"

    chmod 755 "$INIT" "$BIN"
    chmod 644 "$LIB"/core/*.sh
    chmod 644 "$LIB"/checks/*.sh
    chmod 644 "$LIB"/outputs/*.sh
}

start_service() {
    log "enabling service"
    "$INIT" enable

    log "starting service"
    "$INIT" start

    log "installation complete"
    log "check status: $INIT status"
    log "check logs: logread -e $PROJECT"
}

main() {
    log "installation started"

    check_environment
    check_sources

    stop_service
    install_files
    start_service
}

main "$@"
