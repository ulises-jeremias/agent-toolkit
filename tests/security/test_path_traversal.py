"""Security tests: path traversal prevention in compiler."""
from pathlib import Path
import tempfile
import pytest


from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


def test_output_cannot_escape_output_root(graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    adapter = ClaudeCodeAdapter(tmp_path / "plugins", REPO_ROOT)
    result = adapter.compile(graph, product)

    for artifact in result.artifacts:
        try:
            artifact.relative_to(tmp_path / "plugins")
        except ValueError:
            pytest.fail(f"Artifact escaped output_root: {artifact}")


def test_no_symlink_escape(graph, tmp_path):
    product = graph.products["agent-toolkit-core"]
    adapter = ClaudeCodeAdapter(tmp_path / "plugins", REPO_ROOT)
    adapter.compile(graph, product)

    for f in (tmp_path / "plugins").rglob("*"):
        if f.is_symlink():
            target = f.resolve()
            try:
                target.relative_to(tmp_path)
            except ValueError:
                pytest.fail(f"Symlink escape: {f} -> {target}")
