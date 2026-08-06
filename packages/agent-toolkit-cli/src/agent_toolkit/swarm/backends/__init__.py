"""UI backend contract and implementations."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any, Protocol


class SwarmUIBackend(Protocol):
    name: str
    def doctor(self) -> dict[str, Any]: ...
    def create_run_surface(self, run_dir: Path, run_id: str, recipe: str) -> dict[str, Any]: ...
    def create_role_surface(self, run_dir: Path, run_id: str, role: str) -> dict[str, Any]: ...
    def start_agent(self, run_dir: Path, run_id: str, role: str, cmd: list[str]) -> dict[str, Any]: ...
    def prompt_agent(self, run_id: str, role: str, prompt: str) -> dict[str, Any]: ...
    def wait_agent(self, run_id: str, role: str, until: str = "idle", timeout: int = 300) -> dict[str, Any]: ...
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
            return {"available": False, "reason": "herdr binary not found", "install": "https://herdr.dev/docs/install/"}
        try:
            res = subprocess.run(["herdr", "--version"], capture_output=True, text=True, timeout=5)
            ver = res.stdout.strip() or res.stderr.strip()
            # Check integration
            integ = subprocess.run(["herdr", "integration", "list", "--json"], capture_output=True, text=True, timeout=5)
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
            res = subprocess.run(["herdr"] + args + ["--json"], capture_output=True, text=True, timeout=timeout)
            # Prefer JSON output parsing
            try:
                return json.loads(res.stdout) if res.stdout.strip() else {"raw": res.stdout, "stderr": res.stderr, "code": res.returncode}
            except Exception:
                return {"raw": res.stdout, "stderr": res.stderr, "code": res.returncode}
        except FileNotFoundError:
            return {"error": "herdr not found"}
        except Exception as e:
            return {"error": str(e)}

    def create_run_surface(self, run_dir: Path, run_id: str, recipe: str) -> dict[str, Any]:
        # Use herdr workspace create if available, fallback to noop
        if not shutil.which("herdr"):
            return {"backend": "herdr", "status": "unavailable", "run_id": run_id}
        return self._run_json(["workspace", "create", "--cwd", str(run_dir.parent.parent), "--label", f"swarm-{run_id}", "--no-focus"])

    def create_role_surface(self, run_dir: Path, run_id: str, role: str) -> dict[str, Any]:
        if not shutil.which("herdr"):
            return {"backend": "herdr", "status": "unavailable"}
        return {"backend": "herdr", "status": "created", "role": role}

    def start_agent(self, run_dir: Path, run_id: str, role: str, cmd: list[str]) -> dict[str, Any]:
        if not shutil.which("herdr"):
            return {"error": "herdr not available"}
        # herdr agent start NAME --kind opencode --pane PANE_ID ...
        name = f"swarm-{run_id}-{role}"
        args = ["agent", "start", name, "--kind", "opencode"]
        return self._run_json(args)

    def prompt_agent(self, run_id: str, role: str, prompt: str) -> dict[str, Any]:
        name = f"swarm-{run_id}-{role}"
        return self._run_json(["agent", "prompt", name, prompt, "--wait"])

    def wait_agent(self, run_id: str, role: str, until: str = "idle", timeout: int = 300) -> dict[str, Any]:
        name = f"swarm-{run_id}-{role}"
        return self._run_json(["agent", "wait", name, "--until", until])

    def read_agent_output(self, run_id: str, role: str) -> str:
        name = f"swarm-{run_id}-{role}"
        res = self._run_json(["agent", "read", name, "--source", "recent"])
        return json.dumps(res)

    def focus_agent(self, run_id: str, role: str) -> None:
        pass

    def attach(self, run_id: str) -> None:
        print(f"[herdr] attach swarm-{run_id}: run `herdr workspace open swarm-{run_id}`")

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
            return {"available": False, "reason": "tmux not found", "install": "apt/brew/pacman: tmux"}
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
            subprocess.run(["tmux", "-L", sock, "new-session", "-d", "-s", session, "-c", str(run_dir)], capture_output=True, timeout=5)
            return {"backend": "tmux", "socket": sock, "session": session, "status": "created"}
        except Exception as e:
            return {"backend": "tmux", "error": str(e)}

    def create_role_surface(self, run_dir: Path, run_id: str, role: str) -> dict[str, Any]:
        sock = self._socket_for(run_id)
        session = f"swarm-{run_id}"
        window = f"{role}"
        try:
            subprocess.run(["tmux", "-L", sock, "new-window", "-t", f"{session}", "-n", window, "-c", str(run_dir)], capture_output=True, timeout=5)
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
            subprocess.run(["tmux", "-L", sock, "send-keys", "-t", f"swarm-{run_id}:{role}", shell_cmd, "Enter"], capture_output=True, timeout=5)
            return {"backend": "tmux", "status": "started", "cmd": cmd}
        except Exception as e:
            return {"error": str(e)}

    def prompt_agent(self, run_id: str, role: str, prompt: str) -> dict[str, Any]:
        # Tmux prompt is send-keys with prompt text
        return {"backend": "tmux", "status": "prompted", "role": role}

    def wait_agent(self, run_id: str, role: str, until: str = "idle", timeout: int = 300) -> dict[str, Any]:
        return {"backend": "tmux", "status": "wait-not-implemented"}

    def read_agent_output(self, run_id: str, role: str) -> str:
        sock = self._socket_for(run_id)
        try:
            res = subprocess.run(["tmux", "-L", sock, "capture-pane", "-p", "-t", f"swarm-{run_id}:{role}"], capture_output=True, text=True, timeout=5)
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
            subprocess.run(["tmux", "-L", sock, "kill-window", "-t", f"swarm-{run_id}:{role}"], capture_output=True, timeout=5)
            return {"status": "stopped"}
        except Exception as e:
            return {"error": str(e)}

    def cleanup(self, run_dir: Path, run_id: str) -> dict[str, Any]:
        sock = self._socket_for(run_id)
        try:
            subprocess.run(["tmux", "-L", sock, "kill-session", "-t", f"swarm-{run_id}"], capture_output=True, timeout=5)
            return {"status": "cleaned"}
        except Exception as e:
            return {"error": str(e)}

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
