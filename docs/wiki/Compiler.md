# Compiler Guide

Canonical: [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), [`docs/v/README.md`](../v/README.md), [`docs/v/emitters.md`](../v/emitters.md).

The compiler lives in the **V** CLI (`./make.vsh build-cli` → `build/agent-toolkit`). Python adapters under `packages/pypi/` are launcher/parity tests, not the product path.

```bash
./make.vsh build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --target cursor --product agent-toolkit-core
./build/agent-toolkit diff
./build/agent-toolkit inventory
```

`agent-toolkit release` is **not** a product command (REMOVE / `not_implemented` in V). Cut a version with [`docs/RELEASING.md`](../RELEASING.md).
