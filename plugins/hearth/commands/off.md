---
description: Switch this machine back from the Hearth node to its previous Claude Code setup
allowed-tools: ["Bash"]
---

Switch this machine back from the Hearth node to whatever model setup it had before `/hearth:on`.

Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/off.sh
```

The script prints a `STATE=` marker. Reply warm and short, never dumping raw script output. Reply in English, unless the user's conversation language is clearly different, then use that language.

- `STATE=OK`: say Hearth is off and the previous settings are restored, the default model is now MODEL (the value from the `MODEL=` line; if it is `account default`, phrase it as "your account's default model"); tell them to restart Claude Code sessions to pick it up. Mention that the node key stays in the Keychain, so nothing needs to be re-issued.
- `STATE=ALREADY_OFF`: say this machine is not routed through a Hearth node, so there is nothing to switch off.
- `STATE=NO_JQ`: ask them to `brew install jq` and re-run.

ALWAYS end the reply with a one-line "way back" hint: return to the Hearth node anytime with `/hearth:on [node-url]`, or try it per session with `/hearth:on --session` (single sessions via `claude --settings ~/.hearth/settings.json`, machine setup untouched).

Do not read, echo, or log the contents of any Keychain item or key value at any step.
