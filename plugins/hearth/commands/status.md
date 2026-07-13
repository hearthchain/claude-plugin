---
description: Health, attestation, and key budget of the configured Hearth node
allowed-tools: ["Bash"]
---

Report the status of the Hearth node this machine is configured for. The node host is the hostname part of `$ANTHROPIC_BASE_URL`; if it is empty, tell the user to run `/hearth:on` first.

Gather, tolerating individual failures:

1. Gateway: `curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$ANTHROPIC_BASE_URL/v1/models"` without auth; 401 means up and enforcing keys.
2. Key budget: `curl -s --max-time 8 "$ANTHROPIC_BASE_URL/key/info" -H "Authorization: Bearer $(bash $HOME/.hearth/apikey.sh)" | jq '{alias: .info.key_alias, spend: .info.spend, max_budget: .info.max_budget, expires: .info.expires}'`
3. Enclave identity: `curl -s --max-time 8 "http://<host>:8471/v1/pubkey"` (expected on SecretVM: a pubkey with `"attested": false`; the VM-level attestation is the authoritative one).
4. VM attestation reachable: `curl -sk -o /dev/null -w '%{http_code}' --max-time 8 "https://<host>:29343/self.html"` (SecretVM attestation endpoint; 200 means the measured-VM report is being served).

Summarize in a few lines, in English unless the user's conversation language is clearly different: gateway up/down, remaining budget (max_budget minus spend), identity pubkey (short prefix) and attested flag, attestation endpoint availability. End with a one-line hint that `/hearth:off` switches the machine back to its regular Anthropic setup. Never print the key value.
