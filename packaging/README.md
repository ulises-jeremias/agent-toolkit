# Packaging Templates

This directory contains packaging templates and reference files for
distributions published to external package managers.

## Structure

```
packaging/
  homebrew/
    agent-toolkit.rb       ← Homebrew formula template
  aur/
    PKGBUILD               ← Arch Linux AUR PKGBUILD template
```

## Dedicated distribution repos

The actual distribution happens in separate repositories:

| Repo | Purpose | Install |
|------|---------|---------|
| [ulises-jeremias/homebrew-tap](https://github.com/ulises-jeremias/homebrew-tap) | Homebrew formula | `brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit` |
| [ulises-jeremias/aur-packages](https://github.com/ulises-jeremias/aur-packages) | AUR PKGBUILD mirror | `yay -S agent-toolkit` |

## Auto-update flow

When a new GitHub release is created:
1. `.github/workflows/notify-homebrew.yml` → dispatches to homebrew-tap
2. `.github/workflows/notify-aur.yml` → dispatches to aur-packages
3. Both repos update their formulas/PKGBUILDs automatically

The templates in this directory are the source reference; the dedicated repos
contain the actual live formulas.

## PyPI

Published to PyPI as `agent-toolkit-cli` via `.github/workflows/release.yml`
using GitHub Trusted Publishing (no stored API keys).

```bash
pip install agent-toolkit-cli
uvx --from agent-toolkit-cli agent-toolkit
```
