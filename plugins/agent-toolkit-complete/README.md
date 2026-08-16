<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-complete

**Full stable skill catalog** for consumers who want everything. Experimental — portable manifest included; marketplace pending.

[![Agent Plugins](https://img.shields.io/badge/Agent%20Plugins-1.0-7c3aed?style=flat&labelColor=1f2937)](https://agent-plugins.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
![skills](https://img.shields.io/badge/skills-80-7c3aed?style=flat&labelColor=1f2937)

[Monorepo](https://github.com/ulises-jeremias/agent-toolkit) ·
[Products](https://github.com/ulises-jeremias/agent-toolkit/blob/main/distributions/products.yaml) ·
[Installation](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md)

</div>

---

## What's included

The complete product ships the full skill catalog (`plugin.json` + `skills/` + `mcp.json`) from [`distributions/products.yaml`](../../distributions/products.yaml). Prefer the split marketplace plugins (`core`, `agents`, `forge`) unless you need the entire catalog.

## Install

CLI (recommended until marketplace listing lands):

```bash
npm i -g agent-toolkit-cli
# or: uv tool install agent-toolkit-cli
agent-toolkit install
```

Claude Code / Cursor marketplaces currently ship `agent-toolkit-core`, `agent-toolkit-agents`, and `agent-toolkit-forge`. This bundle is the experimental full catalog.
