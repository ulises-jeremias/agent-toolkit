"""
install — Install agent-toolkit profiles for AI coding assistants.

Usage:
    agent-toolkit install [options]

Options:
    --tools <list>  Comma-separated tools to install (default: auto-detect)
                    Valid: claude-code, cursor, opencode, copilot, windsurf, pi
    --dry-run       Show what would happen without making changes
    --force         Overwrite existing files without prompting
    --offline       Use only bundled/wheel data (skip GitHub Release cache)
    --help          Show this help message
"""
from __future__ import annotations

import json
import shutil
import sys
import os
from pathlib import Path
from agent_toolkit._paths import toolkit_root
from agent_toolkit.installer.merge import merge_json_file
from agent_toolkit.installer.sources import (
    agent_install_sources,
    compiled_agent_files,
    plugins_dir,
    profile_file,
)

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

    return success


def _install_agent_files(
    tool: str,
    dst_dir: Path,
    *,
    dry_run: bool,
    force: bool,
    data_root: Path | None = None,
) -> bool:
    """Install agent files from compiled plugins/ or profiles/ fallback."""
    root = data_root or toolkit_root()
    agents = agent_install_sources(tool, data_root=root)
    if not agents:
        _warn(f"No agent sources found for {tool}")
        return True

    plugins = plugins_dir(root)
    if plugins is not None:
        _info(f"Using compiler artifacts from {plugins}")

    success = True
    for name, src in sorted(agents.items()):
        dst = dst_dir / f"{name}.md"
        success &= _copy_file(src, dst, dry_run=dry_run, force=force)
    return success


def _install_claude_code(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: Claude Code")
    root = toolkit_root()
    profile = profile_file("claude-code", data_root=root)

    if not profile.is_dir() and not compiled_agent_files(root):
        _warn(f"Profile directory not found: {profile}")
        return False

    home = Path.home()
    success = True
    # Install instruction/agent files only. Never write ~/.claude/settings.json —
    # that file is user-owned (plugins, permissions, env). Target contract:
    # distributions/targets/claude-code.yaml → plugin_settings_scope: plugin-local.
    claude_md = profile_file("claude-code", "CLAUDE.md", data_root=root)
    if claude_md.is_file():
        success &= _copy_file(
            claude_md,
            home / ".claude" / "CLAUDE.md",
            dry_run=dry_run,
            force=force,
        )
    settings_src = profile / "settings.json"
    if settings_src.is_file():
        _info(
            "Skipping ~/.claude/settings.json (user-owned). "
            "Use Claude Code marketplace plugins for toolkit capabilities; "
            f"reference profile kept at {settings_src}"
        )
    success &= _install_agent_files(
        "claude-code",
        home / ".claude" / "agents",
        dry_run=dry_run,
        force=force,
        data_root=root,
    )
    return success


def _install_cursor(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: Cursor")
    src = profile_file("cursor", "rules")

    if not src.is_dir():
        _warn(f"Cursor rules directory not found: {src}")
        return False

    return _copy_dir(src, Path.home() / ".cursor" / "rules",
                     dry_run=dry_run, force=force)


def _install_json_config(
    src: Path,
    dst: Path,
    *,
    dry_run: bool,
    force: bool,
) -> bool:
    """Install a JSON config with non-destructive merge when dst already exists."""
    if not src.is_file():
        _warn(f"Source not found, skipping: {src}")
        return True

    if dry_run:
        if dst.is_file() and not force:
            _dry(f"Would merge: {src.name} → {dst}")
        else:
            _dry(f"Would copy: {src.name} → {dst}")
        return True

    try:
        merged, patches, ownership = merge_json_file(src, dst, force=force)
    except (json.JSONDecodeError, OSError) as exc:
        _err(f"Failed to merge {src} → {dst}: {exc}")
        return False

    if ownership == "unchanged":
        _skip(f"Already up to date: {dst}")
        return True

    if ownership == "skipped":
        _skip(f"Preserving user-owned file (use --force to overwrite): {dst}")
        return True

    if merged is None:
        return _copy_file(src, dst, dry_run=False, force=force)

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    if ownership == "merged" and patches:
        _ok(f"Merged config ({len(patches)} key(s) added): {dst}")
    else:
        _ok(f"Installed: {dst}")
    return True


def _install_opencode(*, dry_run: bool, force: bool) -> bool:
    print()
    _info("Installing: OpenCode")
    root = toolkit_root()
    profile = profile_file("opencode", data_root=root)

    if not profile.is_dir() and not compiled_agent_files(root):
        _warn(f"OpenCode profile directory not found: {profile}")
        return False

    opencode_json = profile_file("opencode", "opencode.json", data_root=root)
    if opencode_json.is_file():
        try:
            profile_data = json.loads(opencode_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            _err(f"Invalid profiles/opencode/opencode.json: {exc}")
            return False
        from agent_toolkit.compiler.targets.opencode import OpenCodeAdapter

        validation_errors = OpenCodeAdapter.validate_opencode_json(profile_data)
        if validation_errors:
            for msg in validation_errors:
                _err(msg)
            return False

    home = Path.home()
    success = True
    if opencode_json.is_file():
        success &= _install_json_config(
            opencode_json,
            home / ".config" / "opencode" / "opencode.json",
            dry_run=dry_run,
            force=force,
        )
    success &= _install_agent_files(
        "opencode",
        home / ".config" / "opencode" / "agents",
        dry_run=dry_run,
        force=force,
        data_root=root,
    )
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


# Sentinel parse outcomes — must not be confused with a successful empty-tools tuple.
_PARSE_HELP = object()
_PARSE_ERROR = object()


def _parse_args(args: list[str]):
    """Return (tools, dry_run, force, offline), _PARSE_HELP, or _PARSE_ERROR."""
    dry_run = False
    force = False
    offline = False
    requested: str = ""

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print(__doc__)
            return _PARSE_HELP
        elif arg == "--dry-run":
            dry_run = True
        elif arg == "--force":
            force = True
        elif arg == "--offline":
            offline = True
        elif arg == "--tools":
            if i + 1 >= len(args):
                _err("--tools requires an argument")
                return _PARSE_ERROR
            requested = args[i + 1]
            i += 1
        else:
            _err(f"Unknown option: {arg}  (run 'agent-toolkit install --help' for usage)")
            return _PARSE_ERROR
        i += 1

    tools: list[str] = []
    if requested:
        tools = [t.strip() for t in requested.split(",") if t.strip()]
    return tools, dry_run, force, offline


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def cmd_install(args: list[str]) -> int:
    """Install agent-toolkit profiles for AI coding assistants.

    Returns 0 on success, 1 on install failure, 2 on usage/parse errors.
    """
    result = _parse_args(args)
    if result is _PARSE_HELP:
        return 0
    if result is _PARSE_ERROR:
        return 2

    tools, dry_run, force, offline = result

    if offline:
        os.environ["AGENT_TOOLKIT_OFFLINE"] = "1"
        _info("Offline mode — using bundled data only")

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
