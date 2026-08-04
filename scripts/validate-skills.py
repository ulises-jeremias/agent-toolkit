#!/usr/bin/env python3
"""Validate SKILL.md frontmatter across all skills per Agent Skills spec."""

import sys
import re
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Installing PyYAML...", file=sys.stderr)
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml", "--quiet"])
    import yaml

REPO_ROOT = Path(__file__).parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
PLUGINS_DIR = REPO_ROOT / "plugins"

REQUIRED_FRONTMATTER = ["name", "description"]
ERRORS: list[str] = []
WARNINGS: list[str] = []

def error(msg: str) -> None:
    ERRORS.append(msg)
    print(f"  ✗ {msg}")

def warn(msg: str) -> None:
    WARNINGS.append(msg)
    print(f"  ⚠ {msg}")

def ok(msg: str) -> None:
    print(f"  ✓ {msg}")

def parse_frontmatter(path: Path) -> dict | None:
    content = path.read_text(errors="replace")
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return None
    try:
        return yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError as e:
        error(f"{path.relative_to(REPO_ROOT)}: invalid YAML frontmatter: {e}")
        return None

def validate_skill(skill_dir: Path) -> bool:
    skill_md = skill_dir / "SKILL.md"
    rel = skill_dir.relative_to(REPO_ROOT)

    if not skill_md.exists():
        error(f"{rel}: missing SKILL.md")
        return False

    fm = parse_frontmatter(skill_md)
    if fm is None:
        error(f"{rel}/SKILL.md: no YAML frontmatter found (must start with ---)")
        return False

    ok_flag = True
    for field in REQUIRED_FRONTMATTER:
        if not fm.get(field):
            error(f"{rel}/SKILL.md: missing required frontmatter field '{field}'")
            ok_flag = False

    # name must match directory name
    if fm.get("name") and fm["name"] != skill_dir.name:
        warn(f"{rel}/SKILL.md: name '{fm['name']}' does not match directory '{skill_dir.name}'")

    # Check no skill.json (deprecated)
    if (skill_dir / "skill.json").exists():
        warn(f"{rel}: skill.json found — not needed by Agent Skills spec, can be removed")

    return ok_flag

def main() -> int:
    print("\n🔍 Validating SKILL.md frontmatter (Agent Skills spec)...\n")

    skill_count = 0
    print("── skills/ ──")
    for domain_dir in sorted(SKILLS_DIR.iterdir()):
        if not domain_dir.is_dir():
            continue
        for skill_dir in sorted(domain_dir.iterdir()):
            if not skill_dir.is_dir():
                continue
            validate_skill(skill_dir)
            skill_count += 1

    print(f"\n── plugins/ (bundled copies) ──")
    for plugin_dir in sorted(PLUGINS_DIR.iterdir()):
        if not plugin_dir.is_dir():
            continue
        plugin_skills = plugin_dir / "skills"
        if plugin_skills.exists():
            for skill_dir in sorted(plugin_skills.iterdir()):
                if skill_dir.is_dir():
                    validate_skill(skill_dir)

    print(f"\n── Summary ──")
    print(f"  Skills validated: {skill_count}")

    if ERRORS:
        print(f"\n❌ {len(ERRORS)} error(s) found")
        return 1
    
    if WARNINGS:
        print(f"\n⚠ All valid with {len(WARNINGS)} warning(s)")
    else:
        print("\n✅ All SKILL.md files are valid!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
