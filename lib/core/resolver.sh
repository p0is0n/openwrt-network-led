#!/bin/sh

# Declarative LED rule resolver.
#
# Dependencies:
#   /lib/functions.sh
#   core/runner.sh
#
# Rule conditions:
#   check=status
#   check=ok,fail
#
# Multiple conditions are combined with AND.
# Highest matching priority wins.

NL_RESOLVER_CONFIG="network-led"

nl_resolver_condition() {
    local condition="$1"
    local name expected actual
    local value

    case "$condition" in
        *=*)
            name="${condition%%=*}"
            expected="${condition#*=}"
            ;;
        *)
            return 1
            ;;
    esac

    nl_runner_valid_name "$name" || return 1
    [ -n "$expected" ] || return 1

    actual="$(nl_runner_get "$name")"

    case ",$expected," in
        *,"$actual",*)
            return 0
            ;;
    esac

    return 1
}

nl_resolver_match_condition() {
    [ "$NL_RESOLVER_MATCH" -eq 1 ] || return 0

    nl_resolver_condition "$1" || NL_RESOLVER_MATCH=0
}

nl_resolver_evaluate_rule() {
    local section="$1"
    local priority color effect

    NL_RESOLVER_MATCH=1

    config_list_foreach "$section" condition nl_resolver_match_condition

    [ "$NL_RESOLVER_MATCH" -eq 1 ] || return

    config_get priority "$section" priority 0
    config_get color "$section" color red
    config_get effect "$section" effect solid

    case "$priority" in
        ""|*[!0-9]*)
            return
            ;;
    esac

    if [ "$priority" -gt "$NL_RESOLVER_PRIORITY" ]; then
        NL_RESOLVER_PRIORITY="$priority"
        NL_RESOLVER_RULE="$section"
        NL_RESOLVER_COLOR="$color"
        NL_RESOLVER_EFFECT="$effect"
    fi
}

nl_resolver_resolve() {
    NL_RESOLVER_PRIORITY="-1"
    NL_RESOLVER_RULE="error"
    NL_RESOLVER_COLOR="red"
    NL_RESOLVER_EFFECT="blink_fast"
    NL_RESOLVER_MATCH=0

    config_load "$NL_RESOLVER_CONFIG"
    config_foreach nl_resolver_evaluate_rule rule

    printf '%s %s %s\n' \
        "$NL_RESOLVER_RULE" \
        "$NL_RESOLVER_COLOR" \
        "$NL_RESOLVER_EFFECT"
}
