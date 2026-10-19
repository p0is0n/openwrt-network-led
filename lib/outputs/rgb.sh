#!/bin/sh

# RGB LED driver for Google WiFi (Gale).
#
# Public functions:
#   nl_rgb_init
#   nl_rgb_set COLOR
#   nl_rgb_off
#
# Supported colors:
#   red, green, blue, white, orange, purple, yellow, off

NL_RGB_SECTION="rgb"
NL_RGB_PATH="/sys/class/leds"

NL_RGB_RED=""
NL_RGB_GREEN=""
NL_RGB_BLUE=""
NL_RGB_BRIGHTNESS=90
NL_RGB_CURRENT=""

nl_rgb_log() {
    logger -t network-led "RGB: $*"
}

nl_rgb_error() {
    nl_rgb_log "ERROR: $*"
}

nl_rgb_validate_channel() {
    local channel="$1"
    local path

    case "$channel" in
        ""|*/*|*..*)
            nl_rgb_error "invalid channel: $channel"
            return 1
            ;;
    esac

    path="$NL_RGB_PATH/$channel"

    if [ ! -w "$path/brightness" ]; then
        nl_rgb_error "channel unavailable: $channel"
        return 1
    fi

    return 0
}

nl_rgb_disable_trigger() {
    local channel="$1"
    local path="$NL_RGB_PATH/$channel/trigger"
    local current

    [ -r "$path" ] || return 1

    current="$(cat "$path")"

    case "$current" in
        *"[none]"*)
            return 0
            ;;
    esac

    if ! (printf '%s\n' none > "$path") 2>/dev/null; then
        nl_rgb_error "failed to disable trigger: $channel"
        return 1
    fi

    return 0
}

nl_rgb_write() {
    local channel="$1"
    local value="$2"
    local path="$NL_RGB_PATH/$channel/brightness"

    if ! (printf '%s\n' "$value" > "$path") 2>/dev/null; then
        nl_rgb_error "failed to write: channel=$channel value=$value"
        return 1
    fi

    return 0
}

nl_rgb_init() {
    local red green blue brightness channel

    config_load network-led || {
        nl_rgb_error "failed to load configuration"
        return 1
    }

    config_get red "$NL_RGB_SECTION" red ""
    config_get green "$NL_RGB_SECTION" green ""
    config_get blue "$NL_RGB_SECTION" blue ""
    config_get brightness "$NL_RGB_SECTION" brightness 90

    for channel in "$red" "$green" "$blue"; do
        nl_rgb_validate_channel "$channel" || return 1
    done

    case "$brightness" in
        ""|*[!0-9]*)
            nl_rgb_error "invalid brightness: $brightness"
            return 1
            ;;
    esac

    [ "$brightness" -le 255 ] || {
        nl_rgb_error "brightness exceeds 255"
        return 1
    }

    NL_RGB_RED="$red"
    NL_RGB_GREEN="$green"
    NL_RGB_BLUE="$blue"
    NL_RGB_BRIGHTNESS="$brightness"
    NL_RGB_CURRENT=""

    for channel in "$red" "$green" "$blue"; do
        nl_rgb_disable_trigger "$channel" || return 1
    done

    nl_rgb_set off || return 1

    nl_rgb_log "initialized"

    return 0
}

nl_rgb_set() {
    local color="$1"
    local brightness="$NL_RGB_BRIGHTNESS"
    local red=0 green=0 blue=0

    [ "$color" = "$NL_RGB_CURRENT" ] && return 0

    case "$color" in
        red)
            red="$brightness"
            ;;
        green)
            green="$brightness"
            ;;
        blue)
            blue="$brightness"
            ;;
        white)
            red="$brightness"
            green="$brightness"
            blue="$brightness"
            ;;
        orange)
            red="$brightness"
            green=$((brightness / 3))
            ;;
        purple)
            red="$brightness"
            blue="$brightness"
            ;;
        yellow)
            red="$brightness"
            green="$brightness"
            ;;
        off)
            ;;
        *)
            nl_rgb_error "unsupported color: $color"
            return 1
            ;;
    esac

    nl_rgb_write "$NL_RGB_RED" "$red" || return 1
    nl_rgb_write "$NL_RGB_GREEN" "$green" || return 1
    nl_rgb_write "$NL_RGB_BLUE" "$blue" || return 1

    NL_RGB_CURRENT="$color"

    nl_rgb_log "color: $color"

    return 0
}

nl_rgb_off() {
    nl_rgb_set off
}
