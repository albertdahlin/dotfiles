#!/usr/bin/env bash
# i3bar status_command: runs i3status and prepends the Claude usage blocks.
set -uo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USAGE="$DIR/claude-usage.sh"

# i3status must emit i3bar JSON; ~/.i3status.conf sets output_format = "i3bar".
i3status | {
    read -r line && echo "$line"   # {"version":1,...}
    read -r line && echo "$line"                # [
    while read -r line; do
        prefix=""
        if [ "${line:0:1}" = "," ]; then
            prefix=","
            line=${line:1}
        fi
        extra=$("$USAGE" blocks 2>/dev/null)
        case "$extra" in ""|"[]") extra="[]" ;; esac
        printf '%s%s\n' "$prefix" \
            "$(jq -cn --argjson a "$extra" --argjson b "$line" '$a + $b' 2>/dev/null || printf '%s' "$line")"
    done
}
