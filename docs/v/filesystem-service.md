# V filesystem service

**Issue:** [#499](https://github.com/ulises-jeremias/agent-toolkit/issues/499)  
**Related:** ADR-015 resolution, env precedence `#559`

`FsService` in `agent_toolkit_core` centralizes:

- OS-aware `join` via `os.join_path` (Windows path semantics)
- XDG cache/data homes + toolkit cache/data dirs
- `ensure_dir`, `write_atomic` (temp + rename), `read_text`, `exists`

Install/receipts/workspace code should call this service instead of scattering raw `os` calls.
