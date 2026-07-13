---
description: Wire this machine to a Hearth node (Keychain key, apiKeyHelper, settings.json)
argument-hint: "[node-url] [main-model] [fast-model]"
allowed-tools: ["Bash"]
---

Configure this machine to use a Hearth execution node as the model provider for Claude Code.

Node URL: use `$ARGUMENTS` if given; default is `https://moccasin-canidae.vm.scrtlabs.com`. Any other Hearth miner works the same way, that is the point of the argument.

Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/configure.sh <node-url> [main-model] [fast-model]
```

Interpret the result for the user:

- `OK`: report the configured node URL and models, mention the settings backup path, and tell the user to restart their Claude Code sessions (the env is read at startup). Warn that this machine's default `claude` now routes through the Hearth node; to undo, restore `~/.claude/settings.json.bak-hearth`.
- `ERR_NO_KEY` (exit 2): relay the exact `security add-generic-password` command from the script output. IMPORTANT: the user must paste their virtual key in their own terminal, never into this chat. Then re-run this command.
- `ERR_NODE_UNREACHABLE` (exit 3): the node did not answer on `/v1/models`; show the HTTP code and suggest checking the URL or the node operator.
- `ERR_NOT_MACOS` / `ERR_NO_JQ`: relay as-is.

Do not read, echo, or log the contents of any Keychain item or key value at any step.
