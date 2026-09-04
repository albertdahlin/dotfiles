# Claude usage in i3bar

Shows three percentages, left of the normal i3status output:

    5h 20%   wk 38%   Fable 54%

* `5h`    – current session (5-hour) usage
* `wk`    – current week, all models
* `Fable` – current week, Fable only (any model-scoped weekly limit is shown
            under its own name, so this adapts if the scoped model changes)

Colour: green < 50 %, yellow ≥ 50 %, orange ≥ 75 %, red ≥ 90 %.
A trailing `!` in grey means the numbers are older than 10 minutes
(no network, revoked token, …) — the last good values stay on screen.

## Files

| file                       | what it does |
|----------------------------|--------------|
| `i3/claude-usage.sh`       | talks to the API, caches to `~/.cache/claude-usage.json`, renders i3bar blocks |
| `i3/i3status-wrapper.sh`   | runs `i3status` and prepends those blocks — this is the `status_command` |
| `i3status.conf`            | symlinked to `~/.i3status.conf`; copy of the distro default plus `output_format = "i3bar"`, which the wrapper needs |

`i3/config` has:

    bar {
            status_command ~/.i3/i3status-wrapper.sh
    }

Both scripts live next to `config`, and the wrapper finds `claude-usage.sh`
relative to itself, so `~/.i3 -> dotfiles/i3` is all the installation there is.

## How it gets the data

`GET https://api.anthropic.com/api/oauth/usage?at_wall=1&skip_spend=1` with the
OAuth access token from `~/.claude/.credentials.json` — the same call Claude
Code's `/usage` makes. The response's `limits[]` array is used directly, so the
labels come from the server.

The bar re-renders every 5 s from cache; the API is polled at most once every
60 s, in a detached background process, so i3bar never blocks on the network.

## Token refresh

Claude Code's access token lasts ~8 hours. When the API answers 401/403,
`claude-usage.sh` exchanges the refresh token at
`https://platform.claude.com/v1/oauth/token` and writes the new token back into
`~/.claude/.credentials.json`, keeping every other field and leaving the
previous file at `~/.claude/.credentials.json.bak`.

Set `CLAUDE_USAGE_NO_REFRESH=1` if you would rather it never wrote to that
file — the bar then goes grey/stale until the next time you run `claude`, which
refreshes the token itself.

## Knobs

Environment variables read by `claude-usage.sh`:

    CLAUDE_USAGE_TTL=60          seconds between API polls
    CLAUDE_USAGE_STALE=600       seconds before values are marked stale
    CLAUDE_USAGE_NO_REFRESH=0    1 = never write to the credentials file
    CLAUDE_CREDENTIALS=~/.claude/.credentials.json

## Testing

    ~/.i3/claude-usage.sh show      # fetch now, print plain text
    ~/.i3/claude-usage.sh blocks    # the JSON i3bar sees
    ~/.i3/claude-usage.sh fetch     # refresh the cache
