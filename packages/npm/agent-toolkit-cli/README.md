# agent-toolkit-cli (npm)

Thin Node launcher for the **native V** `agent-toolkit` binary. Same product name as PyPI: **`agent-toolkit-cli`**.

```bash
npm install -g agent-toolkit-cli
agent-toolkit --help
```

The installer pulls a platform package via `optionalDependencies` (`agent-toolkit-cli-<os>-<cpu>`). Those packages contain GitHub Release V binaries (ADR-018 / ADR-025), not a second CLI.

Dev override: `AGENT_TOOLKIT_BIN=/path/to/agent-toolkit`.

Publish: GitHub Actions OIDC trusted publishing (`.github/workflows/publish-npm.yml`). No long-lived `NPM_TOKEN`.
