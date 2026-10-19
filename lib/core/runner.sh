#!/bin/sh

# Network LED check runner.
#
# Dependencies:
#   /lib/functions.sh
#   core/check.sh
#
# Lifecycle:
#   nl_runner_init
#   nl_runner_tick
#   nl_runner_snapshot

NL_RUNNER_DIR="/tmp/network-led/checks"
NL_RUNNER_CONFIG="network-led"

nl_runner_now() {
    cut -d. -f1 /proc/uptime | cut -d' ' -f1
}

nl_runner_read() {
    local file="$1"
    local fallback="$2"
    local value

    if [ -r "$file" ]; then
        IFS= read -r value < "$file"
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

nl_runner_write() {
    printf '%s\n' "$2" > "$1"
}

nl_runner_valid_name() {
    case "$1" in
        ""|*[!a-zA-Z0-9_-]*)
            return 1
            ;;
    esac

    return 0
}

nl_runner_positive() {
    case "$1" in
        ""|*[!0-9]*|0)
            printf '%s\n' "$2"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

nl_runner_get() {
    local name="$1"

    nl_runner_valid_name "$name" || {
        printf '%s\n' "unknown"
        return
    }

    nl_runner_read "$NL_RUNNER_DIR/$name/state" "uninitialized"
}

nl_runner_init_check() {
    local section="$1"
    local enabled

    config_get_bool enabled "$section" enabled 1

    [ "$enabled" -eq 1 ] || return
    nl_runner_valid_name "$section" || return

    mkdir -p "$NL_RUNNER_DIR/$section"

    nl_runner_write "$NL_RUNNER_DIR/$section/state" "uninitialized"
    nl_runner_write "$NL_RUNNER_DIR/$section/success" "0"
    nl_runner_write "$NL_RUNNER_DIR/$section/fail" "0"
    nl_runner_write "$NL_RUNNER_DIR/$section/next" "0"
}

nl_runner_init() {
    mkdir -p "$NL_RUNNER_DIR"

    config_load "$NL_RUNNER_CONFIG"
    config_foreach nl_runner_init_check check
}

nl_runner_tick_check() {
    local section="$1"
    local enabled interval timeout_seconds
    local success_threshold fail_threshold
    local dir now next result state
    local success fail

    config_get_bool enabled "$section" enabled 1
    [ "$enabled" -eq 1 ] || return

    nl_runner_valid_name "$section" || return

    dir="$NL_RUNNER_DIR/$section"
    [ -d "$dir" ] || return

    config_get interval "$section" interval 3
    config_get timeout_seconds "$section" timeout 5
    config_get success_threshold "$section" success_threshold 1
    config_get fail_threshold "$section" fail_threshold 1

    interval="$(nl_runner_positive "$interval" 3)"
    timeout_seconds="$(nl_runner_positive "$timeout_seconds" 5)"
    success_threshold="$(nl_runner_positive "$success_threshold" 1)"
    fail_threshold="$(nl_runner_positive "$fail_threshold" 1)"

    now="$(nl_runner_now)"
    next="$(nl_runner_read "$dir/next" 0)"

    [ "$now" -ge "$next" ] || return

    result="$(nl_check_run "$section" "$timeout_seconds")"

    state="$(nl_runner_read "$dir/state" uninitialized)"
    success="$(nl_runner_read "$dir/success" 0)"
    fail="$(nl_runner_read "$dir/fail" 0)"

    case "$result" in
        ok)
            success=$((success + 1))
            fail=0

            if [ "$success" -ge "$success_threshold" ]; then
                state="ok"
            fi
            ;;

        fail)
            fail=$((fail + 1))
            success=0

            if [ "$fail" -ge "$fail_threshold" ]; then
                state="fail"
            fi
            ;;

        pending)
            state="pending"
            success=0
            fail=0
            ;;

        unknown|*)
            state="unknown"
            success=0
            fail=0
            ;;
    esac

    nl_runner_write "$dir/state" "$state"
    nl_runner_write "$dir/success" "$success"
    nl_runner_write "$dir/fail" "$fail"
    nl_runner_write "$dir/next" "$((now + interval))"
}

nl_runner_tick() {
    config_load "$NL_RUNNER_CONFIG"
    config_foreach nl_runner_tick_check check
}

nl_runner_print_check() {
    local section="$1"
    local enabled state

    config_get_bool enabled "$section" enabled 1
    [ "$enabled" -eq 1 ] || return

    state="$(nl_runner_get "$section")"
    printf '%-16s %s\n' "$section" "$state"
}

nl_runner_snapshot() {
    config_load "$NL_RUNNER_CONFIG"
    config_foreach nl_runner_print_check check
}
