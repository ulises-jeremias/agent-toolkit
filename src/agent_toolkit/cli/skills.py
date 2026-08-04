"""
skills — Skill management for agent-toolkit.

Usage:
    agent-toolkit skills <subcommand> [options]

Subcommands:
    list [--domain DOMAIN]     List skills grouped by domain
    sync [--tools TOOLS]       Sync skills to tool-specific directories
    validate                   Validate SKILL.md frontmatter

Options:
    --domain DOMAIN   Filter by domain (used with list)
    --tools TOOLS     Comma-separated tools to sync (used with sync)
                      Valid: claude-code, cursor, opencode
    --help            Show this help message
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path
from agent_toolkit._paths import toolkit_root





# ---------------------------------------------------------------------------
# Skills layout loading
# ---------------------------------------------------------------------------

def _load_layout(toolkit_dir: Path) -> dict | None:
    layout_path = toolkit_dir / "catalogs" / "skills-layout.json"
    if not layout_path.exists():
        print(f"  ✗  skills-layout.json not found: {layout_path}", file=sys.stderr)
        return None
    try:
        return json.loads(layout_path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        print(f"  ✗  Cannot parse skills-layout.json: {exc}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# SKILL.md frontmatter parsing (stdlib-only, no PyYAML)
# ---------------------------------------------------------------------------

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_SIMPLE_KV_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$")


def _parse_frontmatter_simple(content: str) -> dict | None:
    """Parse simple YAML frontmatter (key: value pairs only, no nesting)."""
    match = _FRONTMATTER_RE.match(content)
    if not match:
        return None
    result: dict[str, str] = {}
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = _SIMPLE_KV_RE.match(line)
        if m:
            key = m.group(1).strip()
            val = m.group(2).strip().strip('"').strip("'")
            result[key] = val
    return result


# ---------------------------------------------------------------------------
# list subcommand
# ---------------------------------------------------------------------------

def _cmd_list(args: list[str], toolkit_dir: Path) -> int:
    """Display skills grouped by domain."""
    domain_filter: str | None = None
    i = 0
    while i < len(args):
        if args[i] == "--domain" and i + 1 < len(args):
            domain_filter = args[i + 1]
            i += 2
        else:
            i += 1

    layout = _load_layout(toolkit_dir)
    if layout is None:
        return 1

    groups: dict[str, list[str]] = layout.get("groups", {})
    skills_index: dict[str, dict] = {s["name"]: s for s in layout.get("skills", [])}

    if domain_filter and domain_filter not in groups:
        available = ", ".join(sorted(groups.keys()))
        print(f"  ✗  Unknown domain: {domain_filter}  (available: {available})", file=sys.stderr)
        return 1

    targets = {domain_filter: groups[domain_filter]} if domain_filter else groups

    print()
    print("Available skills")
    print()

    for domain, skill_names in sorted(targets.items()):
        print(f"── {domain} ──")
        for name in sorted(skill_names):
            info = skills_index.get(name, {})
            path = toolkit_dir / info.get("path", f"skills/{domain}/{name}")
            skill_md = path / "SKILL.md"

            description = ""
            if skill_md.exists():
                try:
                    content = skill_md.read_text(errors="replace")
                    fm = _parse_frontmatter_simple(content)
                    if fm:
                        description = fm.get("description", "")
                except OSError:
                    pass

            exists_marker = "✓" if skill_md.exists() else "✗"
            desc_str = f"  — {description}" if description else ""
            print(f"  {exists_marker}  {name:<40}{desc_str}")
        print()

    total = sum(len(v) for v in groups.values())
    print(f"Total: {total} skill(s) across {len(groups)} domain(s)")
    print()
    return 0


# ---------------------------------------------------------------------------
# sync subcommand
# ---------------------------------------------------------------------------

def _sync_claude_code(toolkit_dir: Path) -> bool:
    """Copy/symlink SKILL.md files into ~/.claude/skills/<name>/."""
    skills_dir = toolkit_dir / "skills"
    if not skills_dir.is_dir():
        print(f"  ✗  Skills directory not found: {skills_dir}", file=sys.stderr)
        return False

    dst_root = Path.home() / ".claude" / "skills"
    success = True

    for skill_md in sorted(skills_dir.rglob("SKILL.md")):
        skill_dir = skill_md.parent
        name = skill_dir.name
        dst = dst_root / name / "SKILL.md"
        try:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists() and dst.read_bytes() == skill_md.read_bytes():
                print(f"  -  {name}: already up to date")
                continue
            shutil.copy2(skill_md, dst)
            print(f"  ✓  {name}: synced → {dst}")
        except (PermissionError, OSError) as exc:
            print(f"  ✗  {name}: {exc}", file=sys.stderr)
            success = False

    return success


def _sync_cursor(toolkit_dir: Path) -> bool:
    """Write a skills index JSON to ~/.cursor/skills-index.json."""
    layout = _load_layout(toolkit_dir)
    if layout is None:
        return False

    index: list[dict] = []
    for skill_info in layout.get("skills", []):
        name = skill_info["name"]
        path = toolkit_dir / skill_info.get("path", f"skills/{skill_info.get('group','')}/{name}")
        skill_md = path / "SKILL.md"
        description = ""
        if skill_md.exists():
            try:
                fm = _parse_frontmatter_simple(skill_md.read_text(errors="replace"))
                if fm:
                    description = fm.get("description", "")
            except OSError:
                pass
        index.append({
            "name": name,
            "group": skill_info.get("group", ""),
            "description": description,
            "path": str(path),
        })

    dst = Path.home() / ".cursor" / "skills-index.json"
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(json.dumps({"skills": index}, indent=2) + "\n")
        print(f"  ✓  cursor: skills-index written → {dst} ({len(index)} skills)")
        return True
    except (PermissionError, OSError) as exc:
        print(f"  ✗  cursor: {exc}", file=sys.stderr)
        return False


def _sync_opencode(toolkit_dir: Path) -> bool:
    """Copy SKILL.md files to ~/.config/opencode/skills/<name>/."""
    skills_dir = toolkit_dir / "skills"
    if not skills_dir.is_dir():
        print(f"  ✗  Skills directory not found: {skills_dir}", file=sys.stderr)
        return False

    dst_root = Path.home() / ".config" / "opencode" / "skills"
    success = True

    for skill_md in sorted(skills_dir.rglob("SKILL.md")):
        skill_dir = skill_md.parent
        name = skill_dir.name
        dst = dst_root / name / "SKILL.md"
        try:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists() and dst.read_bytes() == skill_md.read_bytes():
                print(f"  -  {name}: already up to date")
                continue
            shutil.copy2(skill_md, dst)
            print(f"  ✓  {name}: synced → {dst}")
        except (PermissionError, OSError) as exc:
            print(f"  ✗  {name}: {exc}", file=sys.stderr)
            success = False

    return success


def _cmd_sync(args: list[str], toolkit_dir: Path) -> int:
    """Sync skills to tool-specific directories."""
    tools_arg: str | None = None
    i = 0
    while i < len(args):
        if args[i] == "--tools" and i + 1 < len(args):
            tools_arg = args[i + 1]
            i += 2
        else:
            i += 1

    valid_tools = ("claude-code", "cursor", "opencode")
    if tools_arg:
        tools = [t.strip() for t in tools_arg.split(",") if t.strip()]
    else:
        # Default: all supported tools
        tools = list(valid_tools)

    print()
    print("Syncing skills...")
    print()

    success = True
    for tool in tools:
        if tool == "claude-code":
            print("── claude-code ──")
            if not _sync_claude_code(toolkit_dir):
                success = False
            print()
        elif tool == "cursor":
            print("── cursor ──")
            if not _sync_cursor(toolkit_dir):
                success = False
            print()
        elif tool == "opencode":
            print("── opencode ──")
            if not _sync_opencode(toolkit_dir):
                success = False
            print()
        else:
            print(f"  ⚠  Unknown tool: {tool}  (valid: {', '.join(valid_tools)})")

    return 0 if success else 1


# ---------------------------------------------------------------------------
# validate subcommand
# ---------------------------------------------------------------------------

def _validate_skill(skill_dir: Path, toolkit_dir: Path) -> tuple[int, int]:
    """Validate a single skill directory. Returns (errors, warnings)."""
    rel = skill_dir.relative_to(toolkit_dir)
    skill_md = skill_dir / "SKILL.md"
    errors = 0
    warnings = 0

    if not skill_md.exists():
        print(f"  ✗  {rel}: missing SKILL.md")
        return 1, 0

    try:
        content = skill_md.read_text(errors="replace")
    except OSError as exc:
        print(f"  ✗  {rel}/SKILL.md: cannot read: {exc}")
        return 1, 0

    fm = _parse_frontmatter_simple(content)
    if fm is None:
        print(f"  ✗  {rel}/SKILL.md: no YAML frontmatter found (must start with ---)")
        return 1, 0

    ok = True
    for field in ("name", "description"):
        if not fm.get(field):
            print(f"  ✗  {rel}/SKILL.md: missing required frontmatter field '{field}'")
            errors += 1
            ok = False

    if fm.get("name") and fm["name"] != skill_dir.name:
        print(f"  ⚠  {rel}/SKILL.md: name '{fm['name']}' does not match directory '{skill_dir.name}'")
        warnings += 1

    if (skill_dir / "skill.json").exists():
        print(f"  ⚠  {rel}: skill.json found — not needed, can be removed")
        warnings += 1

    if ok:
        print(f"  ✓  {rel}/SKILL.md")

    return errors, warnings


def _cmd_validate(toolkit_dir: Path) -> int:
    """Validate SKILL.md frontmatter for all skills."""
    skills_dir = toolkit_dir / "skills"
    plugins_dir = toolkit_dir / "plugins"

    if not skills_dir.is_dir():
        print(f"  ✗  Skills directory not found: {skills_dir}", file=sys.stderr)
        return 1

    print()
    print("Validating SKILL.md frontmatter...")
    print()

    total_errors = 0
    total_warnings = 0
    skill_count = 0

    print("── skills/ ──")
    for domain_dir in sorted(skills_dir.iterdir()):
        if not domain_dir.is_dir():
            continue
        for skill_dir in sorted(domain_dir.iterdir()):
            if not skill_dir.is_dir():
                continue
            errs, warns = _validate_skill(skill_dir, toolkit_dir)
            total_errors += errs
            total_warnings += warns
            skill_count += 1

    if plugins_dir.is_dir():
        print()
        print("── plugins/ (bundled copies) ──")
        for plugin_dir in sorted(plugins_dir.iterdir()):
            if not plugin_dir.is_dir():
                continue
            plugin_skills = plugin_dir / "skills"
            if plugin_skills.exists():
                for skill_dir in sorted(plugin_skills.iterdir()):
                    if skill_dir.is_dir():
                        errs, warns = _validate_skill(skill_dir, toolkit_dir)
                        total_errors += errs
                        total_warnings += warns

    print()
    print("── Summary ──")
    print(f"  Skills validated: {skill_count}")

    if total_errors:
        print(f"\n  ✗  {total_errors} error(s) found")
        return 1

    if total_warnings:
        print(f"\n  ⚠  All valid with {total_warnings} warning(s)")
    else:
        print("\n  ✓  All SKILL.md files are valid!")
    return 0


# ---------------------------------------------------------------------------
# Argument parsing & dispatch
# ---------------------------------------------------------------------------

def cmd_skills(args: list[str]) -> int:
    """Skill management entry point.

    Returns 0 on success, 1 on failure.
    """
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    toolkit_dir = toolkit_root()
    if toolkit_dir is None:
        print("  ✗  Cannot locate toolkit directory", file=sys.stderr)
        return 1

    subcommand = args[0]
    rest = args[1:]

    if subcommand == "list":
        return _cmd_list(rest, toolkit_dir)
    elif subcommand == "sync":
        return _cmd_sync(rest, toolkit_dir)
    elif subcommand == "validate":
        return _cmd_validate(toolkit_dir)
    else:
        print(f"  ✗  Unknown subcommand: {subcommand}", file=sys.stderr)
        print("  Valid subcommands: list, sync, validate", file=sys.stderr)
        return 1
