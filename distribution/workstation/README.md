# Agentic Workstation adapter

**Epic:** [#469](https://github.com/ulises-jeremias/agent-toolkit/issues/469)  
**Consumer issue:** [agentic-workstation#206](https://github.com/ulises-jeremias/agentic-workstation/issues/206)  
**Consumer docs:** [agentic-workstation/docs/AGENT_TOOLKIT.md](https://github.com/ulises-jeremias/agentic-workstation/blob/main/docs/AGENT_TOOLKIT.md)

agentic-workstation is **L1** (machine provisioning). This repo is **L1.5** (capability distribution). Workstation MUST treat Agent Toolkit as a **CLI**, never as a Python library.

## MUST NOT

- `import agent_toolkit` (or any `agent_toolkit.*` module) from workstation code, chezmoi templates, or `dots-*` wrappers.
- Vendor skills/agents/loops into workstation (`home/dot_local/share/.../skills`). Catalog comes from `agent-toolkit install`.
- Assume PyInstaller, `python -m agent_toolkit`, or `agent-toolkit-py` is the product.

## Install channel preference

Bootstrap **prefers a platform-native adapter**, then falls back. Every path MUST end with the same CLI contract (`agent-toolkit install`, `doctor`, `inventory`).

| Order | Platform | Channel | Gate |
|------:|----------|---------|------|
| 1 | macOS | Homebrew `ulises-jeremias/homebrew-tap` `agent-toolkit` | Formula merged **and** a GitHub Release has V sha256 (homebrew-tap#5) |
| 1 | Arch Linux | AUR `agent-toolkit-bin` | PKGBUILD merged; Release has `agent-toolkit-linux-*` |
| 2 | Linux/macOS/Windows | GitHub Release floating binary + `SHA256SUMS` | Tag with ADR-018 assets |
| 3 | Any (chicken/egg) | `uv tool install --force agent-toolkit-cli` then `agent-toolkit install` | PyPI wheel that **execs the bundled V binary** (ADR-021), not Python as the product |
| 3 | Node environments | `npm i -g agent-toolkit-cli` | OIDC `publish-npm.yml` + platform optionalDependencies |

Until Homebrew/AUR consume a **real** V sha256, `uv tool install` remains the documented workstation default. That is still **canonical binary behavior** once ADR-021 wheels ship; it is not a Python-impl dependency.

## chezmoi / dots-* contract

Workstation owns these files (do not copy them here):

| Script / command | Allowed after cutover |
|------------------|------------------------|
| `run_once_after_50-install-agent-toolkit.sh.tmpl` | Install via the preference table, then `agent-toolkit install` |
| `run_onchange_45-install-ai-agents.sh.tmpl` | Same two steps + `dots-skills sync` |
| `dots-skills install-toolkit` | Channel install + `agent-toolkit install` |
| `dots-skills sync` | `agent-toolkit install` |
| `dots-skills list` | `agent-toolkit skills list` |
| `dots-skills check` / `dots-doctor` | `agent-toolkit doctor` (+ workstation-only tmux/herdr checks) |
| `dots-loop *` | `agent-toolkit loop *` |

LLM policy stays in workstation. Toolkit remains vendor-neutral.

## Rollback

Pin the previous `agent-toolkit-cli` version in the chezmoi script (`uv tool install agent-toolkit-cli==<ver>`) or pin the Homebrew/AUR package. Do not roll back by importing Python modules.

## Testing

Fresh VM/container: install via the highest available channel, then:

```bash
agent-toolkit --version
agent-toolkit doctor
agent-toolkit install
```

Implementation of the preference table lives in **agentic-workstation#206**, not this repo.
