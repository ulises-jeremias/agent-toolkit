# Per-artifact smoke tests

**Issue:** [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531)  
**Matrix:** [release-matrix.md](release-matrix.md) ([#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529))

MUST-platform V binaries are **executed on the same runner architecture that built them**. Compile-only is not enough. No QEMU/emulation.

## Checks (each matrix job)

1. **Arch gate** — `uname -m` (normalized: `aarch64`→`arm64`, `amd64`→`x86_64`) must equal the job’s `expect_arch`. A mismatch fails; it cannot silently pass.
2. **`--version`** and **`--help`**
3. **`inventory`** and **`doctor --json`** with `AGENT_TOOLKIT_ROOT` set to the checkout (read-only; data is in-tree)

Implemented in `.github/workflows/experimental-v.yml` after `make`-equivalent V build. Failures fail the job (`fail-fast: false` so other platforms still report).

Tag `release.yml` PyInstaller assets are **not** switched here; promotion after smoke stays an explicit decision.
