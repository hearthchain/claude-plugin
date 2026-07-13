---
description: List the model catalog of the configured Hearth node
allowed-tools: ["Bash"]
---

List the models served by the Hearth node this machine is configured for.

Run:

```
curl -s "$ANTHROPIC_BASE_URL/v1/models" -H "Authorization: Bearer $(bash $HOME/.hearth/apikey.sh)" | jq -r '.data[].id'
```

If `ANTHROPIC_BASE_URL` is empty or the helper is missing, tell the user to run `/hearth:install` first.

Present the result as a short list. Skip wildcard entries (ids containing `*`) but mention that any upstream id matching those wildcards can be used too. Remind the user they can switch with `/model <id>` inside a session, and that with gateway model discovery enabled the same catalog appears in the `/model` picker labeled "From gateway" after a session restart.

Never print the key value itself.
