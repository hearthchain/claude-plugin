---
description: Health, attestation, and key budget of the configured Hearth node
allowed-tools: ["Bash"]
---

Report the status of the Hearth node this machine is configured for. The node host is the hostname part of `$ANTHROPIC_BASE_URL`; if it is empty, tell the user to run `/hearth:on` first.

Gather, tolerating individual failures:

1. Gateway: `curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$ANTHROPIC_BASE_URL/v1/models"` without auth; 401 means up and enforcing keys.
2. Key budget: `curl -s --max-time 8 "$ANTHROPIC_BASE_URL/key/info" -H "Authorization: Bearer $(bash $HOME/.hearth/apikey.sh)" | jq '{alias: .info.key_alias, spend: .info.spend, max_budget: .info.max_budget, expires: .info.expires}'`
3. Verification: run `bash $HOME/.hearth/verify.sh` (synchronous full check; if the file is missing, tell the user to re-run `/hearth:on` to install it), then read `$HOME/.hearth/verify.json`. It reports: `quote` (report_data binds the served pubkey), `dcap` (Intel signature + TCB via secretvm-cli, `skipped` when the CLI is absent), `tls` (the enclave key's `/v1/tls` endorsement matches the certificate the public :443 actually presents; `unavailable` until the node ships the endpoint), `signature` (Ed25519 endorsement check, needs OpenSSL 3), and `overall` (ok / partial / fail).
4. VM attestation reachable: `curl -sk -o /dev/null -w '%{http_code}' --max-time 8 "https://<host>:29343/self.html"` (SecretVM attestation endpoint; 200 means the measured-VM report is being served).

Summarize in a few lines, in English unless the user's conversation language is clearly different: gateway up/down, remaining budget (max_budget minus spend), then the verification verdict with its component checks, flagging `overall: fail` as a possible MITM that must not be ignored (name the failing check and the `reason` field). A `partial` verdict is normal while the node has not yet deployed `/v1/tls` or when secretvm-cli / OpenSSL 3 are missing locally; say which piece was skipped. End with a one-line hint that `/hearth:off` switches the machine back to its regular Anthropic setup. Never print the key value.
