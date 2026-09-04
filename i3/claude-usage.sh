#!/usr/bin/env bash
# Claude subscription usage as i3bar blocks.
#
#   claude-usage.sh blocks   print a JSON array of i3bar blocks (from cache,
#                            refreshing in the background when stale)
#   claude-usage.sh fetch    hit the API now and update the cache
#   claude-usage.sh show     human-readable one-liner (for testing)

set -uo pipefail

CREDS="${CLAUDE_CREDENTIALS:-$HOME/.claude/.credentials.json}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE="$CACHE_DIR/claude-usage.json"
LOCK="$CACHE_DIR/claude-usage.lock"

API_URL="${CLAUDE_USAGE_API:-https://api.anthropic.com}/api/oauth/usage?at_wall=1&skip_spend=1"
TOKEN_URL="https://platform.claude.com/v1/oauth/token"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"

TTL="${CLAUDE_USAGE_TTL:-60}"      # seconds before a background refresh is kicked off
STALE="${CLAUDE_USAGE_STALE:-600}" # seconds before the shown numbers are marked stale

# Set CLAUDE_USAGE_NO_REFRESH=1 to never touch ~/.claude/.credentials.json.
NO_REFRESH="${CLAUDE_USAGE_NO_REFRESH:-0}"

mkdir -p "$CACHE_DIR"

# --- credentials ------------------------------------------------------------

access_token() { jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null; }

# Exchange the refresh token for a new access token and write it back, keeping
# every other field in the credentials file intact. A copy of the previous file
# is left at <creds>.bak.
refresh_token() {
    [ "$NO_REFRESH" = 1 ] && return 1
    local rt resp access refresh expires_in tmp
    rt=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS" 2>/dev/null) || return 1
    [ -n "$rt" ] || return 1

    resp=$(curl -sf --max-time 20 -X POST "$TOKEN_URL" \
        -H 'Content-Type: application/json' \
        -d "$(jq -nc --arg rt "$rt" --arg cid "$CLIENT_ID" \
              '{grant_type:"refresh_token", refresh_token:$rt, client_id:$cid}')") || return 1

    access=$(jq -r '.access_token // empty' <<<"$resp")
    [ -n "$access" ] || return 1
    refresh=$(jq -r '.refresh_token // empty' <<<"$resp")
    expires_in=$(jq -r '.expires_in // 28800' <<<"$resp")

    tmp=$(mktemp "$CREDS.XXXXXX") || return 1
    if jq --arg a "$access" --arg r "$refresh" --argjson e "$expires_in" '
            .claudeAiOauth.accessToken = $a
          | (if $r == "" then . else .claudeAiOauth.refreshToken = $r end)
          | .claudeAiOauth.expiresAt = ((now * 1000 | floor) + $e * 1000)
        ' "$CREDS" >"$tmp"; then
        chmod 600 "$tmp"
        cp -p "$CREDS" "$CREDS.bak" 2>/dev/null
        mv "$tmp" "$CREDS"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# --- fetching ---------------------------------------------------------------

# Writes the body to $BODY_FILE and sets $http_code.
http_code=000
BODY_FILE=""
api_get() {
    local token=$1
    http_code=$(curl -s --max-time 20 -o "$BODY_FILE" -w '%{http_code}' "$API_URL" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json") || http_code=000
}

do_fetch() {
    local token tmp
    token=$(access_token)
    if [ -z "$token" ]; then
        write_error "no auth"
        return 1
    fi

    BODY_FILE=$(mktemp "$CACHE.body.XXXXXX") || return 1
    trap 'rm -f "$BODY_FILE"' RETURN

    api_get "$token"
    if [ "$http_code" = 401 ] || [ "$http_code" = 403 ]; then
        if refresh_token; then
            token=$(access_token)
            api_get "$token"
        fi
    fi

    if [ "$http_code" != 200 ]; then
        write_error "http $http_code"
        return 1
    fi

    tmp=$(mktemp "$CACHE.XXXXXX") || return 1
    if jq -c '{fetched_at: (now | floor), error: null, limits: (.limits // [])}' \
            "$BODY_FILE" >"$tmp" 2>/dev/null; then
        mv "$tmp" "$CACHE"
    else
        rm -f "$tmp"
        write_error "bad response"
        return 1
    fi
}

# Record an error without discarding the last good numbers.
write_error() {
    local msg=$1 tmp
    tmp=$(mktemp "$CACHE.XXXXXX") || return 1
    jq -c --arg e "$msg" '.error = $e' "$CACHE" 2>/dev/null >"$tmp" \
        || jq -nc --arg e "$msg" '{fetched_at: 0, error: $e, limits: []}' >"$tmp"
    mv "$tmp" "$CACHE"
}

fetch_locked() { flock -n 9 || exit 0; do_fetch; } # used with 9>"$LOCK"

# --- rendering --------------------------------------------------------------

render() {
    jq -c --argjson stale "$STALE" '
        def color($p):
              if $p >= 90 then "#ff5f5f"
            elif $p >= 75 then "#ffaf5f"
            elif $p >= 50 then "#ffdf5f"
            else                "#a3d18a" end;

        def blabel:
              if .kind == "session"       then "5h"
            elif .kind == "weekly_all"    then "wk"
            elif .kind == "weekly_scoped" then (.scope.model.display_name // "wk*")
            else .kind end;

        ((now | floor) - (.fetched_at // 0)) as $age
        | ($age > $stale) as $old
        | (.error // null) as $err
        | [ (.limits // [])[]
            | select(.kind == "session" or .kind == "weekly_all" or .kind == "weekly_scoped")
            | (.percent // 0) as $p
            | { name: "claude_usage",
                instance: (.kind + (if .scope.model.display_name then ":" + .scope.model.display_name else "" end)),
                full_text: (blabel + " " + ($p|tostring) + "%" + (if $old then "!" else "" end)),
                short_text: (($p|tostring) + "%"),
                color: (if $old then "#8a8a8a" else color($p) end),
                markup: "none",
                separator: false,
                separator_block_width: 6 }
          ]
        | if length == 0
          then [ { name: "claude_usage", full_text: ("claude: " + ($err // "no data")),
                   color: "#8a8a8a", markup: "none", separator: false, separator_block_width: 6 } ]
          else . end
        | (.[-1] |= (.separator = true | .separator_block_width = 12))
    ' "$CACHE" 2>/dev/null || echo '[]'
}

cache_age() {
    local t
    t=$(jq -r '.fetched_at // 0' "$CACHE" 2>/dev/null) || t=0
    echo $(( $(date +%s) - ${t:-0} ))
}

# --- entry points -----------------------------------------------------------

case "${1:-blocks}" in
    fetch)
        exec 9>"$LOCK"; fetch_locked
        ;;
    blocks)
        if [ ! -f "$CACHE" ] || [ "$(cache_age)" -ge "$TTL" ]; then
            setsid "$0" fetch </dev/null >/dev/null 2>&1 &
            disown 2>/dev/null
        fi
        render
        ;;
    show)
        exec 9>"$LOCK"; fetch_locked
        jq -r '(.limits // [])[]
               | select(.kind|test("session|weekly"))
               | "\(.kind)\(if .scope.model.display_name then " ("+.scope.model.display_name+")" else "" end): \(.percent)%"' \
            "$CACHE"
        ;;
    *)
        echo "usage: $0 [blocks|fetch|show]" >&2; exit 2
        ;;
esac
