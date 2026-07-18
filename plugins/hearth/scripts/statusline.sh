#!/usr/bin/env bash
# Status line: model, node host, cached verdict from ~/.hearth/verify.json.
# Glyphs: ✔ ok, ◐ partial, ✖ fail (treat as MITM), … no verdict yet.
set -uo pipefail

input=$(cat 2>/dev/null || true)
model=$(jq -r '.model.display_name // .model.id // empty' <<<"$input" 2>/dev/null || true)

url="${ANTHROPIC_BASE_URL:-}"
host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#[/:].*$##')

if [ -z "$host" ]; then
  printf '%s' "${model:-}"
  exit 0
fi

verdict="…" detail=""
out="$HOME/.hearth/verify.json"
if [ -f "$out" ] && [ "$(jq -r .host "$out" 2>/dev/null)" = "$host" ]; then
  overall=$(jq -r .overall "$out")
  case "$overall" in
    ok) verdict="✔" detail="attested, TLS pinned" ;;
    partial) verdict="◐" detail=$(jq -r '[
        {quote, dcap, tls, signature} | to_entries[] | select(.value != "ok") | "\(.key) \(.value)"
      ] | join(", ")' "$out") ;;
    fail) verdict="✖" detail=$(jq -r '.reason // "verification failed"' "$out") ;;
  esac
  # Refresh in background when stale.
  age=$(( $(date +%s) - $(jq -r '.checked_epoch // 0' "$out") ))
  [ "$age" -lt 900 ] || ANTHROPIC_BASE_URL="$url" "$(dirname "$0")/verify.sh" --hook >/dev/null 2>&1 || true
else
  ANTHROPIC_BASE_URL="$url" "$(dirname "$0")/verify.sh" --hook >/dev/null 2>&1 || true
fi

printf '🔥 Hearth %s %s%s%s' "$verdict" "$host" "${model:+ · }" "${model:-}"
[ -z "$detail" ] || printf ' (%s)' "$detail"
