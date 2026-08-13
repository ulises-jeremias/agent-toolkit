# npm adapter

**Issue:** [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536) · **ADR:** [#487](https://github.com/ulises-jeremias/agent-toolkit/issues/487)

Future adapter. Topology (optionalDependencies per platform vs single meta-package) is decided in #487. This repo does **not** vendor npm `package.json` here.

When implemented: launcher must forward stdio, signals, and Windows quoting; no forked CLI behavior. Binary sourced from GitHub Releases (ADR-018), not a second compile.
