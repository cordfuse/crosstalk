#!/usr/bin/env bash
# Portable crosstalk watcher — the agent-agnostic wake (SPEC §2 escape hatch:
# a plain poll loop, like cron/systemd). Works for ANY runtime — agy, gemini,
# opencode, a human — regardless of whether it has a hook system.
#
# Loops: sync + inbox. On a NEW set of unread mail it prints the summary and,
# if you set CROSSTALK_ON_MAIL, runs that command. It NEVER launches or
# supervises an agent itself — spawning is the operator's choice via
# CROSSTALK_ON_MAIL, kept outside the tool (SPEC §2: delivery, never behavior).
# No LLM runs in this loop; inference happens only in whatever you wire up.
#
# Env:
#   CROSSTALK_HANDLE    who to poll for (required)
#   CROSSTALK_MESH      mesh repo path (default: cwd)
#   CROSSTALK_BIN       crosstalk binary (default: sp)
#   CROSSTALK_INTERVAL  seconds between polls (default: 30)
#   CROSSTALK_ON_MAIL   optional command run when new mail appears (e.g. a
#                       desktop notification, or a nudge into a running session)

set -u
CT="${CROSSTALK_BIN:-ct}"
interval="${CROSSTALK_INTERVAL:-30}"
[ -n "${CROSSTALK_MESH:-}" ] && cd "$CROSSTALK_MESH"
[ -z "${CROSSTALK_HANDLE:-}" ] && { echo "crosstalk-watch: set CROSSTALK_HANDLE" >&2; exit 1; }

echo "crosstalk-watch: polling for '$CROSSTALK_HANDLE' every ${interval}s (Ctrl-C to stop)" >&2
last=""
while true; do
  # option B: the watcher is the unsandboxed edge — flush any mail an agent
  # wrote but couldn't commit (outgoing), then poll for incoming.
  "$CT" flush >/dev/null 2>&1
  mail=$("$CT" inbox --json 2>/dev/null || echo '[]')
  ids=$(printf '%s' "$mail" | jq -r '.[].id' 2>/dev/null | sort | tr '\n' ',')
  if [ -n "$ids" ] && [ "$ids" != "$last" ]; then
    last="$ids"
    printf '%s' "$mail" | jq -r '.[] | "  new mail: [\(.kind)] \(.from): \(.subject) (\(.id))"'
    [ -n "${CROSSTALK_ON_MAIL:-}" ] && eval "$CROSSTALK_ON_MAIL"
  fi
  sleep "$interval"
done
