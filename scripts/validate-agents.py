#!/usr/bin/env python3
"""Validate AGENT.md frontmatter across all agents."""

import sys
import re
from pathlib import Path

try:
    import yaml
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml", "--quiet"])
    import yaml

REPO_ROOT = Path(__file__).parent.parent
AGENTS_DIR = REPO_ROOT / "agents"
REQUIRED = ["name", "description"]

ERRORS: list[str] = []

def error(msg: str) -> None:
    ERRORS.append(msg)
    print(f"  ✗ {msg}")

def parse_frontmatter(path: Path) -> dict | None:
    content = path.read_text(errors="replace")
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return None
    try:
        return yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        return None

def main() -> int:
    print("\n🔍 Validating AGENT.md frontmatter...\n")
    count = 0

    for agent_dir in sorted(AGENTS_DIR.iterdir()):
        if not agent_dir.is_dir():
            continue
        agent_md = agent_dir / "AGENT.md"
        if not agent_md.exists():
            error(f"{agent_dir.name}: missing AGENT.md")
            continue
        fm = parse_frontmatter(agent_md)
        if fm is None:
            error(f"{agent_dir.name}/AGENT.md: no YAML frontmatter")
            continue
        for field in REQUIRED:
            if not fm.get(field):
                error(f"{agent_dir.name}/AGENT.md: missing '{field}'")
        count += 1

    print(f"\nAgents validated: {count}")
    if ERRORS:
        print(f"\n❌ {len(ERRORS)} error(s)")
        return 1
    print("\n✅ All AGENT.md files are valid!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
