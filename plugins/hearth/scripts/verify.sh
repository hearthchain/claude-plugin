#!/usr/bin/env bash
# Verify the Hearth node this session points at and cache the verdict in
# ~/.hearth/verify.json for the status line and /hearth:status.
#
# Checks, each degrading gracefully rather than failing the whole run:
#   quote      report_data[0:32] inside the DCAP quote equals the served pubkey
#   dcap       Intel signature + TCB verdict via secretvm-cli (skipped if absent)
#   tls        /v1/tls endorsement SPKI equals the cert the public :443 presents
#   signature  Ed25519 endorsement signature (needs OpenSSL 3; LibreSSL skips)
#
# overall: ok (nothing failed, nothing skipped), partial (something skipped or
# /v1/tls not deployed yet), fail (a hard mismatch: possible MITM or bad node).
#
# Usage: verify.sh [--hook]
#   --hook: SessionStart mode. Instant when the cache is fresh (<15 min);
#   otherwise kicks a background refresh and returns immediately, so session
#   start never blocks on the network. Prints one context line either way.
set -euo pipefail

hearth_dir="$HOME/.hearth"
out="$hearth_dir/verify.json"
lock="$hearth_dir/verify.lock"
fresh_secs=900
rd_offset=568 # report_data offset in the TDX v4 quote (TD10 body offset 520)

url="${ANTHROPIC_BASE_URL:-}"
host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#[/:].*$##')

mode="${1:-}"

# Not a Hearth session: nothing to verify, nothing to print.
[ -n "$host" ] || exit 0
command -v jq >/dev/null || exit 0

emit_line() {
  [ "$mode" = "--hook" ] || return 0
  if [ -f "$out" ] && [ "$(jq -r .host "$out")" = "$host" ]; then
    jq -r '"Hearth node \(.host): verification \(.overall) (quote \(.quote), dcap \(.dcap), tls \(.tls), signature \(.signature), checked \(.checked_at))"' "$out"
  else
    echo "Hearth node $host: verification running in background; the status line updates when it lands."
  fi
}

fresh() {
  [ -f "$out" ] || return 1
  [ "$(jq -r .host "$out")" = "$host" ] || return 1
  local now age
  now=$(date +%s)
  age=$(( now - $(jq -r '.checked_epoch // 0' "$out") ))
  [ "$age" -lt "$fresh_secs" ]
}

if [ "$mode" = "--hook" ]; then
  if fresh; then
    emit_line
    exit 0
  fi
  # Background refresh; mkdir is the portable lock, stale after 5 min.
  if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then rmdir "$lock" 2>/dev/null || true; fi
  if mkdir "$lock" 2>/dev/null; then
    ( trap 'rmdir "$lock" 2>/dev/null' EXIT; "$0" >/dev/null 2>&1 || true ) &
    disown 2>/dev/null || true
  fi
  emit_line
  exit 0
fi

# Synchronous full check from here on.
mkdir -p "$hearth_dir"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gateway="down" quote="unreachable" dcap="skipped" tls="unavailable" signature="skipped" pubkey="" reason=""

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$url/v1/models" || true)
case "$code" in 200|401) gateway="up" ;; esac

if curl -sf --max-time 8 "http://$host:8471/v1/quote" > "$tmp/quote.json" 2>/dev/null; then
  pubkey=$(jq -r '.pubkey // empty' "$tmp/quote.json")
  jq -r '.quote // empty' "$tmp/quote.json" | base64 -d 2>/dev/null | xxd -p -c 256 | tr -d '\n' > "$tmp/quote.hex" || true
  report_data=$(cut -c $((rd_offset * 2 + 1))-$(((rd_offset + 32) * 2)) "$tmp/quote.hex" 2>/dev/null || true)
  if [ -n "$pubkey" ] && [ "$report_data" = "$pubkey" ]; then
    quote="ok"
  elif [ -n "$pubkey" ]; then
    quote="fail"; reason="report_data does not bind the served pubkey"
  fi
  if [ "$quote" = "ok" ] && command -v secretvm-cli >/dev/null; then
    verdict=$(secretvm-cli verify quote --quote-file "$tmp/quote.hex" --attestation-type tdx 2>/dev/null || true)
    case "$(jq -r 'if .result.ok == true and .result.status.result == "0" then "ok" else "fail" end' <<<"$verdict" 2>/dev/null || echo err)" in
      ok) dcap="ok" ;;
      fail) dcap="fail"; reason="DCAP verdict not OK" ;;
      *) dcap="skipped" ;;
    esac
  fi
fi

tls_code=$(curl -s -o "$tmp/tls.json" -w '%{http_code}' --max-time 8 "http://$host:8471/v1/tls" || true)
if [ "$tls_code" = "200" ]; then
  spki=$(jq -r '.spki_sha256 // empty' "$tmp/tls.json")
  live_spki=$(openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null \
    | openssl x509 -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null \
    | shasum -a 256 | cut -d' ' -f1)
  if [ -z "$spki" ]; then
    tls="fail"; reason="endorsement malformed"
  elif [ -n "$pubkey" ] && [ "$(jq -r .pubkey "$tmp/tls.json")" != "$pubkey" ]; then
    tls="fail"; reason="/v1/tls pubkey differs from /v1/quote"
  elif [ "$live_spki" != "$spki" ]; then
    tls="fail"; reason="endorsed SPKI does not match the live :443 certificate (possible MITM)"
  else
    tls="ok"
    # Endorsement message: tag NUL spki(32) not_after(8 BE) nonce_len(1) nonce (miner internal/enclave/endorse.go).
    not_after=$(jq -r .not_after "$tmp/tls.json")
    {
      printf 'hearth-tls-endorsement-v1'
      printf '\0'
      printf '%s' "$spki" | xxd -r -p
      printf '%016x' "$not_after" | xxd -r -p
      printf '%02x' $(( ${#nonce} / 2 )) | xxd -r -p
      printf '%s' "$nonce" | xxd -r -p
    } > "$tmp/msg.bin"
    jq -r .signature "$tmp/tls.json" | xxd -r -p > "$tmp/sig.bin"
    printf '302a300506032b6570032100%s' "$(jq -r .pubkey "$tmp/tls.json")" | xxd -r -p > "$tmp/pub.der"
    # Ed25519 needs OpenSSL 3 (pkeyutl -rawin); macOS LibreSSL lacks it, so hunt for a Homebrew one. Without a
    # capable openssl the check stays "skipped" and overall degrades to partial, never to a false "ok".
    ossl="openssl"
    for candidate in /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl; do
      [ -x "$candidate" ] && ossl="$candidate" && break
    done
    if "$ossl" pkeyutl -help 2>&1 | grep -q rawin; then
      if "$ossl" pkeyutl -verify -pubin -inkey "$tmp/pub.der" -keyform DER -rawin \
           -in "$tmp/msg.bin" -sigfile "$tmp/sig.bin" >/dev/null 2>&1; then
        signature="ok"
      else
        signature="invalid"; reason="endorsement signature does not verify"
      fi
    fi
  fi
fi

overall="partial"
if [ "$quote" = "fail" ] || [ "$tls" = "fail" ] || [ "$signature" = "invalid" ] || [ "$dcap" = "fail" ]; then
  overall="fail"
elif [ "$quote" = "ok" ] && [ "$dcap" = "ok" ] && [ "$tls" = "ok" ] && [ "$signature" = "ok" ]; then
  overall="ok"
fi

jq -n --arg host "$host" --arg gateway "$gateway" --arg quote "$quote" --arg dcap "$dcap" \
      --arg tls "$tls" --arg signature "$signature" --arg overall "$overall" --arg reason "$reason" \
      --arg pubkey "$pubkey" --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson epoch "$(date +%s)" \
   '{host: $host, gateway: $gateway, quote: $quote, dcap: $dcap, tls: $tls, signature: $signature,
     overall: $overall, reason: $reason, pubkey: $pubkey, checked_at: $checked_at, checked_epoch: $epoch}' \
   > "$out.tmp"
mv "$out.tmp" "$out"

emit_line
