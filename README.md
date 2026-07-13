---
purpose: Claude Code plugin that points a machine at a Hearth execution node as its model provider
---

# hearth

A Claude Code plugin for using a Hearth execution node as the model provider. A Hearth node is a TEE-hosted, OpenAI/Anthropic-compatible LLM gateway run by a Hearth miner, and the plugin wires your machine to one with a single command. Any Hearth node works the same way, so you can point at whichever miner you like by passing its URL.

## Install

```
/plugin marketplace add hearthchain/claude-plugin
/plugin install hearth@hearthchain
```

## Setup

Ask the node operator for a virtual key, then run `/hearth:install <node-url>`. With no argument it targets the default node `https://moccasin-canidae.vm.scrtlabs.com`.

The command checks that the node answers on `/v1/models`, then asks you to place your key into the macOS Keychain yourself. You run one `security add-generic-password` line in your own terminal, so the key never enters the chat:

```
security add-generic-password -U -s hearth-node -a <node-host> -w '<your-virtual-key>'
```

Once the key is present, re-run `/hearth:install <node-url>`. It installs an `apiKeyHelper` at `~/.hearth/apikey.sh` that reads the key back from the Keychain, then merges the provider env block (`ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`, `ANTHROPIC_SMALL_FAST_MODEL`, gateway model discovery) into `~/.claude/settings.json`, keeping a backup at `~/.claude/settings.json.bak-hearth`. Restart your Claude Code sessions afterwards, since the env is read at startup.

After this, the machine's default `claude` routes through the Hearth node. To undo, restore `~/.claude/settings.json.bak-hearth` over `~/.claude/settings.json`.

## Commands

| Command | What it does |
|---------|--------------|
| `/hearth:install [node-url] [main-model] [fast-model]` | Wire this machine to a node, or switch to a different node by passing its URL. |
| `/hearth:models` | List the node's model catalog. With gateway model discovery enabled the same catalog also appears in the `/model` picker, labeled "From gateway", after a session restart. |
| `/hearth:status` | Report gateway health, the key's spend against its budget, the enclave identity pubkey, and whether the VM attestation endpoint is reachable. |

## Multiple miners

Keys are stored per node hostname in the Keychain (service `hearth-node`, account set to the host), so one machine can hold keys for several nodes at once. Switch between them with `/hearth:install <other-url>`, and the `apiKeyHelper` picks the right key from whichever `ANTHROPIC_BASE_URL` the session points at.

## Requirements

macOS (for the Keychain), `jq`, and a recent Claude Code with plugin support.

## What the node proves

The reference node runs inside a SecretVM Intel TDX confidential VM. Its attestation, the TDX quote together with the measured workload definition, is served on port 29343 of the node host, so a client can verify what code the enclave is running before trusting it. The execution node itself lives in the `hearthchain/miner` repo.
