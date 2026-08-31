# OpenCode Profile

Files in this directory configure [OpenCode](https://opencode.ai) for use with agent-toolkit.

## Installation

```bash
agent-toolkit install --tools opencode
```

Or manually:

```bash
cp profiles/opencode/opencode.json ~/.config/opencode/opencode.json
cp -r profiles/opencode/agents/. ~/.config/opencode/agents/
```

## Configuration

`opencode.json` ships with minimal defaults. Customize your model in `~/.config/opencode/opencode.json`:

```json
{
  "model": "anthropic/claude-sonnet-4-5",
  "provider": {
    "my-provider": {
      "baseURL": "https://...",
      "apiKey": "${MY_PROVIDER_API_KEY}"
    }
  }
}
```

Use `${ENV_VAR}` syntax for credentials — never commit API keys.

## Agents

The `agents/` directory contains agent personas for OpenCode. These are discovered
automatically when placed in `~/.config/opencode/agents/`.

## Supported tools

- OpenCode 0.3+ required for agent support
- OpenCode 0.1+ for basic model configuration
