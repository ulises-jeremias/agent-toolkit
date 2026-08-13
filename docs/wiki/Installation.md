# Installation

Canonical guide: [`docs/INSTALLATION.md`](../INSTALLATION.md). Quick start: [`docs/GETTING_STARTED.md`](../GETTING_STARTED.md). Uninstall: [`docs/UNINSTALL.md`](../UNINSTALL.md).

The product CLI is the **native V binary**. Pick one channel, then deploy profiles:

```bash
# Homebrew
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
# AUR — GitHub Release V binary (not the Python AUR package)
yay -S agent-toolkit-bin
# GitHub Release — agent-toolkit-<os>-<arch> + SHA256SUMS from /releases/latest
# PyPI launcher (execs bundled V)
uv tool install 'agent-toolkit-cli>=1.11.0'
# npm
npm i -g agent-toolkit-cli

agent-toolkit install
agent-toolkit doctor
```

`scripts/install.sh` is a deprecated fallback ([ADR-007](../adrs/ADR-007-install-sh-deprecation.md)).
