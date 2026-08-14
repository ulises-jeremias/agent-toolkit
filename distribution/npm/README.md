# npm adapter

**Issue:** [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536) · **ADR:** [ADR-025](../../docs/adrs/ADR-025-npm-binary.md) ([#487](https://github.com/ulises-jeremias/agent-toolkit/issues/487))

Published name: **`agent-toolkit-cli`** (same as PyPI). Node is a launcher only; the product is the GitHub Release V binary (ADR-018).

| Package | Role |
|---------|------|
| `agent-toolkit-cli` | Meta-package; `bin.agent-toolkit` → `packages/npm/agent-toolkit-cli/bin/agent-toolkit.js` |
| `agent-toolkit-cli-linux-x64` | glibc ELF (`os=linux`, `cpu=x64`, `libc=glibc`) |
| `agent-toolkit-cli-linux-arm64` | glibc ELF |
| `agent-toolkit-cli-darwin-arm64` | Mach-O |
| `agent-toolkit-cli-darwin-x64` | Mach-O |
| `agent-toolkit-cli-win32-x64` | PE |

No musl/Alpine npm tag (ADR-019). Launcher forwards argv/stdio/signals via `child_process.spawn` (no shell; Windows quoting is argv). Override: `AGENT_TOOLKIT_BIN`. Missing binary → exit 127.

## Pack / publish

```bash
# After GitHub Release assets exist:
export RELEASE_BIN_DIR=binaries
export RELEASE_VERSION="$(tr -d '[:space:]' < VERSION)"
./scripts/pack_npm.vsh
```

CI: `.github/workflows/publish-npm.yml` on tag `v*` (OIDC trusted publishing; npm CLI ≥ 11.5.1; `id-token: write`; no `NODE_AUTH_TOKEN`). Trust pin:

```bash
npm trust github agent-toolkit-cli --file publish-npm.yml --repository ulises-jeremias/agent-toolkit --allow-publish -y
```

Repeat `npm trust github` for each platform package after first publish.
