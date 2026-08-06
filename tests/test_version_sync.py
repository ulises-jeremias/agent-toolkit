"""Single version source of truth across packaging surfaces (#62)."""

from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def _python_version() -> str:
    text = (REPO / "packages/agent-toolkit-cli/src/agent_toolkit/__init__.py").read_text()
    m = re.search(r'__version__\s*=\s*"([^"]+)"', text)
    assert m, "missing __version__"
    return m.group(1)


def test_version_file_matches_python():
    assert (REPO / "VERSION").read_text().strip() == _python_version()


def test_package_json_matches_python():
    pkg = json.loads((REPO / "package.json").read_text())
    assert pkg["version"] == _python_version()


def test_marketplace_metadata_matches_python():
    ver = _python_version()
    for rel in (".claude-plugin/marketplace.json", ".cursor-plugin/marketplace.json"):
        data = json.loads((REPO / rel).read_text())
        assert data.get("metadata", {}).get("version") == ver, rel


def test_cli_reports_python_version():
    from agent_toolkit import __version__

    assert __version__ == _python_version()
