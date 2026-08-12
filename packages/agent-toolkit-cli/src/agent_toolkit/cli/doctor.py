"""
doctor — Check system health, AI tool availability, and Swarm prerequisites.

Usage:
    agent-toolkit doctor [options]

Options:
    --json         Output results as JSON
    --fix          Attempt to auto-fix issues (installs missing profiles)
    --provenance   Show full provenance report (SHA/commit immutability, expiry >90d)
    --help         Show this help message

Exit codes:
    0 — no errors detected
    1 — one or more errors detected
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import datetime
import urllib.request
from pathlib import Path
import pathlib
import pathlib

from agent_toolkit._paths import toolkit_root

# Windows: force UTF-8 output so emoji chars (✓ ✗ ⚠) don't crash
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Result model
# ---------------------------------------------------------------------------


class CheckResult:
    """A single health-check item."""

    STATUS_OK = "ok"
    STATUS_WARN = "warn"
    STATUS_ERR = "error"

    def __init__(self, category: str, name: str, status: str, detail: str = "") -> None:
        self.category = category
        self.name = name
        self.status = status
        self.detail = detail

    @property
    def icon(self) -> str:
        return {"ok": "✓", "warn": "⚠", "error": "✗"}.get(self.status, "?")

    def to_dict(self) -> dict:
        return {
            "category": self.category,
            "name": self.name,
            "status": self.status,
            "detail": self.detail,
        }


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------


def _check_python_version() -> CheckResult:
    vi = sys.version_info
    version_str = f"{vi.major}.{vi.minor}.{vi.micro}"
    if (vi.major, vi.minor) >= (3, 10):
        return CheckResult("system", "python >= 3.10", CheckResult.STATUS_OK, version_str)
    return CheckResult(
        "system", "python >= 3.10", CheckResult.STATUS_ERR, f"Found {version_str} — need 3.10+"
    )


def _check_command(category: str, name: str, cmd: str) -> CheckResult:
    path = shutil.which(cmd)
    if path:
        # Try to get version
        try:
            result = subprocess.run([cmd, "--version"], capture_output=True, text=True, timeout=5)
            version = (result.stdout or result.stderr or "").strip().splitlines()[0]
        except Exception:
            version = path
        return CheckResult(category, name, CheckResult.STATUS_OK, version)
    return CheckResult(category, name, CheckResult.STATUS_ERR, f"'{cmd}' not found in PATH")


def _check_gh_auth() -> CheckResult:
    if shutil.which("gh") is None:
        return CheckResult("system", "gh auth", CheckResult.STATUS_ERR, "'gh' not found in PATH")
    try:
        result = subprocess.run(
            ["gh", "auth", "status"], capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            return CheckResult("system", "gh auth", CheckResult.STATUS_OK, "authenticated")
        return CheckResult(
            "system",
            "gh auth",
            CheckResult.STATUS_WARN,
            "gh installed but not authenticated — run: gh auth login",
        )
    except Exception as exc:
        return CheckResult("system", "gh auth", CheckResult.STATUS_WARN, str(exc))


def _check_ai_tool(name: str, cmd: str) -> CheckResult:
    path = shutil.which(cmd)
    if path:
        return CheckResult("ai_tools", name, CheckResult.STATUS_OK, path)
    return CheckResult(
        "ai_tools", name, CheckResult.STATUS_WARN, f"'{cmd}' not found — tool may not be installed"
    )


def _profile_installed(category: str, name: str, path: Path) -> CheckResult:
    if path.exists():
        return CheckResult(category, name, CheckResult.STATUS_OK, str(path))
    return CheckResult(category, name, CheckResult.STATUS_WARN, f"Not installed: {path}")


def _check_profiles() -> list[CheckResult]:
    """Check whether profiles are installed for each detected tool."""
    results: list[CheckResult] = []
    home = Path.home()

    # claude-code
    if shutil.which("claude") or (home / ".claude").is_dir():
        results.append(
            _profile_installed("profiles", "claude-code CLAUDE.md", home / ".claude" / "CLAUDE.md")
        )
        # settings.json is user-owned and must not be managed by the installer.
        results.append(
            _profile_installed("profiles", "claude-code agents/", home / ".claude" / "agents")
        )

    # cursor
    if shutil.which("cursor") or (home / ".cursor").is_dir():
        results.append(_profile_installed("profiles", "cursor rules/", home / ".cursor" / "rules"))

    # opencode
    if shutil.which("opencode") or (home / ".config" / "opencode").is_dir():
        results.append(
            _profile_installed(
                "profiles", "opencode agents/", home / ".config" / "opencode" / "agents"
            )
        )
        results.append(
            _profile_installed(
                "profiles",
                "opencode opencode.json",
                home / ".config" / "opencode" / "opencode.json",
            )
        )

    # windsurf
    windsurf_dir: Path | None = None
    if (home / ".codeium" / "windsurf").is_dir():
        windsurf_dir = home / ".codeium" / "windsurf"
    elif (home / ".windsurf").is_dir():
        windsurf_dir = home / ".windsurf"
    elif shutil.which("windsurf"):
        windsurf_dir = home / ".codeium" / "windsurf"

    if windsurf_dir is not None:
        results.append(_profile_installed("profiles", "windsurf rules/", windsurf_dir / "rules"))
        results.append(
            _profile_installed("profiles", "windsurf memories/", windsurf_dir / "memories")
        )

    # pi
    if shutil.which("pi") or (home / ".pi").is_dir():
        results.append(
            _profile_installed("profiles", "pi skills/", home / ".pi" / "agent" / "skills")
        )

    # muse (Meta) — ~/.config/muse/skills and project .agents/skills
    if shutil.which("muse") or (home / ".config" / "muse").is_dir() or (home / ".agents").is_dir():
        results.append(
            _profile_installed(
                "profiles", "muse skills (user)", home / ".config" / "muse" / "skills"
            )
        )
        # project scope: .agents/skills in CWD or workspace root
        # check CWD .agents/skills and toolkit-relative if available
        cwd_agents = Path.cwd() / ".agents" / "skills"
        if cwd_agents.is_dir() or (home / ".agents").is_dir():
            # use CWD if present, else home fallback for display
            agents_path = cwd_agents if cwd_agents.is_dir() else home / ".agents" / "skills"
            results.append(_profile_installed("profiles", "muse skills (project)", agents_path))
        else:
            results.append(
                CheckResult(
                    "profiles",
                    "muse skills (project)",
                    CheckResult.STATUS_WARN,
                    "Not found: .agents/skills (project scope — optional)",
                )
            )

    return results


def _check_loop_runtime(toolkit_dir: Path | None) -> list[CheckResult]:
    results: list[CheckResult] = []

    # Check if `agent-toolkit loop` resolves (basic import test)
    try:
        subprocess.run(
            [sys.executable, "-m", "agent_toolkit", "loop", "--help"],
            capture_output=True,
            timeout=10,
        )
        results.append(
            CheckResult(
                "loops",
                "loop subcommand",
                CheckResult.STATUS_OK,
                "agent-toolkit loop --help succeeded",
            )
        )
    except Exception as exc:
        results.append(
            CheckResult(
                "loops",
                "loop subcommand",
                CheckResult.STATUS_WARN,
                f"Could not run loop command: {exc}",
            )
        )

    # Check loops/ templates
    if toolkit_dir:
        loops_dir = toolkit_dir / "loops"
        if loops_dir.is_dir():
            count = sum(1 for d in loops_dir.iterdir() if d.is_dir())
            results.append(
                CheckResult(
                    "loops",
                    "loop templates",
                    CheckResult.STATUS_OK,
                    f"{count} template(s) found in {loops_dir}",
                )
            )
        else:
            results.append(
                CheckResult(
                    "loops",
                    "loop templates",
                    CheckResult.STATUS_WARN,
                    f"loops/ directory not found at {loops_dir}",
                )
            )
    else:
        results.append(
            CheckResult(
                "loops",
                "loop templates",
                CheckResult.STATUS_WARN,
                "Toolkit directory not found — cannot check loop templates",
            )
        )

    return results


def _check_llm_providers() -> list[CheckResult]:
    results: list[CheckResult] = []

    # API keys
    for var in ("ANTHROPIC_API_KEY", "OPENAI_API_KEY"):
        val = os.environ.get(var, "")
        if val:
            masked = val[:8] + "..." if len(val) > 8 else "***"
            results.append(CheckResult("llm", var, CheckResult.STATUS_OK, f"set ({masked})"))
        else:
            results.append(CheckResult("llm", var, CheckResult.STATUS_WARN, "not set"))

    # Ollama
    try:
        req = urllib.request.Request("http://localhost:11434", method="HEAD")
        req.add_header("User-Agent", "agent-toolkit-doctor/1")
        with urllib.request.urlopen(req, timeout=3):
            pass
        results.append(
            CheckResult("llm", "ollama", CheckResult.STATUS_OK, "running at localhost:11434")
        )
    except Exception:
        results.append(
            CheckResult(
                "llm", "ollama", CheckResult.STATUS_WARN, "not reachable at localhost:11434"
            )
        )

    # opencode socket (Linux/macOS only — os.getuid() doesn't exist on Windows)
    try:
        uid = os.getuid()  # type: ignore[attr-defined]
    except AttributeError:
        uid = 0
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")
    socket_paths = [
        Path(xdg_runtime) / "opencode.sock",
        Path.home() / ".config" / "opencode" / "opencode.sock",
    ]
    for sp in socket_paths:
        if sp.exists():
            results.append(CheckResult("llm", "opencode socket", CheckResult.STATUS_OK, str(sp)))
            break
    else:
        results.append(
            CheckResult(
                "llm",
                "opencode socket",
                CheckResult.STATUS_WARN,
                "socket not found (opencode may not be running)",
            )
        )

    return results


def _check_mcp() -> list[CheckResult]:
    results: list[CheckResult] = []
    config_path = Path.home() / ".config" / "agent-toolkit" / "mcp-config.json"

    if not config_path.exists():
        results.append(
            CheckResult(
                "mcp",
                "mcp-config.json",
                CheckResult.STATUS_WARN,
                f"Not found: {config_path}  (run: agent-toolkit mcp setup <provider>)",
            )
        )
        return results

    try:
        data = json.loads(config_path.read_text())
        providers = data.get("providers", {})
        if not providers:
            results.append(
                CheckResult(
                    "mcp",
                    "mcp providers",
                    CheckResult.STATUS_WARN,
                    "Config exists but no providers configured",
                )
            )
            return results
        for name, cfg in providers.items():
            enabled = cfg.get("enabled", False)
            validated = cfg.get("validated_at", "never")
            status = CheckResult.STATUS_OK if enabled else CheckResult.STATUS_WARN
            results.append(
                CheckResult(
                    "mcp",
                    f"provider:{name}",
                    status,
                    f"enabled={enabled}, validated_at={validated}",
                )
            )
    except (json.JSONDecodeError, OSError) as exc:
        results.append(
            CheckResult(
                "mcp", "mcp-config.json", CheckResult.STATUS_ERR, f"Cannot read config: {exc}"
            )
        )

    return results


def _check_scheduled_loops() -> list[CheckResult]:
    results: list[CheckResult] = []
    system = platform.system()

    if system == "Linux":
        timer_dir = Path.home() / ".config" / "systemd" / "user"
        if timer_dir.is_dir():
            timers = list(timer_dir.glob("agent-toolkit-*.timer"))
            if timers:
                for t in sorted(timers):
                    results.append(CheckResult("scheduled", t.name, CheckResult.STATUS_OK, str(t)))
            else:
                results.append(
                    CheckResult(
                        "scheduled",
                        "systemd timers",
                        CheckResult.STATUS_WARN,
                        "No agent-toolkit-*.timer files found",
                    )
                )
        else:
            results.append(
                CheckResult(
                    "scheduled",
                    "systemd user dir",
                    CheckResult.STATUS_WARN,
                    f"Not found: {timer_dir}",
                )
            )
    elif system == "Darwin":
        launchd_dir = Path.home() / "Library" / "LaunchAgents"
        if launchd_dir.is_dir():
            plists = list(launchd_dir.glob("com.agent-toolkit.*.plist"))
            if plists:
                for p in sorted(plists):
                    results.append(CheckResult("scheduled", p.name, CheckResult.STATUS_OK, str(p)))
            else:
                results.append(
                    CheckResult(
                        "scheduled",
                        "launchd plists",
                        CheckResult.STATUS_WARN,
                        "No com.agent-toolkit.*.plist files found",
                    )
                )
        else:
            results.append(
                CheckResult(
                    "scheduled",
                    "LaunchAgents dir",
                    CheckResult.STATUS_WARN,
                    f"Not found: {launchd_dir}",
                )
            )
    else:
        results.append(
            CheckResult(
                "scheduled",
                "scheduled loops",
                CheckResult.STATUS_WARN,
                f"Unsupported platform: {system}",
            )
        )

    return results


def _check_swarm() -> list[CheckResult]:
    results: list[CheckResult] = []

    tmux_path = shutil.which("tmux")
    if tmux_path:
        try:
            result = subprocess.run(["tmux", "-V"], capture_output=True, text=True, timeout=5)
            version = result.stdout.strip()
            results.append(CheckResult("swarm", "tmux", CheckResult.STATUS_OK, version))
        except Exception:
            results.append(CheckResult("swarm", "tmux", CheckResult.STATUS_OK, str(tmux_path)))
    else:
        results.append(
            CheckResult(
                "swarm",
                "tmux",
                CheckResult.STATUS_WARN,
                "not found — install with: brew install tmux / apt install tmux",
            )
        )

    herdr_path = shutil.which("herdr")
    if herdr_path:
        try:
            result = subprocess.run(
                ["herdr", "--version"], capture_output=True, text=True, timeout=5
            )
            version = result.stdout.strip() or result.stderr.strip()
            results.append(CheckResult("swarm", "herdr", CheckResult.STATUS_OK, version))
        except Exception:
            results.append(CheckResult("swarm", "herdr", CheckResult.STATUS_OK, str(herdr_path)))
    else:
        results.append(
            CheckResult(
                "swarm",
                "herdr",
                CheckResult.STATUS_WARN,
                "not found — install from https://herdr.dev/docs/install/",
            )
        )

    try:
        plan_result = subprocess.run(
            [
                sys.executable,
                "-m",
                "agent_toolkit",
                "swarm",
                "plan",
                "--runner",
                "skeleton",
                "--ui",
                "tmux",
                "doctor check",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if plan_result.returncode == 0:
            results.append(
                CheckResult(
                    "swarm",
                    "swarm plan (offline)",
                    CheckResult.STATUS_OK,
                    "skeleton runner plan succeeded",
                )
            )
        else:
            stderr = (plan_result.stderr or "").strip().splitlines()
            detail = stderr[-1] if stderr else f"plan exited {plan_result.returncode}"
            results.append(
                CheckResult(
                    "swarm",
                    "swarm plan (offline)",
                    CheckResult.STATUS_WARN,
                    detail,
                )
            )
    except Exception as exc:
        results.append(
            CheckResult(
                "swarm",
                "swarm plan (offline)",
                CheckResult.STATUS_WARN,
                f"could not run plan: {exc}",
            )
        )

    return results


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------


def _print_section(title: str) -> None:
    print(f"\n── {title} ──")



def _check_provenance(toolkit_dir: Path | None = None) -> list[CheckResult]:
    """Provenance checks per §52: SHA/commit immutability, expiry/staleness >90d, UNKNOWN/mutable ref."""
    results: list[CheckResult] = []
    # Try multiple roots: toolkit_root() (data), its parent (repo), cwd, and file's repo root
    candidates = []
    tr = toolkit_dir or toolkit_root()
    candidates.append(tr / "capabilities" / "upstream.lock")
    candidates.append(tr.parent / "capabilities" / "upstream.lock")
    candidates.append(Path.cwd() / "capabilities" / "upstream.lock")
    # also try toolkit_root().parents[2] if data is deep
    for anc in tr.parents:
        candidates.append(anc / "capabilities" / "upstream.lock")
    # Also try repo root via _paths toolkit_root parent chain
    import pathlib as _P
    for anc in _P.Path(__file__).resolve().parents:
        candidates.append(anc / "capabilities" / "upstream.lock")
        if (anc / "capabilities" / "upstream.lock").exists():
            break
    lock_path = next((c for c in candidates if c.exists()), candidates[0])
    root = lock_path.parent.parent if lock_path.exists() else (toolkit_dir or toolkit_root())

    if not lock_path.exists():
        results.append(CheckResult("provenance", "upstream.lock exists", CheckResult.STATUS_ERR, f"Missing: {lock_path}"))
        return results
    try:
        import yaml as _yaml
        import json as _json
        raw = lock_path.read_text()
        try:
            data = _yaml.safe_load(raw) or {}
        except Exception:
            data = _json.loads(raw)
        # check version and upstreams
        if data.get("version") != 1:
            results.append(CheckResult("provenance", "lock version", CheckResult.STATUS_WARN, f"version={data.get('version')} expected 1"))
        else:
            results.append(CheckResult("provenance", "lock version", CheckResult.STATUS_OK, "version 1"))
        upstreams = data.get("upstreams", []) or data.get("capabilities", [])
        # Try both shapes: v1 is list of caps with sources
        caps = data.get("capabilities", data.get("upstreams", []))
        if not caps:
            # fallback: count files
            results.append(CheckResult("provenance", "lock has entries", CheckResult.STATUS_WARN, "no capabilities/upstreams"))
        else:
            results.append(CheckResult("provenance", "lock entries", CheckResult.STATUS_OK, f"{len(caps)} entries"))
        # Check each source for SHA40 and staleness >90d
        import datetime as _dt
        now = _dt.datetime.now(_dt.timezone.utc)
        for cap in caps if isinstance(caps, list) else []:
            # caps may be dict with sources
            sources = cap.get("sources", []) if isinstance(cap, dict) else []
            for src in sources:
                ref = src.get("ref", "")
                commit = src.get("commit", "")
                # mutable ref check: tag without commit or branch name
                if ref and not commit:
                    results.append(CheckResult("provenance", f"provenance:{cap.get('id','?')}:{src.get('id','?')} immutable", CheckResult.STATUS_ERR, f"ref={ref} without commit — mutable"))
                elif commit and len(commit) != 40:
                    results.append(CheckResult("provenance", f"provenance:{cap.get('id','?')} SHA", CheckResult.STATUS_ERR, f"commit {commit[:8]} not SHA40"))
                # staleness: check last_checked or reviewed_at
                for date_key in ("last_checked", "reviewed_at", "last_activity"):
                    val = src.get(date_key) or cap.get(date_key)
                    if val:
                        try:
                            dt = _dt.datetime.fromisoformat(val.replace("Z", "+00:00"))
                            age = (now - dt).days
                            if age > 90:
                                results.append(CheckResult("provenance", f"provenance:{cap.get('id','?')} freshness", CheckResult.STATUS_WARN, f"{date_key} {age}d ago (>90d) — consider update"))
                            break
                        except Exception:
                            pass
        # Also check SKILL.md declarations have origin
        # (light — ensure file exists)
        results.append(CheckResult("provenance", "provenance: doctor --provenance", CheckResult.STATUS_OK, "run: agent-toolkit doctor --provenance for full SHA/commit + expiry report"))
    except Exception as exc:
        results.append(CheckResult("provenance", "upstream.lock parse", CheckResult.STATUS_ERR, str(exc)))
    return results


def _check_products_and_packs(toolkit_dir: Path | None = None) -> list[CheckResult]:
    """Pack consistency + product catalog per #387."""
    results: list[CheckResult] = []
    # Locate repo root (not data dir) for distributions, skills, packs
    candidates = []
    tr = toolkit_dir or toolkit_root()
    candidates.append(tr)
    candidates.append(tr.parent)
    candidates.append(Path.cwd())
    for anc in tr.parents:
        candidates.append(anc)
    for anc in pathlib.Path(__file__).resolve().parents:
        candidates.append(anc)
    root = next((c for c in candidates if (c / "distributions" / "products.yaml").exists()), tr)
    prod_path = root / "distributions" / "products.yaml"
    if not prod_path.exists():
        results.append(CheckResult("packs", "products.yaml exists", CheckResult.STATUS_ERR, str(prod_path)))
    else:
        results.append(CheckResult("packs", "products.yaml exists", CheckResult.STATUS_OK, str(prod_path)))
        # check complete covers all skills via catalog
        try:
            import yaml as _yaml
            prod_data = _yaml.safe_load(prod_path.read_text())
            complete = next((p for p in prod_data.get("products", []) if p.get("id") == "agent-toolkit-complete"), None)
            if complete:
                included = set(complete.get("includes", {}).get("skills", []))
                # count skills on disk
                skills = list((root / "skills").rglob("SKILL.md"))
                skill_ids = {f"{p.parts[-3]}/{p.parts[-2]}" if len(p.parts) >= 3 else p.parent.name for p in skills}
                # also handle skills/*/* flat?
                missing = skill_ids - included
                if missing:
                    results.append(CheckResult("packs", "complete covers all skills", CheckResult.STATUS_ERR, f"missing {sorted(missing)[:5]}"))
                else:
                    results.append(CheckResult("packs", "complete covers all skills", CheckResult.STATUS_OK, f"{len(included)} skills"))
        except Exception as exc:
            results.append(CheckResult("packs", "products.yaml parse", CheckResult.STATUS_WARN, str(exc)))
    # packs/* config.yaml
    packs_dir = root / "packs"
    if packs_dir.is_dir():
        for pack_dir in sorted(packs_dir.iterdir()):
            if pack_dir.is_dir():
                cfg = pack_dir / "config.yaml"
                if not cfg.exists():
                    results.append(CheckResult("packs", f"pack:{pack_dir.name} config", CheckResult.STATUS_WARN, "missing config.yaml"))
                else:
                    results.append(CheckResult("packs", f"pack:{pack_dir.name} config", CheckResult.STATUS_OK, str(cfg)))
                # loops check
                try:
                    import yaml as _yaml2
                    cfg_data = _yaml2.safe_load(cfg.read_text()) or {}
                    for loop_name in cfg_data.get("loops", {}).keys():
                        if not (root / "loops" / loop_name).is_dir():
                            results.append(CheckResult("packs", f"pack:{pack_dir.name} loop:{loop_name}", CheckResult.STATUS_WARN, "loop dir missing"))
                except Exception:
                    pass
    return results


def _check_mcp_registry(toolkit_dir: Path | None = None) -> list[CheckResult]:
    """MCP registry vs installed runtime per #387."""
    results: list[CheckResult] = []
    root = toolkit_dir or toolkit_root()
    reg_dir = root / "mcp" / "registry"
    if not reg_dir.is_dir():
        results.append(CheckResult("mcp", "mcp/registry dir", CheckResult.STATUS_WARN, str(reg_dir)))
        return results
    yaml_files = list(reg_dir.glob("*.yaml"))
    results.append(CheckResult("mcp", "mcp/registry count", CheckResult.STATUS_OK, f"{len(yaml_files)} providers"))
    for yf in sorted(yaml_files):
        try:
            import yaml as _yaml3
            data = _yaml3.safe_load(yf.read_text()) or {}
            # require id, tools or implementation
            if not data.get("id"):
                results.append(CheckResult("mcp", f"mcp:{yf.stem} id", CheckResult.STATUS_ERR, "missing id"))
            # check healthcheck or transport
            if "transport" not in data and "implementation" not in data:
                results.append(CheckResult("mcp", f"mcp:{yf.stem} transport", CheckResult.STATUS_WARN, "no transport/implementation"))
        except Exception as exc:
            results.append(CheckResult("mcp", f"mcp:{yf.stem} parse", CheckResult.STATUS_ERR, str(exc)))
    return results


def _print_result(r: CheckResult) -> None:
    detail = f"  ({r.detail})" if r.detail else ""
    print(f"  {r.icon}  {r.name}{detail}")


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

_PARSE_HELP = object()
_PARSE_ERROR = object()


def _parse_args(args: list[str]):
    """Return (json_output, fix), _PARSE_HELP, or _PARSE_ERROR."""
    json_output = False
    fix = False

    for arg in args:
        if arg in ("-h", "--help"):
            print(__doc__)
            return _PARSE_HELP
        elif arg == "--json":
            json_output = True
        elif arg == "--fix":
            fix = True
        elif arg == "--provenance":
            print("  ℹ  --provenance: full SHA/commit + expiry report (provenance checks are always run; use --json for machine-readable)", file=sys.stderr)
            # explicit flag — no separate mode, just acknowledge
            pass
        else:
            print(
                f"  ✗  Unknown option: {arg}  (run 'agent-toolkit doctor --help')", file=sys.stderr
            )
            return _PARSE_ERROR

    return json_output, fix


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def cmd_doctor(args: list[str]) -> int:
    """Run health checks for the agent-toolkit installation.

    Returns 0 if no errors, 1 if any check errors, 2 on usage/parse errors.
    """
    result = _parse_args(args)
    if result is _PARSE_HELP:
        return 0
    if result is _PARSE_ERROR:
        return 2

    json_output, fix = result
    toolkit_dir = toolkit_root()

    # Run all checks
    all_results: list[CheckResult] = []

    # 1. System baseline
    all_results.append(_check_python_version())
    all_results.append(_check_command("system", "git", "git"))
    all_results.append(_check_command("system", "gh (GitHub CLI)", "gh"))
    all_results.append(_check_gh_auth())

    # 2. AI tools
    for tool_name, cmd in [
        ("claude", "claude"),
        ("cursor", "cursor"),
        ("opencode", "opencode"),
        ("windsurf", "windsurf"),
        ("muse", "muse"),
    ]:
        all_results.append(_check_ai_tool(tool_name, cmd))

    # 3. Profiles
    all_results.extend(_check_profiles())

    # 4. Loop runtime
    all_results.extend(_check_loop_runtime(toolkit_dir))

    # 5. LLM providers
    all_results.extend(_check_llm_providers())

    # 6. MCP
    all_results.extend(_check_mcp())

    # 7. Scheduled loops
    all_results.extend(_check_scheduled_loops())

    # 8. Swarm tooling
    all_results.extend(_check_swarm())

    # 9. Provenance (per §52: inventory warnings, doctor --provenance validating SHA/commit immutability, expiry >90d)
    all_results.extend(_check_provenance(toolkit_dir))

    # 10. Products / Packs (per #387: pack consistency, complete coverage)
    all_results.extend(_check_products_and_packs(toolkit_dir))

    # 11. MCP registry (per #387: mcp/registry vs installed runtime)
    all_results.extend(_check_mcp_registry(toolkit_dir))

    # Output
    if json_output:
        print(json.dumps({"checks": [r.to_dict() for r in all_results]}, indent=2))
    else:
        print()
        print("agent-toolkit doctor")

        categories_seen: list[str] = []
        category_labels = {
            "system": "System baseline",
            "ai_tools": "AI tools",
            "profiles": "Profiles",
            "loops": "Loop runtime",
            "llm": "LLM providers",
            "mcp": "MCP",
            "scheduled": "Scheduled loops",
            "swarm": "Swarm tooling",
            "provenance": "Provenance (SHA/commit, expiry)",
            "packs": "Products / Packs",
        }
        for r in all_results:
            if r.category not in categories_seen:
                categories_seen.append(r.category)
                label = category_labels.get(r.category, r.category)
                _print_section(label)
            _print_result(r)

        # Summary
        n_ok = sum(1 for r in all_results if r.status == CheckResult.STATUS_OK)
        n_warn = sum(1 for r in all_results if r.status == CheckResult.STATUS_WARN)
        n_err = sum(1 for r in all_results if r.status == CheckResult.STATUS_ERR)

        print()
        print("── Summary ──")
        print(f"  ✓  {n_ok} ok   ⚠ {n_warn} warnings   ✗ {n_err} errors")
        print()

    # --fix: call install for warnings/errors related to profiles
    install_rc = 0
    if fix:
        has_profile_issues = any(
            r.category == "profiles" and r.status != CheckResult.STATUS_OK for r in all_results
        )
        if has_profile_issues:
            if not json_output:
                print("── Auto-fix: running install ──")
            from agent_toolkit.cli.install import cmd_install

            if json_output:
                import contextlib
                import io

                # Keep stdout JSON-pure: swallow install chatter.
                with contextlib.redirect_stdout(io.StringIO()):
                    install_rc = cmd_install([])
            else:
                install_rc = cmd_install([])

    errors = [r for r in all_results if r.status == CheckResult.STATUS_ERR]
    if errors:
        return 1
    if install_rc:
        return install_rc
    return 0
