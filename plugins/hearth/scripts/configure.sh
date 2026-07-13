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

command -v security >/dev/null || { echo "ERR_NOT_MACOS: only macOS Keychain is supported for now"; exit 4; }
command -v jq >/dev/null || { echo "ERR_NO_JQ: install jq first (brew install jq)"; exit 5; }

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url/v1/models" || true)
case "$code" in
  200|401) ;;
  *) echo "ERR_NODE_UNREACHABLE: $url/v1/models answered '$code'"; exit 3 ;;
esac

if ! security find-generic-password -s hearth-node -a "$host" >/dev/null 2>&1; then
  echo "ERR_NO_KEY: no Keychain item for $host."
  echo "Run in your terminal (paste the virtual key you were issued, not here):"
  echo "  security add-generic-password -U -s hearth-node -a $host -w '<your-virtual-key>'"
  echo "then re-run /hearth:install $url"
  exit 2
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

echo "OK: $url (host $host, main $main_model, fast $fast_model)"
echo "Backup of previous settings: $settings.bak-hearth"
echo "Restart Claude Code sessions to pick this up."
