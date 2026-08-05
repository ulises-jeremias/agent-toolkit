"""Security tests: path traversal prevention in compiler."""
from pathlib import Path
import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.model import CompilationResult, Skill
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


def test_references_symlink_outside_root_fails_compile(tmp_path):
    """A references/ symlink pointing outside the skill tree must fail closed."""
    outside = tmp_path / "outside"
    outside.mkdir()
    secret = outside / "secret.txt"
    secret.write_text("outside secret", encoding="utf-8")

    skill_dir = tmp_path / "skills" / "evil"
    skill_dir.mkdir(parents=True)
    refs = skill_dir / "references"
    refs.mkdir()
    (skill_dir / "SKILL.md").write_text(
        "---\nname: evil\ndescription: test\n---\n",
        encoding="utf-8",
    )
    (refs / "escape.md").symlink_to(secret)

    skill = Skill(
        id="test/evil",
        name="evil",
        domain="test",
        description="test",
        source_path=skill_dir / "SKILL.md",
    )

    adapter = ClaudeCodeAdapter(tmp_path / "plugins", tmp_path)
    out_dir = tmp_path / "plugins" / "test-product"
    result = CompilationResult(target=adapter.target_id, product="test-product")
    adapter._emit_skill(skill, out_dir, result)

    assert not result.is_valid
    assert any("escapes containment" in err for err in result.errors)

    leaked = out_dir / "references" / "escape.md"
    assert not leaked.exists() or leaked.read_text(encoding="utf-8") != "outside secret"
