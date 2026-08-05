"""
install — Install agent-toolkit profiles for AI coding assistants.

Usage:
    agent-toolkit install [options]

Options:
    --tools <list>  Comma-separated tools to install (default: auto-detect)
                    Valid: claude-code, cursor, opencode, copilot, windsurf, pi
    --dry-run       Show what would happen without making changes
    --force         Overwrite existing files without prompting
    --help          Show this help message
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path
from agent_toolkit._paths import toolkit_root

import sys as _sys_win
if _sys_win.platform == "win32":
    try:
        _sys_win.stdout.reconfigure(encoding="utf-8", errors="replace")
        _sys_win.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass







# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _info(msg: str) -> None:
    print(f"  [info]  {msg}")

def _ok(msg: str) -> None:
    print(f"  ✓  {msg}")

def _warn(msg: str) -> None:
    print(f"  ⚠  {msg}")

def _skip(msg: str) -> None:
    print(f"  -  {msg}")

def _dry(msg: str) -> None:
    print(f"  [dry]   {msg}")

def _err(msg: str) -> None:
    print(f"  ✗  {msg}", file=sys.stderr)


def _confirm(prompt: str, force: bool) -> bool:
    """Ask user yes/no. Return True if force is set or user confirms."""
    if force:
        return True
    try:
        answer = input(f"  {prompt} [y/N] ").strip().lower()
    except EOFError:
        return False
    return answer in ("y", "yes")


def _files_identical(a: Path, b: Path) -> bool:
    """Return True if both files exist and have identical content."""
    if not a.is_file() or not b.is_file():
        return False
    return a.read_bytes() == b.read_bytes()


def _copy_file(src: Path, dst: Path, *, dry_run: bool, force: bool) -> bool:
    """Copy src to dst, respecting dry-run, force, and idempotency.

    Returns True on success (including skip), False on failure.
    """
    if not src.is_file():
        _warn(f"Source not found, skipping: {src}")
        return True  # not a hard failure

    if dry_run:
        _dry(f"Would copy: {src.name} → {dst}")
        return True

    if _files_identical(src, dst):
        _skip(f"Already up to date: {dst}")
        return True

    if dst.exists() and not force:
        if not _confirm(f"Overwrite existing file: {dst}?", force=False):
            _skip(f"Skipped: {dst}")
            return True

    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        _ok(f"Installed: {dst}")
        return True
    except PermissionError as exc:
        _err(f"Permission denied writing {dst}: {exc}")
        return False
    except OSError as exc:
        _err(f"Failed to copy {src} → {dst}: {exc}")
        return False


def _copy_dir(src_dir: Path, dst_dir: Path, *, dry_run: bool, force: bool) -> bool:
    """Recursively copy all files from src_dir into dst_dir."""
    if not src_dir.is_dir():
        _warn(f"Source directory not found, skipping: {src_dir}")
        return True

    if dry_run:
        count = sum(1 for _ in src_dir.rglob("*") if _.is_file())
        _dry(f"Would copy {count} file(s) from {src_dir.name}/ → {dst_dir}/")
        return True

    success = True
    for src_file in sorted(src_dir.rglob("*")):
        if not src_file.is_file():
            continue
        rel = src_file.relative_to(src_dir)
        dst_file = dst_dir / rel
        if not _copy_file(src_file, dst_file, dry_run=dry_run, force=force):
            success = False
    return success


# ---------------------------------------------------------------------------
# Tool detection
# ---------------------------------------------------------------------------

def _detect_claude_code() -> bool:
    home = Path.home()
    return shutil.which("claude") is not None or (home / ".claude").is_dir()

def _detect_cursor() -> bool:
    home = Path.home()
    return shutil.which("cursor") is not None or (home / ".cursor").is_dir()

def _detect_opencode() -> bool:
    home = Path.home()
    return shutil.which("opencode") is not None or (home / ".config" / "opencode").is_dir()

def _detect_windsurf() -> bool:
    home = Path.home()
    return (
        shutil.which("windsurf") is not None
        or (home / ".codeium" / "windsurf").is_dir()
        or (home / ".windsurf").is_dir()
    )

def _detect_pi() -> bool:
    home = Path.home()
    return shutil.which("pi") is not None or (home / ".pi").is_dir()


def _windsurf_config_dir() -> Path:
    home = Path.home()
    if (home / ".codeium" / "windsurf").is_dir():
        return home / ".codeium" / "windsurf"
    if (home / ".windsurf").is_dir():
        return home / ".windsurf"
    return home / ".codeium" / "windsurf"


# ---------------------------------------------------------------------------
# Per-tool installers
# ---------------------------------------------------------------------------

def _install_claude_code(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: Claude Code")
    src = toolkit_root() / "profiles" / "claude-code"

    if not src.is_dir():
        _warn(f"Profile directory not found: {src}")
        return False

    home = Path.home()
    success = True
    # Install instruction/agent files only. Never write ~/.claude/settings.json —
    # that file is user-owned (plugins, permissions, env). Target contract:
    # distributions/targets/claude-code.yaml → plugin_settings_scope: plugin-local.
    success &= _copy_file(src / "CLAUDE.md", home / ".claude" / "CLAUDE.md",
                          dry_run=dry_run, force=force)
    settings_src = src / "settings.json"
    if settings_src.is_file():
        _info(
            "Skipping ~/.claude/settings.json (user-owned). "
            "Use Claude Code marketplace plugins for toolkit capabilities; "
            f"reference profile kept at {settings_src}"
        )
    if (src / "agents").is_dir():
        success &= _copy_dir(src / "agents", home / ".claude" / "agents",
                             dry_run=dry_run, force=force)
    return success


def _install_cursor(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: Cursor")
    src = toolkit_root() / "profiles" / "cursor" / "rules"

    if not src.is_dir():
        _warn(f"Cursor rules directory not found: {src}")
        return False

    return _copy_dir(src, Path.home() / ".cursor" / "rules",
                     dry_run=dry_run, force=force)


def _install_opencode(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: OpenCode")
    src = toolkit_root() / "profiles" / "opencode"

    if not src.is_dir():
        _warn(f"OpenCode profile directory not found: {src}")
        return False

    home = Path.home()
    success = True
    success &= _copy_file(src / "opencode.json", home / ".config" / "opencode" / "opencode.json",
                          dry_run=dry_run, force=force)
    if (src / "agents").is_dir():
        success &= _copy_dir(src / "agents", home / ".config" / "opencode" / "agents",
                             dry_run=dry_run, force=force)
    return success


def _install_copilot(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: GitHub Copilot")
    _info("Copilot instructions are per-project and committed to the repository.")

    src = toolkit_root() / "profiles" / "copilot" / "copilot-instructions.md"
    if not src.is_file():
        _warn(f"Copilot instructions not found: {src}")
        return False

    if dry_run:
        _dry("Would copy copilot-instructions.md to <project>/.github/")
        return True

    import sys as _sys
    if not _sys.stdin.isatty():
        _skip("Non-interactive — run 'agent-toolkit install --tools copilot' interactively")
        return True

    try:
        project_dir_raw = input("  Enter project directory path (or press Enter to skip): ").strip()
    except EOFError:
        project_dir_raw = ""

    if not project_dir_raw:
        _skip("No project directory specified — skipping Copilot install")
        _info(f"To install manually: cp {src} <your-project>/.github/copilot-instructions.md")
        return True

    # Expand tilde
    project_dir = Path(project_dir_raw).expanduser().resolve()

    if not project_dir.is_dir():
        _err(f"Directory not found: {project_dir}")
        return False

    dst = project_dir / ".github" / "copilot-instructions.md"
    success = _copy_file(src, dst, dry_run=dry_run, force=force)
    if success:
        _info("Remember to: git add .github/copilot-instructions.md && git commit")
    return success


def _install_windsurf(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: Windsurf")
    src = toolkit_root() / "profiles" / "windsurf"

    if not src.is_dir():
        _warn(f"Windsurf profile directory not found: {src}")
        return False

    config_dir = _windsurf_config_dir()
    success = True
    if (src / "rules").is_dir():
        success &= _copy_dir(src / "rules", config_dir / "rules",
                             dry_run=dry_run, force=force)
    if (src / "memories").is_dir():
        success &= _copy_dir(src / "memories", config_dir / "memories",
                             dry_run=dry_run, force=force)
    return success


def _install_pi(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: Pi Coding Agent")
    src = toolkit_root() / "profiles" / "pi" / "skills"

    if not src.is_dir():
        _warn(f"Pi skills directory not found: {src}")
        return False

    return _copy_dir(src, Path.home() / ".pi" / "agent" / "skills",
                     dry_run=dry_run, force=force)


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

_VALID_TOOLS = ("claude-code", "cursor", "opencode", "copilot", "windsurf", "pi")


def _parse_args(args: list[str]) -> tuple[list[str], bool, bool] | None:
    """Return (tools, dry_run, force) or None to signal early exit."""
    dry_run = False
    force = False
    requested: str = ""

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print(__doc__)
            return None
        elif arg == "--dry-run":
            dry_run = True
        elif arg == "--force":
            force = True
        elif arg == "--tools":
            if i + 1 >= len(args):
                _err("--tools requires an argument")
                return None
            requested = args[i + 1]
            i += 1
        else:
            _err(f"Unknown option: {arg}  (run 'agent-toolkit install --help' for usage)")
            return None
        i += 1

    tools: list[str] = []
    if requested:
        tools = [t.strip() for t in requested.split(",") if t.strip()]
    return tools, dry_run, force


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def cmd_install(args: list[str]) -> int:
    """Install agent-toolkit profiles for AI coding assistants.

    Returns 0 on success, 1 on any failure.
    """
    result = _parse_args(args)
    if result is None:
        return 0

    tools, dry_run, force = result

    print()
    print("agent-toolkit installer")
    print(f"Toolkit: {toolkit_root()}")

    if dry_run:
        print()
        _warn("DRY RUN — no files will be written")

    # Determine tools
    if not tools:
        print()
        _info("Auto-detecting installed AI tools...")
        if _detect_claude_code():
            tools.append("claude-code")
            _info("  Detected: Claude Code")
        if _detect_cursor():
            tools.append("cursor")
            _info("  Detected: Cursor")
        if _detect_opencode():
            tools.append("opencode")
            _info("  Detected: OpenCode")
        if _detect_windsurf():
            tools.append("windsurf")
            _info("  Detected: Windsurf")
        if _detect_pi():
            tools.append("pi")
            _info("  Detected: Pi Coding Agent")

        # Copilot is per-project and requires a path — never auto-install.
        # Only installed when explicitly passed via --tools copilot.
        _info("  [info] Copilot: use --tools copilot to install per-project")

        if not tools:
            _warn("No AI tools detected. Install at least one supported tool and re-run,")
            _warn("or specify with: --tools claude-code,cursor,opencode,copilot,windsurf,pi")
            return 1

    print()
    _info(f"Tools to install: {', '.join(tools)}")

    installed: list[str] = []
    skipped: list[str] = []
    failed: list[str] = []

    _installers = {
        "claude-code": _install_claude_code,
        "cursor": _install_cursor,
        "opencode": _install_opencode,
        "copilot": _install_copilot,
        "windsurf": _install_windsurf,
        "pi": _install_pi,
    }

    for tool in tools:
        installer = _installers.get(tool)
        if installer is None:
            _warn(f"Unknown tool: {tool} (valid: {', '.join(_VALID_TOOLS)})")
            skipped.append(tool)
            continue
        ok = installer(dry_run=dry_run, force=force)
        if ok:
            installed.append(tool)
        else:
            failed.append(tool)

    print()
    print("----------------------------------------------------------------------")
    print("Installation summary")

    if installed:
        _ok(f"Installed: {', '.join(installed)}")
    if skipped:
        _skip(f"Skipped:   {', '.join(skipped)}")
    if failed:
        _err(f"Failed:    {', '.join(failed)}")

    print()
    _info("Next steps:")
    _info("  1. Restart your AI tool(s) to load the new profiles")
    _info("  2. Run 'agent-toolkit doctor' to verify the installation")
    _info("  3. See docs/MCP.md to configure external service integrations")
    _info("  4. See docs/PROFILES.md for per-tool customization options")
    print()

    return 1 if failed else 0
