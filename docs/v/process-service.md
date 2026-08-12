# V process execution service

**Issue:** [#500](https://github.com/ulises-jeremias/agent-toolkit/issues/500)

`ProcessService.run` spawns executables via `os.new_process` + argv (never a shell). Supports cwd, env, timeout, stdout/stderr capture, and cancel via kill on timeout.
