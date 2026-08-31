# V content sync / download client

**Issue:** [#557](https://github.com/ulises-jeremias/agent-toolkit/issues/557)

Downloads capability trees from GitHub Release tarballs into XDG data (`$XDG_DATA_HOME/agent-toolkit/data`). Uses `NetworkClient` (#558). Offline (`AGENT_TOOLKIT_OFFLINE` or `ensure_data(..., offline: true)`) never hits the network. Staging is validated before replace so a corrupt/partial download does not activate the cache.
