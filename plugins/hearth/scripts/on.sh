#!/usr/bin/env bash
# Point this machine at a Hearth node: verify the node, check the Keychain key,
# install the apiKeyHelper, and merge the provider env block into
# ~/.claude/settings.json. Before the first change it snapshots the prior
# values of every key it manages to ~/.hearth/pre-hearth-settings.json; the
# snapshot doubles as the "Hearth is on" marker and is what off.sh restores.
# Re-running while on (to switch node or models) never touches the snapshot.
#
# It also always writes ~/.hearth/settings.json, a self-contained provider
# block for `claude --settings ~/.hearth/settings.json`: one Hearth session
# without changing the machine-wide setup. With --session, that file is ALL
# it writes; ~/.claude/settings.json stays untouched.
#
# Usage: on.sh [--session] [node-url] [main-model] [fast-model]
set -euo pipefail

session_only=0
if [ "${1:-}" = "--session" ]; then session_only=1; shift; fi

url=${1:-https://moccasin-canidae.vm.scrtlabs.com}
url=${url%/}
main_model=${2:-nebius/moonshotai/Kimi-K2.7-Code}
fast_model=${3:-nebius/Qwen/Qwen3-30B-A3B-Instruct-2507}
host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#[/:].*$##')

# Expected onboarding states exit 0 with a STATE= marker so the harness does
# not render them as scary red errors; only real faults exit non-zero.
command -v security >/dev/null || { echo "STATE=NOT_MACOS"; exit 0; }
command -v jq >/dev/null || { echo "STATE=NO_JQ"; exit 0; }

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url/v1/models" || true)
case "$code" in
  200|401) ;;
  *) echo "STATE=UNREACHABLE"; echo "HTTP=$code"; echo "URL=$url"; exit 0 ;;
esac

if ! security find-generic-password -s hearth-node -a "$host" >/dev/null 2>&1; then
  echo "STATE=NO_KEY"
  echo "HOST=$host"
  echo "ADD_CMD=security add-generic-password -U -s hearth-node -a $host -w '<your-virtual-key>'"
  echo "RERUN=/hearth:on $url"
  exit 0
fi

mkdir -p "$HOME/.hearth"
cp "$(cd "$(dirname "$0")" && pwd)/apikey.sh" "$HOME/.hearth/apikey.sh"
chmod +x "$HOME/.hearth/apikey.sh"

# Session-scoped provider block. It carries its own "model": a user-scope
# model setting would otherwise override ANTHROPIC_MODEL and ask the node for
# an Anthropic model id it does not serve.
jq -n --arg url "$url" --arg helper "$HOME/.hearth/apikey.sh" \
      --arg main "$main_model" --arg fast "$fast_model" \
   '{apiKeyHelper: $helper,
     model: $main,
     env: {
       ANTHROPIC_BASE_URL: $url,
       ANTHROPIC_MODEL: $main,
       ANTHROPIC_SMALL_FAST_MODEL: $fast,
       CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY: "1"
     }}' > "$HOME/.hearth/settings.json"

session_cmd="claude --settings $HOME/.hearth/settings.json"

if [ "$session_only" = 1 ]; then
  echo "STATE=OK_SESSION"
  echo "URL=$url"
  echo "MAIN=$main_model"
  echo "FAST=$fast_model"
  echo "SESSION_CMD=$session_cmd"
  exit 0
fi

settings="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[ -f "$settings" ] || printf '{}\n' > "$settings"

snapshot="$HOME/.hearth/pre-hearth-settings.json"
if [ ! -f "$snapshot" ]; then
  jq '{apiKeyHelper: (.apiKeyHelper // null),
       model: (.model // null),
       env: ((.env // {}) | with_entries(select(.key | IN(
         "ANTHROPIC_BASE_URL", "ANTHROPIC_MODEL", "ANTHROPIC_SMALL_FAST_MODEL",
         "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"))))}' \
    "$settings" > "$snapshot"
fi

# A top-level "model" in settings.json silently overrides ANTHROPIC_MODEL, so
# sessions would keep asking the node for the old (Anthropic) model id; drop it
# while Hearth is on and let off.sh restore it from the snapshot.
jq --arg url "$url" --arg helper "$HOME/.hearth/apikey.sh" \
   --arg main "$main_model" --arg fast "$fast_model" \
   '.apiKeyHelper = $helper
    | del(.model)
    | .env = (.env // {}) + {
        ANTHROPIC_BASE_URL: $url,
        ANTHROPIC_MODEL: $main,
        ANTHROPIC_SMALL_FAST_MODEL: $fast,
        CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY: "1"
      }' "$settings" > "$settings.tmp"
mv "$settings.tmp" "$settings"

echo "STATE=OK"
echo "URL=$url"
echo "MAIN=$main_model"
echo "FAST=$fast_model"
echo "SESSION_CMD=$session_cmd"
