"""Security tests: secrets must never appear in generated artifacts."""
from pathlib import Path
import tempfile
import re
import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter
from agent_toolkit.compiler.targets.cursor import CursorAdapter
from agent_toolkit.compiler.targets.opencode import OpenCodeAdapter

REPO_ROOT = Path(__file__).parent.parent.parent

SECRET_PATTERNS = [
    r"ghp_[A-Za-z0-9]{36}",      # GitHub tokens
    r"sk-[A-Za-z0-9]{20,}",      # OpenAI keys
    r"sk-ant-[A-Za-z0-9]",       # Anthropic keys
    r"xoxb-[A-Za-z0-9-]+",       # Slack bot tokens
    r"AKIA[0-9A-Z]{16}",          # AWS keys
]


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.mark.parametrize("adapter_cls", [
    ClaudeCodeAdapter, CursorAdapter, OpenCodeAdapter
])
def test_no_secrets_in_artifacts(graph, tmp_path, adapter_cls):
    """Generated artifacts must not contain any secret values."""
    product = graph.products["agent-toolkit-core"]
    adapter = adapter_cls(tmp_path / "plugins", REPO_ROOT)
    adapter.compile(graph, product)

    for f in (tmp_path / "plugins").rglob("*"):
        if f.is_file():
            try:
                text = f.read_text(errors="replace")
            except Exception:
                continue
            for pattern in SECRET_PATTERNS:
                match = re.search(pattern, text)
                if match:
                    pytest.fail(f"Secret pattern '{pattern}' in {f}: {match.group()[:20]}...")


PRIVATE_HOSTNAME_NEEDLES = (
    ".local",
    "colibri",
    "skypiea",
    "192.168.",
    "10.",
)


def _assert_no_private_hostnames(path: Path, text: str) -> None:
    lower = text.lower()
    for needle in PRIVATE_HOSTNAME_NEEDLES:
        # Avoid false positives on path segments like ".local/share" instructions
        # that are not hostnames — only flag URL-like or provider host usage.
        if needle in (".local", "10."):
            if re.search(rf"https?://[^\s\"']*{re.escape(needle)}", text, re.I):
                pytest.fail(f"Private hostname pattern {needle!r} in {path}")
            if needle == "10." and re.search(r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", text):
                pytest.fail(f"Private IPv4 10.x address in {path}")
            continue
        if needle in lower:
            pytest.fail(f"Private hostname pattern {needle!r} in {path}")


def test_private_hostnames_not_in_opencode_json(graph, tmp_path):
    """Compiled opencode.json must never contain private LAN hostnames."""
    product = graph.products["agent-toolkit-core"]
    adapter = OpenCodeAdapter(tmp_path / "plugins", REPO_ROOT)
    adapter.compile(graph, product)

    opencode_json = tmp_path / "plugins" / "agent-toolkit-core" / "opencode.json"
    if opencode_json.exists():
        _assert_no_private_hostnames(opencode_json, opencode_json.read_text())


def test_private_hostnames_not_in_profiles():
    """Installer profiles must not ship private LAN hostnames or org-specific hosts."""
    profiles = REPO_ROOT / "profiles"
    assert profiles.is_dir()
    for path in profiles.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".json", ".yaml", ".yml", ".md", ".mdc", ".toml"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        _assert_no_private_hostnames(path, text)
