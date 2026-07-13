#!/usr/bin/env bash
# apiKeyHelper for Claude Code: returns the virtual key for the Hearth node
# this session points at. Keys live in the macOS Keychain as service
# `hearth-node`, account = node hostname, so one machine can hold keys for
# several miners and the right one is picked from ANTHROPIC_BASE_URL.
set -euo pipefail
host=$(printf '%s' "${ANTHROPIC_BASE_URL:-}" | sed -E 's#^[a-z]+://##; s#[/:].*$##')
security find-generic-password -w -s hearth-node -a "$host" 2>/dev/null \
  || security find-generic-password -w -s hearth-node 2>/dev/null \
  || { echo "no Keychain item hearth-node for $host; run /hearth:on" >&2; exit 1; }
