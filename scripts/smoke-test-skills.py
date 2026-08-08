#!/usr/bin/env python3
"""
Author: RawNuke
Copyright (c) 2026 RawNuke. All rights reserved.

Mechanical smoke validation for skills/ and agents/ directories.

Checks every SKILL.md and AGENT.md for:
- YAML frontmatter that parses
- Required fields present (name, description)
- Directory name matches frontmatter name
- Description is not a placeholder
- Internal file references resolve

Run this locally:
  python3 scripts/smoke-test-skills.py
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml", "--quiet"])
    import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
AGENTS_DIR = REPO_ROOT / "agents"

REQUIRED_FRONTMATTER = ["name", "description"]

PLACEHOLDER_DESCRIPTIONS = {
    "",
    "-",
    "tbd",
    "TBD",
    "todo",
    "TODO",
    "wip",
    "WIP",
}

ERRORS: list[str] = []
_SEEN_ERRORS: set[str] = set()


def error(msg: str) -> None:
    if msg in _SEEN_ERRORS:
        return
    _SEEN_ERRORS.add(msg)
    ERRORS.append(msg)
    print(f"  X {msg}")


def ok_msg(msg: str) -> None:
    print(f"  OK {msg}")


def parse_frontmatter(path: Path) -> dict | None:
    content = path.read_text(errors="replace")
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return None
    try:
        return yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError as e:
        error(f"{path_relative(path)}: invalid YAML frontmatter: {e}")
        return None


def path_relative(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def check_file_exists(ref_path: Path, source: Path) -> bool:
    if ref_path.exists():
        return True
    error(
        f"{path_relative(source)}: references '{ref_path}' which does not exist"
    )
    return False


LINKABLE_DIRS = {
    "skills",
    "agents",
    "docs",
    "scripts",
    "schemas",
    "catalogs",
    "loops",
    "profiles",
    "packs",
    "mcp",
    "tools",
    "integrations",
    "distributions",
    "capabilities",
    "plugins",
    ".github",
}


def _looks_like_repo_ref(target: str) -> bool:
    if target.startswith(("./", "../")):
        return True
    top = target.split("/")[0]
    return top in LINKABLE_DIRS


def resolve_links(content: str, source_path: Path) -> None:
    source_dir = source_path.parent
    link_pattern = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")
    for match_obj in link_pattern.finditer(content):
        target = match_obj.group(2)
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        anchor_idx = target.find("#")
        file_part = target[:anchor_idx] if anchor_idx >= 0 else target
        if not file_part:
            continue
        if not _looks_like_repo_ref(file_part):
            continue
        candidate = (source_dir / file_part).resolve()
        try:
            candidate.relative_to(REPO_ROOT)
        except ValueError:
            continue
        if not candidate.exists():
            error(
                f"{path_relative(source_path)}: link target '{file_part}' does not resolve"
            )


def validate_skill(skill_dir: Path) -> bool:
    skill_md = skill_dir / "SKILL.md"
    rel = path_relative(skill_dir)
    ok_flag = True

    if not skill_md.exists():
        error(f"{rel}: missing SKILL.md")
        return False

    fm = parse_frontmatter(skill_md)
    if fm is None:
        error(f"{rel}/SKILL.md: no YAML frontmatter (must start with '---')")
        return False

    for field in REQUIRED_FRONTMATTER:
        if not fm.get(field):
            error(f"{rel}/SKILL.md: missing required field '{field}'")
            ok_flag = False

    name = fm.get("name", "")
    if name and name != skill_dir.name:
        error(
            f"{rel}/SKILL.md: name '{name}' does not match directory '{skill_dir.name}'"
        )
        ok_flag = False

    desc = fm.get("description", "")
    if isinstance(desc, str) and desc.strip() in PLACEHOLDER_DESCRIPTIONS:
        error(
            f"{rel}/SKILL.md: description is a placeholder ('{desc.strip()}')"
        )
        ok_flag = False

    content = skill_md.read_text(errors="replace")
    resolve_links(content, skill_md)

    if ok_flag:
        ok_msg(rel)
    return ok_flag


def validate_agent(agent_dir: Path) -> bool:
    agent_md = agent_dir / "AGENT.md"
    rel = path_relative(agent_dir)
    ok_flag = True

    if not agent_md.exists():
        error(f"{rel}: missing AGENT.md")
        return False

    fm = parse_frontmatter(agent_md)
    if fm is None:
        error(f"{rel}/AGENT.md: no YAML frontmatter (must start with '---')")
        return False

    for field in REQUIRED_FRONTMATTER:
        if not fm.get(field):
            error(f"{rel}/AGENT.md: missing required field '{field}'")
            ok_flag = False

    name = fm.get("name", "")
    if name and name != agent_dir.name:
        error(
            f"{rel}/AGENT.md: name '{name}' does not match directory '{agent_dir.name}'"
        )
        ok_flag = False

    desc = fm.get("description", "")
    if isinstance(desc, str) and desc.strip() in PLACEHOLDER_DESCRIPTIONS:
        error(
            f"{rel}/AGENT.md: description is a placeholder ('{desc.strip()}')"
        )
        ok_flag = False

    content = agent_md.read_text(errors="replace")
    resolve_links(content, agent_md)

    if ok_flag:
        ok_msg(rel)
    return ok_flag


def validate_script_shebangs() -> bool:
    ok_flag = True
    scripts_dir = REPO_ROOT / "scripts"
    if not scripts_dir.exists():
        return ok_flag

    for script in sorted(scripts_dir.iterdir()):
        if not script.is_file():
            continue
        if script.suffix == ".pyc":
            continue
        if script.name in (".DS_Store",):
            continue

        try:
            first_line = script.read_text(errors="replace").split("\n")[0].rstrip()
        except OSError:
            continue

        if script.suffix in (".py", ".sh", ".bash"):
            if not first_line.startswith("#!"):
                error(
                    f"{path_relative(script)}: missing shebang line (expected '#!/usr/bin/env ...')"
                )
                ok_flag = False

    return ok_flag


def main() -> int:
    print("\n--- Mechanical smoke: skills/ ---\n")
    skill_ok = True
    skill_count = 0
    for domain_dir in sorted(SKILLS_DIR.iterdir()):
        if not domain_dir.is_dir():
            continue
        for skill_dir in sorted(domain_dir.iterdir()):
            if not skill_dir.is_dir():
                continue
            if not validate_skill(skill_dir):
                skill_ok = False
            skill_count += 1

    print(f"\n  Skills checked: {skill_count}")
    if skill_ok:
        print("  Skills: all passed")

    print("\n--- Mechanical smoke: agents/ ---\n")
    agent_ok = True
    agent_count = 0
    for agent_dir in sorted(AGENTS_DIR.iterdir()):
        if not agent_dir.is_dir():
            continue
        if not validate_agent(agent_dir):
            agent_ok = False
        agent_count += 1

    print(f"\n  Agents checked: {agent_count}")
    if agent_ok:
        print("  Agents: all passed")

    print("\n--- Mechanical smoke: script shebangs ---\n")
    shebang_ok = validate_script_shebangs()
    if shebang_ok:
        print("  Scripts: all passed")

    print(f"\n=== Summary: {len(ERRORS)} error(s) ===\n")
    if ERRORS:
        for e in ERRORS:
            print(f"  FAIL: {e}")
        print(f"\n{len(ERRORS)} error(s) total.")
        return 1

    print("  All mechanical smoke checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
