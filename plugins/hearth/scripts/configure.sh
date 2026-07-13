#!/usr/bin/env bash
# Wire this machine to a Hearth node: verify the node, check the Keychain key,
# install the apiKeyHelper, and merge the env block into ~/.claude/settings.json.
# Idempotent; run again with a different URL to switch miners.
#
# Usage: configure.sh <node-url> [main-model] [fast-model]
set -euo pipefail

url=${1:?usage: configure.sh <node-url> [main-model] [fast-model]}
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
  echo "RERUN=/hearth:install $url"
  exit 0
fi

mkdir -p "$HOME/.hearth"
cp "$(cd "$(dirname "$0")" && pwd)/apikey.sh" "$HOME/.hearth/apikey.sh"
chmod +x "$HOME/.hearth/apikey.sh"

settings="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[ -f "$settings" ] || printf '{}\n' > "$settings"
cp "$settings" "$settings.bak-hearth"
jq --arg url "$url" --arg helper "$HOME/.hearth/apikey.sh" \
   --arg main "$main_model" --arg fast "$fast_model" \
   '.apiKeyHelper = $helper
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
echo "BACKUP=$settings.bak-hearth"
