#!/usr/bin/env bash
# Undo on.sh: strip the Hearth provider block from ~/.claude/settings.json and
# restore whatever values those keys had before Hearth was turned on, from the
# snapshot at ~/.hearth/pre-hearth-settings.json. The Keychain key and
# ~/.hearth/apikey.sh are kept so /hearth:on re-enables without re-onboarding.
#
# Usage: off.sh
set -euo pipefail

command -v jq >/dev/null || { echo "STATE=NO_JQ"; exit 0; }

settings="$HOME/.claude/settings.json"
snapshot="$HOME/.hearth/pre-hearth-settings.json"

on_now=""
if [ -f "$settings" ]; then
  on_now=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$settings")
fi
if [ -z "$on_now" ] && [ ! -f "$snapshot" ]; then
  echo "STATE=ALREADY_OFF"
  exit 0
fi

[ -f "$settings" ] || printf '{}\n' > "$settings"

jq 'del(.apiKeyHelper, .model)
    | .env = ((.env // {})
        | del(.ANTHROPIC_BASE_URL, .ANTHROPIC_MODEL, .ANTHROPIC_SMALL_FAST_MODEL,
              .CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY))' \
  "$settings" > "$settings.tmp"

if [ -f "$snapshot" ]; then
  jq --slurpfile saved "$snapshot" \
     '($saved[0]) as $s
      | (if $s.apiKeyHelper != null then .apiKeyHelper = $s.apiKeyHelper else . end)
      | (if $s.model != null then .model = $s.model else . end)
      | .env = (.env + ($s.env // {}))' \
    "$settings.tmp" > "$settings.tmp2"
  mv "$settings.tmp2" "$settings.tmp"
fi

jq 'if .env == {} then del(.env) else . end' "$settings.tmp" > "$settings.tmp2"
mv "$settings.tmp2" "$settings.tmp"
mv "$settings.tmp" "$settings"
rm -f "$snapshot"

echo "STATE=OK"
echo "MODEL=$(jq -r '.model // "account default"' "$settings")"
