"""
doctor — Check system health and AI tool availability.

Usage:
    agent-toolkit doctor [options]

Options:
    --json    Output results as JSON
    --fix     Attempt to auto-fix issues (installs missing profiles)
    --help    Show this help message

Exit codes:
    0 — no errors detected
    1 — one or more errors detected
"""
from __future__ import annotations
from __future__ import annotations


import json
import json
import os
import os
import platform
import platform
import shutil
import shutil
import subprocess
import subprocess
import sys
import sys
import urllib.request
import urllib.request
from pathlib import Path
from pathlib import Path
from agent_toolkit._paths import toolkit_root
from agent_toolkit._paths import toolkit_root

# Windows: force UTF-8 output so emoji chars (✓ ✗ ⚠) don't crash
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
    except Exception:
        pass



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

    STATUS_OK   = "ok"
    STATUS_WARN = "warn"
    STATUS_ERR  = "error"

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
    return CheckResult("system", "python >= 3.10", CheckResult.STATUS_ERR,
                       f"Found {version_str} — need 3.10+")


def _check_command(category: str, name: str, cmd: str) -> CheckResult:
    path = shutil.which(cmd)
    if path:
        # Try to get version
        try:
            result = subprocess.run(
                [cmd, "--version"], capture_output=True, text=True, timeout=5
            )
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
        return CheckResult("system", "gh auth", CheckResult.STATUS_WARN,
                           "gh installed but not authenticated — run: gh auth login")
    except Exception as exc:
        return CheckResult("system", "gh auth", CheckResult.STATUS_WARN, str(exc))


def _check_ai_tool(name: str, cmd: str) -> CheckResult:
    path = shutil.which(cmd)
    if path:
        return CheckResult("ai_tools", name, CheckResult.STATUS_OK, path)
    return CheckResult("ai_tools", name, CheckResult.STATUS_WARN,
                       f"'{cmd}' not found — tool may not be installed")


def _profile_installed(category: str, name: str, path: Path) -> CheckResult:
    if path.exists():
        return CheckResult(category, name, CheckResult.STATUS_OK, str(path))
    return CheckResult(category, name, CheckResult.STATUS_WARN,
                       f"Not installed: {path}")


def _check_profiles() -> list[CheckResult]:
    """Check whether profiles are installed for each detected tool."""
    results: list[CheckResult] = []
    home = Path.home()

    # claude-code
    if shutil.which("claude") or (home / ".claude").is_dir():
        results.append(_profile_installed("profiles", "claude-code CLAUDE.md",
                                          home / ".claude" / "CLAUDE.md"))
        # settings.json is user-owned and must not be managed by the installer.
        results.append(_profile_installed("profiles", "claude-code agents/",
                                          home / ".claude" / "agents"))

    # cursor
    if shutil.which("cursor") or (home / ".cursor").is_dir():
        results.append(_profile_installed("profiles", "cursor rules/",
                                          home / ".cursor" / "rules"))

    # opencode
    if shutil.which("opencode") or (home / ".config" / "opencode").is_dir():
        results.append(_profile_installed("profiles", "opencode agents/",
                                          home / ".config" / "opencode" / "agents"))
        results.append(_profile_installed("profiles", "opencode opencode.json",
                                          home / ".config" / "opencode" / "opencode.json"))

    # windsurf
    windsurf_dir: Path | None = None
    if (home / ".codeium" / "windsurf").is_dir():
        windsurf_dir = home / ".codeium" / "windsurf"
    elif (home / ".windsurf").is_dir():
        windsurf_dir = home / ".windsurf"
    elif shutil.which("windsurf"):
        windsurf_dir = home / ".codeium" / "windsurf"

    if windsurf_dir is not None:
        results.append(_profile_installed("profiles", "windsurf rules/",
                                          windsurf_dir / "rules"))
        results.append(_profile_installed("profiles", "windsurf memories/",
                                          windsurf_dir / "memories"))

    # pi
    if shutil.which("pi") or (home / ".pi").is_dir():
        results.append(_profile_installed("profiles", "pi skills/",
                                          home / ".pi" / "agent" / "skills"))

    return results


def _check_loop_runtime(toolkit_dir: Path | None) -> list[CheckResult]:
    results: list[CheckResult] = []

    # Check if `agent-toolkit loop` resolves (basic import test)
    try:
        subprocess.run(
            [sys.executable, "-m", "agent_toolkit", "loop", "--help"],
            capture_output=True, timeout=10
        )
        results.append(CheckResult("loops", "loop subcommand", CheckResult.STATUS_OK,
                                   "agent-toolkit loop --help succeeded"))
    except Exception as exc:
        results.append(CheckResult("loops", "loop subcommand", CheckResult.STATUS_WARN,
                                   f"Could not run loop command: {exc}"))

    # Check loops/ templates
    if toolkit_dir:
        loops_dir = toolkit_dir / "loops"
        if loops_dir.is_dir():
            count = sum(1 for d in loops_dir.iterdir() if d.is_dir())
            results.append(CheckResult("loops", "loop templates", CheckResult.STATUS_OK,
                                       f"{count} template(s) found in {loops_dir}"))
        else:
            results.append(CheckResult("loops", "loop templates", CheckResult.STATUS_WARN,
                                       f"loops/ directory not found at {loops_dir}"))
    else:
        results.append(CheckResult("loops", "loop templates", CheckResult.STATUS_WARN,
                                   "Toolkit directory not found — cannot check loop templates"))

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
        results.append(CheckResult("llm", "ollama", CheckResult.STATUS_OK,
                                   "running at localhost:11434"))
    except Exception:
        results.append(CheckResult("llm", "ollama", CheckResult.STATUS_WARN,
                                   "not reachable at localhost:11434"))

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
            results.append(CheckResult("llm", "opencode socket", CheckResult.STATUS_OK,
                                       str(sp)))
            break
    else:
        results.append(CheckResult("llm", "opencode socket", CheckResult.STATUS_WARN,
                                   "socket not found (opencode may not be running)"))

    return results


def _check_mcp() -> list[CheckResult]:
    results: list[CheckResult] = []
    config_path = Path.home() / ".config" / "agent-toolkit" / "mcp-config.json"

    if not config_path.exists():
        results.append(CheckResult("mcp", "mcp-config.json", CheckResult.STATUS_WARN,
                                   f"Not found: {config_path}  (run: agent-toolkit mcp setup <provider>)"))
        return results

    try:
        data = json.loads(config_path.read_text())
        providers = data.get("providers", {})
        if not providers:
            results.append(CheckResult("mcp", "mcp providers", CheckResult.STATUS_WARN,
                                       "Config exists but no providers configured"))
            return results
        for name, cfg in providers.items():
            enabled = cfg.get("enabled", False)
            validated = cfg.get("validated_at", "never")
            status = CheckResult.STATUS_OK if enabled else CheckResult.STATUS_WARN
            results.append(CheckResult("mcp", f"provider:{name}", status,
                                       f"enabled={enabled}, validated_at={validated}"))
    except (json.JSONDecodeError, OSError) as exc:
        results.append(CheckResult("mcp", "mcp-config.json", CheckResult.STATUS_ERR,
                                   f"Cannot read config: {exc}"))

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
                results.append(CheckResult("scheduled", "systemd timers", CheckResult.STATUS_WARN,
                                           "No agent-toolkit-*.timer files found"))
        else:
            results.append(CheckResult("scheduled", "systemd user dir", CheckResult.STATUS_WARN,
                                       f"Not found: {timer_dir}"))
    elif system == "Darwin":
        launchd_dir = Path.home() / "Library" / "LaunchAgents"
        if launchd_dir.is_dir():
            plists = list(launchd_dir.glob("com.agent-toolkit.*.plist"))
            if plists:
                for p in sorted(plists):
                    results.append(CheckResult("scheduled", p.name, CheckResult.STATUS_OK, str(p)))
            else:
                results.append(CheckResult("scheduled", "launchd plists", CheckResult.STATUS_WARN,
                                           "No com.agent-toolkit.*.plist files found"))
        else:
            results.append(CheckResult("scheduled", "LaunchAgents dir", CheckResult.STATUS_WARN,
                                       f"Not found: {launchd_dir}"))
    else:
        results.append(CheckResult("scheduled", "scheduled loops", CheckResult.STATUS_WARN,
                                   f"Unsupported platform: {system}"))

    return results


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

def _print_section(title: str) -> None:
    print(f"\n── {title} ──")


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
        else:
            print(f"  ✗  Unknown option: {arg}  (run 'agent-toolkit doctor --help')",
                  file=sys.stderr)
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

    # Output
    if json_output:
        print(json.dumps({"checks": [r.to_dict() for r in all_results]}, indent=2))
    else:
        print()
        print("agent-toolkit doctor")

        categories_seen: list[str] = []
        category_labels = {
            "system":    "System baseline",
            "ai_tools":  "AI tools",
            "profiles":  "Profiles",
            "loops":     "Loop runtime",
            "llm":       "LLM providers",
            "mcp":       "MCP",
            "scheduled": "Scheduled loops",
        }
        for r in all_results:
            if r.category not in categories_seen:
                categories_seen.append(r.category)
                label = category_labels.get(r.category, r.category)
                _print_section(label)
            _print_result(r)

        # Summary
        n_ok   = sum(1 for r in all_results if r.status == CheckResult.STATUS_OK)
        n_warn = sum(1 for r in all_results if r.status == CheckResult.STATUS_WARN)
        n_err  = sum(1 for r in all_results if r.status == CheckResult.STATUS_ERR)

        print()
        print("── Summary ──")
        print(f"  ✓  {n_ok} ok   ⚠ {n_warn} warnings   ✗ {n_err} errors")
        print()

    # --fix: call install for warnings/errors related to profiles
    if fix:
        has_profile_issues = any(
            r.category == "profiles" and r.status != CheckResult.STATUS_OK
            for r in all_results
        )
        if has_profile_issues:
            if not json_output:
                print("── Auto-fix: running install ──")
            from agent_toolkit.cli.install import cmd_install
            cmd_install([])

    errors = [r for r in all_results if r.status == CheckResult.STATUS_ERR]
    return 1 if errors else 0
