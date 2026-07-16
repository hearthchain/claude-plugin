---
description: List the model catalog of the configured Hearth node
allowed-tools: ["Bash"]
---

List the models served by the Hearth node this machine is configured for.

Run:

```
curl -s "$ANTHROPIC_BASE_URL/v1/models" -H "Authorization: Bearer $(bash $HOME/.hearth/apikey.sh)" | jq -r '.data[].id'
```

If `ANTHROPIC_BASE_URL` is empty or the helper is missing, tell the user to run `/hearth:on` first.

Present the result as a short list, in English unless the user's conversation language is clearly different. Skip wildcard entries (ids containing `*`) but mention that any upstream id matching those wildcards can be used too. Remind the user they can switch with `/model <id>` inside a session, and that with gateway model discovery enabled the same catalog appears in the `/model` picker labeled "From gateway" after a session restart. End with a one-line hint that `/hearth:off` switches the machine back to its regular Anthropic setup.

The node answers `/v1/models` with the models the caller's key is scoped to, not the full node catalog. If the list contains ONLY wildcard entries (for example a bare `nebius/*`), explain that the virtual key is wildcard-scoped, which also collapses the `/model` picker to that single entry, and that the node operator can fix it by re-scoping the key to concrete ids (`/key/update`; keys issued by the miner repo's `issue-key.sh` are already concrete). Concrete ids passed to `/model <id>` still work regardless.

Never print the key value itself.
