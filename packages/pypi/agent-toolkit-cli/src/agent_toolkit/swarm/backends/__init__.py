"""UI backend contract and implementations."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any, Protocol


class SwarmUIBackend(Protocol):
    name: str

    def doctor(self) -> dict[str, Any]: ...
    def create_run_surface(self, run_dir: Path, run_id: str, recipe: str) -> dict[str, Any]: ...
    def create_role_surface(self, run_dir: Path, run_id: str, role: str) -> dict[str, Any]: ...
    def start_agent(
        self, run_dir: Path, run_id: str, role: str, cmd: list[str]
    ) -> dict[str, Any]: ...
    def prompt_agent(self, run_id: str, role: str, prompt: str) -> dict[str, Any]: ...
    def wait_agent(
        self, run_id: str, role: str, until: str = "idle", timeout: int = 300
    ) -> dict[str, Any]: ...
    def read_agent_output(self, run_id: str, role: str) -> str: ...
    def focus_agent(self, run_id: str, role: str) -> None: ...
    def attach(self, run_id: str) -> None: ...
    def stop_agent(self, run_id: str, role: str) -> dict[str, Any]: ...
    def cleanup(self, run_dir: Path, run_id: str) -> dict[str, Any]: ...


# --- Herdr backend ---


class HerdrBackend:
    name = "herdr"

    def doctor(self) -> dict[str, Any]:
        herdr = shutil.which("herdr")
        if not herdr:
            return {
                "available": False,
                "reason": "herdr binary not found",
                "install": "https://herdr.dev/docs/install/",
            }
        try:
            res = subprocess.run(["herdr", "--version"], capture_output=True, text=True, timeout=5)
            ver = res.stdout.strip() or res.stderr.strip()
            # Check integration
            integ = subprocess.run(
                ["herdr", "integration", "list", "--json"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            integrations = {}
            if integ.returncode == 0:
                try:
                    integrations = json.loads(integ.stdout)
                except Exception:
                    integrations = {"raw": integ.stdout[:500]}
            return {"available": True, "version": ver, "integrations": integrations}
        except Exception as e:
            return {"available": False, "reason": str(e)}

    def _run_json(self, args: list[str], timeout: int = 10) -> dict[str, Any]:
        try:
            # Try with --json first, fallback without if herdr rejects it (e.g., workspace create)
            for extra in (["--json"], []):
                res = subprocess.run(
                    ["herdr"] + args + extra, capture_output=True, text=True, timeout=timeout
                )
                # If herdr complains about unknown --json, try without
                if "unknown option: --json" in (res.stderr or "") or "unknown option: --json" in (
                    res.stdout or ""
                ):
                    continue
                try:
                    return (
                        json.loads(res.stdout)
                        if res.stdout.strip()
                        else {"raw": res.stdout, "stderr": res.stderr, "code": res.returncode}
                    )
                except Exception:
                    # If not JSON but success, return raw
                    if res.returncode == 0 and res.stdout.strip():
                        try:
                            return json.loads(res.stdout)
                        except Exception:
                            return {"raw": res.stdout, "stderr": res.stderr, "code": res.returncode}
                    return {"raw": res.stdout, "stderr": res.stderr, "code": res.returncode}
            return {"raw": "", "stderr": "unknown option --json handling failed", "code": 1}
        except FileNotFoundError:
            return {"error": "herdr not found"}
        except Exception as e:
            return {"error": str(e)}

    def _herdr_workspace_id(self, run_dir: Path, run_id: str) -> str | None:
        # Try to read stored workspace_id, else find by label
        try:
            store = run_dir / ".herdr_workspace_id"
            if store.is_file():
                wid = store.read_text(encoding="utf-8").strip()
                if wid:
                    return wid
        except Exception:
            pass
        # Find by label swarm-<run_id>
        try:
            res = subprocess.run(
                ["herdr", "workspace", "list"], capture_output=True, text=True, timeout=5
            )
            import json as _json

            data = _json.loads(res.stdout)
            for w in data.get("result", {}).get("workspaces", []):
                if w.get("label") == f"swarm-{run_id}":
                    return w.get("workspace_id")
        except Exception:
            pass
        return None

    def _herdr_pane_for_role(self, run_dir: Path, run_id: str, role: str) -> str | None:
        wid = self._herdr_workspace_id(run_dir, run_id)
        if not wid:
            return None
        try:
            res = subprocess.run(
                ["herdr", "tab", "list", "--workspace", wid],
                capture_output=True,
                text=True,
                timeout=5,
            )
            import json as _json

            data = _json.loads(res.stdout)
            for tab in data.get("result", {}).get("tabs", []):
                if tab.get("label") == role:
                    # Get pane for this tab
                    res2 = subprocess.run(
                        ["herdr", "pane", "list", "--workspace", wid],
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    data2 = _json.loads(res2.stdout)
                    for pane in data2.get("result", {}).get("panes", []):
                        if pane.get("tab_id") == tab.get("tab_id"):
                            return pane.get("pane_id")
                    # Fallback to root_pane if tab list gives it
                    return (
                        tab.get("root_pane", {}).get("pane_id")
                        if isinstance(tab.get("root_pane"), dict)
                        else None
                    )
        except Exception:
            pass
        return None

    def create_run_surface(self, run_dir: Path, run_id: str, recipe: str) -> dict[str, Any]:
        if not shutil.which("herdr"):
            return {"backend": "herdr", "status": "unavailable", "run_id": run_id}
        # Repo is .agent-toolkit/swarm/runs/<id> -> repo = run_dir.parent.parent.parent
        try:
            repo = run_dir.parent.parent.parent
            if not (repo / ".git").exists():
                repo = run_dir
        except Exception:
            repo = run_dir
        res = self._run_json(
            [
                "workspace",
                "create",
                "--cwd",
                str(repo),
                "--label",
                f"swarm-{run_id}",
                "--no-focus",
            ]
        )
        # Store workspace_id for later
        try:
            wid = res.get("result", {}).get("workspace", {}).get("workspace_id") or res.get(
                "result", {}
            ).get("workspace_id")
            if wid:
                (run_dir / ".herdr_workspace_id").write_text(wid, encoding="utf-8")
            else:
                # Try to find by label
                wid2 = self._herdr_workspace_id(run_dir, run_id)
                if wid2:
                    (run_dir / ".herdr_workspace_id").write_text(wid2, encoding="utf-8")
        except Exception:
            pass
        return res

    def create_role_surface(self, run_dir: Path, run_id: str, role: str) -> dict[str, Any]:
        if not shutil.which("herdr"):
            return {"backend": "herdr", "status": "unavailable"}
        wid = self._herdr_workspace_id(run_dir, run_id)
        if not wid:
            # Workspace not yet created, cannot create tab
            return {"backend": "herdr", "status": "no_workspace", "role": role}
        # Check if tab already exists
        try:
            res = subprocess.run(
                ["herdr", "tab", "list", "--workspace", wid],
                capture_output=True,
                text=True,
                timeout=5,
            )
            import json as _json

            data = _json.loads(res.stdout)
            for tab in data.get("result", {}).get("tabs", []):
                if tab.get("label") == role:
                    return {
                        "backend": "herdr",
                        "status": "exists",
                        "role": role,
                        "tab_id": tab.get("tab_id"),
                    }
        except Exception:
            pass
        # Create tab for role
        # Use worktree path if exists else run_dir
        try:
            # Try to get worktree path from state if available
            from .store import read_state

            state = read_state(run_dir) or {}
            wt_path = None
            for wt in state.get("worktrees", []):
                if wt.get("role") == role:
                    wt_path = wt.get("path")
                    break
            cwd = wt_path if wt_path and Path(wt_path).exists() else str(run_dir)
        except Exception:
            cwd = str(run_dir)
        res = self._run_json(
            ["tab", "create", "--workspace", wid, "--label", role, "--cwd", cwd, "--no-focus"]
        )
        return {"backend": "herdr", "status": "created", "role": role, "result": res}

    def start_agent(self, run_dir: Path, run_id: str, role: str, cmd: list[str]) -> dict[str, Any]:
        if not shutil.which("herdr"):
            return {"error": "herdr not available"}
        # For herdr, we run the bash command via pane run, not agent start (more universal, matches tmux)
        # Find pane for role
        pane_id = self._herdr_pane_for_role(run_dir, run_id, role)
        if not pane_id:
            # Fallback: try workspace root pane
            wid = self._herdr_workspace_id(run_dir, run_id)
            if wid:
                try:
                    res = subprocess.run(
                        ["herdr", "pane", "list", "--workspace", wid],
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    import json as _json

                    data = _json.loads(res.stdout)
                    panes = data.get("result", {}).get("panes", [])
                    if panes:
                        pane_id = panes[0].get("pane_id")
                except Exception:
                    pass
        if not pane_id:
            return {"error": f"no pane for role {role}"}
        # Build shell command string like tmux does
        import shlex as _shlex

        shell_cmd = " ".join(_shlex.quote(c) for c in cmd)
        # Use pane run to execute bash -lc '...'
        try:
            res = subprocess.run(
                ["herdr", "pane", "run", pane_id, shell_cmd],
                capture_output=True,
                text=True,
                timeout=10,
            )
            return {
                "backend": "herdr",
                "status": "started",
                "pane_id": pane_id,
                "stdout": res.stdout[:500],
                "stderr": res.stderr[:500],
                "code": res.returncode,
            }
        except Exception as e:
            return {"error": str(e)}

    def prompt_agent(self, run_id: str, role: str, prompt: str) -> dict[str, Any]:
        name = f"swarm-{run_id}-{role}"
        return self._run_json(["agent", "prompt", name, prompt, "--wait"])

    def wait_agent(
        self, run_id: str, role: str, until: str = "idle", timeout: int = 300
    ) -> dict[str, Any]:
        name = f"swarm-{run_id}-{role}"
        return self._run_json(["agent", "wait", name, "--until", until])

    def read_agent_output(self, run_id: str, role: str) -> str:
        name = f"swarm-{run_id}-{role}"
        res = self._run_json(["agent", "read", name, "--source", "recent"])
        return json.dumps(res)

    def focus_agent(self, run_id: str, role: str) -> None:
        pass

    def attach(self, run_id: str) -> None:
        # Find workspace_id by label and focus it (herdr has no 'open')
        wid = None
        try:
            import json as _json
            import subprocess as _sp

            res = _sp.run(["herdr", "workspace", "list"], capture_output=True, text=True, timeout=5)
            data = _json.loads(res.stdout)
            for w in data.get("result", {}).get("workspaces", []):
                if w.get("label") == f"swarm-{run_id}":
                    wid = w.get("workspace_id")
                    break
        except Exception:
            pass
        if wid:
            print(f"[herdr] focusing workspace swarm-{run_id} ({wid})")
            try:
                import subprocess as _sp2

                _sp2.run(["herdr", "workspace", "focus", wid], capture_output=False, timeout=5)
            except Exception as e:
                print(
                    f"[herdr] focus failed: {e} — run `herdr workspace list` and `herdr workspace focus {wid}`"
                )
        else:
            print(
                f"[herdr] attach swarm-{run_id}: workspace not found — run `herdr workspace list`"
            )

    def stop_agent(self, run_id: str, role: str) -> dict[str, Any]:
        name = f"swarm-{run_id}-{role}"
        return self._run_json(["agent", "stop", name])

    def cleanup(self, run_dir: Path, run_id: str) -> dict[str, Any]:
        return {"backend": "herdr", "status": "cleaned"}


# --- Tmux backend ---


class TmuxBackend:
    name = "tmux"

    def doctor(self) -> dict[str, Any]:
        tmux = shutil.which("tmux")
        if not tmux:
            return {
                "available": False,
                "reason": "tmux not found",
                "install": "apt/brew/pacman: tmux",
            }
        try:
            res = subprocess.run(["tmux", "-V"], capture_output=True, text=True, timeout=5)
            return {"available": True, "version": res.stdout.strip()}
        except Exception as e:
            return {"available": False, "reason": str(e)}

    def _socket_for(self, run_id: str) -> str:
        return f"agent-toolkit-swarm-{run_id}"

    def create_run_surface(self, run_dir: Path, run_id: str, recipe: str) -> dict[str, Any]:
        if not shutil.which("tmux"):
            return {"backend": "tmux", "status": "unavailable"}
        sock = self._socket_for(run_id)
        session = f"swarm-{run_id}"
        try:
            subprocess.run(
                ["tmux", "-L", sock, "new-session", "-d", "-s", session, "-c", str(run_dir)],
                capture_output=True,
                timeout=5,
            )
            return {"backend": "tmux", "socket": sock, "session": session, "status": "created"}
        except Exception as e:
            return {"backend": "tmux", "error": str(e)}

    def create_role_surface(self, run_dir: Path, run_id: str, role: str) -> dict[str, Any]:
        sock = self._socket_for(run_id)
        session = f"swarm-{run_id}"
        window = f"{role}"
        try:
            subprocess.run(
                [
                    "tmux",
                    "-L",
                    sock,
                    "new-window",
                    "-t",
                    f"{session}",
                    "-n",
                    window,
                    "-c",
                    str(run_dir),
                ],
                capture_output=True,
                timeout=5,
            )
            return {"backend": "tmux", "socket": sock, "session": session, "window": window}
        except Exception as e:
            return {"backend": "tmux", "error": str(e)}

    def start_agent(self, run_dir: Path, run_id: str, role: str, cmd: list[str]) -> dict[str, Any]:
        if not shutil.which("tmux"):
            return {"error": "tmux not available"}
        sock = self._socket_for(run_id)
        # Use array cmd safely via send-keys with shell quoting
        import shlex

        shell_cmd = " ".join(shlex.quote(c) for c in cmd)
        try:
            subprocess.run(
                [
                    "tmux",
                    "-L",
                    sock,
                    "send-keys",
                    "-t",
                    f"swarm-{run_id}:{role}",
                    shell_cmd,
                    "Enter",
                ],
                capture_output=True,
                timeout=5,
            )
            return {"backend": "tmux", "status": "started", "cmd": cmd}
        except Exception as e:
            return {"error": str(e)}

    def prompt_agent(self, run_id: str, role: str, prompt: str) -> dict[str, Any]:
        sock = self._socket_for(run_id)
        target = f"swarm-{run_id}:{role}"
        # Use buffer paste for large multiline prompts (more robust than send-keys -l)
        import tempfile
        import time as _time

        try:
            # Give agent TUI a moment to initialize
            _time.sleep(1.5)
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".txt", delete=False, encoding="utf-8"
            ) as tf:
                tf.write(prompt)
                tf_path = tf.name
            try:
                subprocess.run(
                    ["tmux", "-L", sock, "load-buffer", "-b", f"swarm-prompt-{role}", tf_path],
                    capture_output=True,
                    timeout=5,
                )
                subprocess.run(
                    [
                        "tmux",
                        "-L",
                        sock,
                        "paste-buffer",
                        "-b",
                        f"swarm-prompt-{role}",
                        "-t",
                        target,
                    ],
                    capture_output=True,
                    timeout=5,
                )
                # Small delay then Enter to submit
                _time.sleep(0.3)
                subprocess.run(
                    ["tmux", "-L", sock, "send-keys", "-t", target, "Enter"],
                    capture_output=True,
                    timeout=5,
                )
                return {"backend": "tmux", "status": "prompted", "role": role, "bytes": len(prompt)}
            finally:
                try:
                    import os as _os

                    _os.unlink(tf_path)
                except Exception:
                    pass
                try:
                    subprocess.run(
                        ["tmux", "-L", sock, "delete-buffer", "-b", f"swarm-prompt-{role}"],
                        capture_output=True,
                        timeout=5,
                    )
                except Exception:
                    pass
        except Exception as e:
            return {"error": str(e)}

    def wait_agent(
        self, run_id: str, role: str, until: str = "idle", timeout: int = 300
    ) -> dict[str, Any]:
        return {"backend": "tmux", "status": "wait-not-implemented"}

    def read_agent_output(self, run_id: str, role: str) -> str:
        sock = self._socket_for(run_id)
        try:
            res = subprocess.run(
                ["tmux", "-L", sock, "capture-pane", "-p", "-t", f"swarm-{run_id}:{role}"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            return res.stdout
        except Exception as e:
            return f"error: {e}"

    def focus_agent(self, run_id: str, role: str) -> None:
        pass

    def attach(self, run_id: str) -> None:
        sock = self._socket_for(run_id)
        print(f"[tmux] attach: tmux -L {sock} attach -t swarm-{run_id}")

    def stop_agent(self, run_id: str, role: str) -> dict[str, Any]:
        sock = self._socket_for(run_id)
        try:
            subprocess.run(
                ["tmux", "-L", sock, "kill-window", "-t", f"swarm-{run_id}:{role}"],
                capture_output=True,
                timeout=5,
            )
            return {"status": "stopped"}
        except Exception as e:
            return {"error": str(e)}

    def cleanup(self, run_dir: Path, run_id: str) -> dict[str, Any]:
        sock = self._socket_for(run_id)
        session = f"swarm-{run_id}"
        actions: list[str] = []
        try:
            subprocess.run(
                ["tmux", "-L", sock, "kill-session", "-t", session],
                capture_output=True,
                timeout=5,
            )
            actions.append("kill-session")
        except Exception as e:
            return {"error": str(e)}
        # kill-server releases the per-run tmux server. If the server already
        # exited (e.g. last session closed, tmux crashed, test timeout), this is
        # a no-op but ensures no server process lingers.
        try:
            subprocess.run(
                ["tmux", "-L", sock, "kill-server"],
                capture_output=True,
                timeout=5,
            )
            actions.append("kill-server")
        except Exception:
            pass
        # tmux leaves the socket file behind when the server dies without a
        # clean shutdown (common under pytest timeouts). Remove the orphan so
        # /tmp/tmux-<uid>/ does not accumulate socket files across runs.
        try:
            for base in ("/tmp", os.environ.get("TMPDIR", "/tmp")):
                cand = Path(base) / f"tmux-{os.getuid()}" / sock
                if cand.is_socket():
                    try:
                        cand.unlink()
                        actions.append(f"rm-socket:{cand}")
                    except FileNotFoundError:
                        pass
        except Exception:
            pass
        return {"backend": "tmux", "status": "cleaned", "actions": actions}


def get_backend(name: str):
    if name == "herdr":
        return HerdrBackend()
    if name == "tmux":
        return TmuxBackend()
    if name == "auto":
        # Prefer herdr if available, else tmux
        hb = HerdrBackend()
        if hb.doctor().get("available"):
            return hb
        tb = TmuxBackend()
        if tb.doctor().get("available"):
            return tb
        return hb  # fallback for error reporting
    return HerdrBackend()
