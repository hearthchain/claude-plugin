---
description: Route Claude Code through a Hearth node, machine-wide or per session (Keychain key, apiKeyHelper, settings.json)
argument-hint: "[--session] [node-url] [main-model] [fast-model]"
allowed-tools: ["Bash"]
---

Route Claude Code through a Hearth execution node as the model provider.

Two scopes:

- default: machine-wide, every new session on this machine uses the node.
- `--session`: touch nothing machine-wide; only prepare `~/.hearth/settings.json` so the user can launch individual Hearth sessions with `claude --settings ~/.hearth/settings.json`. Use this scope when the user passes `--session` or asks for it in words (one session only, just this once, without switching the machine, and similar).

A running session cannot change its provider (the provider env is read at startup), so never promise that THIS session will switch; a new session or a restart is always required.

Node URL: use `$ARGUMENTS` if given; default is `https://moccasin-canidae.vm.scrtlabs.com`. Any other Hearth miner works the same way, that is the point of the argument.

Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/on.sh [--session] <node-url> [main-model] [fast-model]
```

The script prints a `STATE=` marker. Reply warm and short, never dumping raw script output. Reply in English, unless the user's conversation language is clearly different, then use that language. Never assume a language from the machine locale; there is no hard-coded language anywhere in this plugin.

- `STATE=OK`: congratulate briefly; say the machine now talks to the node at URL with MAIN as the model (FAST for background tasks); tell them to restart Claude Code sessions to pick it up.
- `STATE=OK_SESSION`: say the machine-wide setup was NOT touched; to start a Hearth session, run SESSION_CMD (show it as a code block) in the terminal; plain `claude` keeps using their regular setup.
- `STATE=NO_KEY`: this is the normal first-run stop, not an error. Say something like: "Hearth is not a permissionless network yet, so a node operator issues your API key. Once you have it, put it in your Keychain (paste the key in your own terminal, never into this chat)", then show ADD_CMD as a code block and say to re-run RERUN afterwards.
- `STATE=UNREACHABLE`: the node at URL did not answer (HTTP code in HTTP=). Suggest checking the URL spelling or asking the node operator; mention they can pass another node URL as an argument.
- `STATE=NOT_MACOS`: only macOS Keychain is supported so far; suggest asking the node operator about manual setup (env vars ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN).
- `STATE=NO_JQ`: ask them to `brew install jq` and re-run.

ALWAYS end the reply with a short "way back" hint, whatever the state:

- after `STATE=OK`: switch models inside the node with `/model <id>` (catalog: `/hearth:models`); return to your regular Anthropic setup anytime with `/hearth:off`; or use `/hearth:on --session` next time to try a node without switching the machine.
- after `STATE=OK_SESSION`: your regular setup is untouched; sessions started with SESSION_CMD use the node, everything else stays as is.
- after any other state: nothing was changed; your current setup is untouched.

Do not read, echo, or log the contents of any Keychain item or key value at any step.
