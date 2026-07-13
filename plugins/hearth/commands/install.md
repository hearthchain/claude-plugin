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

The script prints a `STATE=` marker. Reply to the user in THEIR language, warm and short, never dumping raw script output:

- `STATE=OK`: congratulate briefly; say the machine now talks to the node at URL with MAIN as the model (FAST for background tasks); tell them to restart Claude Code sessions to pick it up; add one soft caveat that the default `claude` now routes through the Hearth node and the previous settings are saved at BACKUP if they ever want to switch back.
- `STATE=NO_KEY`: this is the normal first-run stop, not an error. Say something like: "Hearth is not a permissionless network yet, so a node operator issues your API key. Once you have it, put it in your Keychain (paste the key in your own terminal, never into this chat)", then show ADD_CMD as a code block and say to re-run RERUN afterwards.
- `STATE=UNREACHABLE`: the node at URL did not answer (HTTP code in HTTP=). Suggest checking the URL spelling or asking the node operator; mention they can pass another node URL as an argument.
- `STATE=NOT_MACOS`: only macOS Keychain is supported so far; suggest asking the node operator about manual setup (env vars ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN).
- `STATE=NO_JQ`: ask them to `brew install jq` and re-run.

Do not read, echo, or log the contents of any Keychain item or key value at any step.
