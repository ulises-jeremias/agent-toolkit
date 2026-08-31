# V HTTP/network download abstraction

**Issue:** [#558](https://github.com/ulises-jeremias/agent-toolkit/issues/558)

`NetworkClient` provides GET/download with User-Agent, timeouts, TLS validate, redirect policy, offline short-circuit (`AGENT_TOOLKIT_OFFLINE`), and SHA-256 verification hooks. All V core network calls should go through this module.
