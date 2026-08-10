"""Contract tests for the audit policy surface in agent_toolkit.runner.policy."""

# Author: RawNuke
# Copyright (c) 2026 RawNuke. All rights reserved.

from __future__ import annotations

import json
from pathlib import Path

import pytest

from agent_toolkit.runner.policy import (
    KNOWN_PROVIDERS,
    LLMPolicy,
    PolicyError,
    _normalize_name,
    _split_list,
    _truthy,
    merge_policies,
)


class DummyProvider:
    """Minimal provider stub with name, priority, and model attributes."""

    def __init__(self, name: str, priority: int = 100, model: str | None = None) -> None:
        self.name = name
        self._priority = priority
        self.model = model

    def get_priority(self) -> int:
        return self._priority


# ── from_env ────────────────────────────────────────────────────────────────


def test_from_env_splits_allowlist_and_denylist() -> None:
    env = {
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode, anthropic",
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_DENYLIST": "ollama, openai",
    }
    policy = LLMPolicy.from_env(env)
    assert policy.allowlist == ("opencode", "anthropic")
    assert policy.denylist == ("ollama", "openai")
    assert policy.sources == ("env",)


def test_from_env_normalizes_pinned_provider_and_model() -> None:
    env = {
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_PINNED_PROVIDER": "  OpenCode  ",
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_PINNED_MODEL": "  claude-3-5-haiku  ",
    }
    policy = LLMPolicy.from_env(env)
    assert policy.pinned_provider == "opencode"
    assert policy.pinned_model == "claude-3-5-haiku"
    assert policy.sources == ("env",)


def test_from_env_blank_pinned_model_is_none() -> None:
    env = {"DOTS_WORKSTATION_DEVCOMPANION_LLM_PINNED_MODEL": "   "}
    policy = LLMPolicy.from_env(env)
    assert policy.pinned_model is None
    assert policy.sources == ()


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("1", True),
        ("true", True),
        ("TRUE", True),
        ("yes", True),
        ("on", True),
        (" Yes ", True),
        ("0", False),
        ("false", False),
        ("no", False),
        ("off", False),
        ("", False),
        ("2", False),
    ],
)
def test_from_env_strict_truthiness(raw: str, expected: bool) -> None:
    policy = LLMPolicy.from_env({"DOTS_WORKSTATION_DEVCOMPANION_LLM_STRICT": raw})
    assert policy.strict is expected
    assert ("env" in policy.sources) is expected


def test_from_env_empty_env_has_no_sources() -> None:
    policy = LLMPolicy.from_env({})
    assert policy.allowlist is None
    assert policy.denylist == ()
    assert policy.sources == ()
    assert policy.warnings == ()


def test_from_env_warns_on_unknown_providers() -> None:
    env = {
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode, mystery-provider",
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_DENYLIST": "ghost",
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_PINNED_PROVIDER": "phantom",
    }
    policy = LLMPolicy.from_env(env)
    assert any(
        "allowlist contains unknown provider 'mystery-provider'" in w for w in policy.warnings
    )
    assert any("denylist contains unknown provider 'ghost'" in w for w in policy.warnings)
    assert any("pinned provider 'phantom' is unknown" in w for w in policy.warnings)
    assert len(policy.warnings) == 3


# ── from_file ───────────────────────────────────────────────────────────────


def test_from_file_reads_json_config(tmp_path: Path) -> None:
    cfg = tmp_path / "policy.json"
    cfg.write_text(
        json.dumps(
            {
                "allowlist": ["opencode", "ollama"],
                "denylist": ["openai"],
                "pinned_provider": "Anthropic",
                "pinned_model": " claude-3-5-haiku ",
                "strict": True,
            }
        )
    )
    policy = LLMPolicy.from_file(cfg)
    assert policy.allowlist == ("opencode", "ollama")
    assert policy.denylist == ("openai",)
    assert policy.pinned_provider == "anthropic"
    assert policy.pinned_model == "claude-3-5-haiku"
    assert policy.strict is True
    assert policy.sources == (f"file:{cfg}",)


def test_from_file_legacy_provider_and_model_keys(tmp_path: Path) -> None:
    cfg = tmp_path / "legacy.json"
    cfg.write_text(json.dumps({"provider": "  OpenAI ", "model": "gpt-4o"}))
    policy = LLMPolicy.from_file(cfg)
    assert policy.pinned_provider == "openai"
    assert policy.pinned_model == "gpt-4o"
    assert policy.sources == (f"file:{cfg}",)


def test_from_file_missing_path_returns_empty(tmp_path: Path) -> None:
    policy = LLMPolicy.from_file(tmp_path / "does-not-exist.json")
    assert policy.allowlist is None
    assert policy.denylist == ()
    assert policy.sources == ()
    assert policy.warnings == ()


def test_from_file_invalid_json_returns_warning(tmp_path: Path) -> None:
    cfg = tmp_path / "broken.json"
    cfg.write_text("{not json", encoding="utf-8")
    policy = LLMPolicy.from_file(cfg)
    assert policy.allowlist is None
    assert len(policy.warnings) == 1
    assert policy.warnings[0].startswith("failed to parse policy file")


def test_from_file_non_object_json_returns_warning(tmp_path: Path) -> None:
    cfg = tmp_path / "array.json"
    cfg.write_text("[1, 2, 3]", encoding="utf-8")
    policy = LLMPolicy.from_file(cfg)
    assert policy.allowlist is None
    assert len(policy.warnings) == 1
    assert "must contain a JSON object" in policy.warnings[0]


def test_from_file_respects_config_env_override(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    cfg = tmp_path / "custom.json"
    cfg.write_text(json.dumps({"allowlist": ["opencode"]}))
    monkeypatch.setenv("DOTS_WORKSTATION_DEVCOMPANION_LLM_CONFIG", str(cfg))
    policy = LLMPolicy.from_file()
    assert policy.allowlist == ("opencode",)
    assert policy.sources == (f"file:{cfg}",)


# ── from_job ────────────────────────────────────────────────────────────────


def test_from_job_none_and_bool_are_empty() -> None:
    assert LLMPolicy.from_job(None).allowlist is None
    assert LLMPolicy.from_job(True).sources == ()
    assert LLMPolicy.from_job(False).sources == ()


def test_from_job_non_mapping_is_empty() -> None:
    for value in ("opencode", 42, ["opencode"], 3.14):
        policy = LLMPolicy.from_job(value)
        assert policy.allowlist is None
        assert policy.sources == ()


def test_from_job_mapping_parses_like_file() -> None:
    job = {
        "allowlist": ["opencode"],
        "denylist": ["openai"],
        "provider": " Ollama ",
        "model": " llama3.2 ",
        "strict": "yes",
    }
    policy = LLMPolicy.from_job(job)
    assert policy.allowlist == ("opencode",)
    assert policy.denylist == ("openai",)
    assert policy.pinned_provider == "ollama"
    assert policy.pinned_model == "llama3.2"
    assert policy.strict is True
    assert policy.sources == ("job",)


# ── load ────────────────────────────────────────────────────────────────────


def test_load_layers_env_file_job(tmp_path: Path) -> None:
    cfg = tmp_path / "policy.json"
    cfg.write_text(json.dumps({"denylist": ["openai"]}))
    env = {"DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode, ollama"}
    policy = LLMPolicy.load(env=env, config_path=cfg, job_llm={"pinned_provider": "opencode"})
    assert policy.allowlist == ("opencode", "ollama")
    assert policy.denylist == ("openai",)
    assert policy.pinned_provider == "opencode"
    assert policy.sources == ("env", f"file:{cfg}", "job")


def test_load_without_job_merges_env_and_file(tmp_path: Path) -> None:
    cfg = tmp_path / "policy.json"
    cfg.write_text(json.dumps({"allowlist": ["opencode"]}))
    policy = LLMPolicy.load(
        env={"DOTS_WORKSTATION_DEVCOMPANION_LLM_DENYLIST": "openai"},
        config_path=cfg,
    )
    assert policy.allowlist == ("opencode",)
    assert policy.denylist == ("openai",)
    assert policy.sources == ("env", f"file:{cfg}")


def test_load_job_cannot_widen_allowlist(tmp_path: Path) -> None:
    env = {"DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode"}
    with pytest.raises(PolicyError, match="not allowed globally"):
        LLMPolicy.load(
            env=env,
            config_path=tmp_path / "missing.json",
            job_llm={"allowlist": ["opencode", "openai"]},
        )


def test_load_job_pin_outside_allowlist_raises(tmp_path: Path) -> None:
    env = {"DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode"}
    with pytest.raises(PolicyError, match="not in the global allowlist"):
        LLMPolicy.load(
            env=env,
            config_path=tmp_path / "missing.json",
            job_llm={"provider": "ollama"},
        )


def test_load_job_pin_denied_provider_raises(tmp_path: Path) -> None:
    cfg = tmp_path / "policy.json"
    cfg.write_text(json.dumps({"denylist": ["ollama"]}))
    env = {"DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode, ollama"}
    with pytest.raises(PolicyError, match="denied by policy"):
        LLMPolicy.load(env=env, config_path=cfg, job_llm={"provider": "ollama"})


def test_load_strict_can_only_escalate(tmp_path: Path) -> None:
    env = {
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode",
        "DOTS_WORKSTATION_DEVCOMPANION_LLM_STRICT": "true",
    }
    policy = LLMPolicy.load(
        env=env,
        config_path=tmp_path / "missing.json",
        job_llm={"strict": False, "denylist": ["openai"]},
    )
    assert policy.strict is True
    assert any("tried to set strict=false" in w for w in policy.warnings)


def test_load_job_can_escalate_strict(tmp_path: Path) -> None:
    env = {"DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST": "opencode"}
    policy = LLMPolicy.load(
        env=env,
        config_path=tmp_path / "missing.json",
        job_llm={"strict": "on", "denylist": ["openai"]},
    )
    assert policy.strict is True


# ── merge_policies ──────────────────────────────────────────────────────────


def test_merge_denylist_union_sorted() -> None:
    base = LLMPolicy(denylist=("ollama", "openai"))
    overlay = LLMPolicy(denylist=("anthropic", "ollama"))
    merged = merge_policies(base, overlay)
    assert merged.denylist == ("anthropic", "ollama", "openai")


def test_merge_allowlist_intersection_keeps_overlay_order() -> None:
    base = LLMPolicy(allowlist=("anthropic", "opencode", "ollama"))
    overlay = LLMPolicy(allowlist=("ollama", "anthropic"))
    merged = merge_policies(base, overlay)
    assert merged.allowlist == ("ollama", "anthropic")


def test_merge_empty_allowlist_intersection_raises() -> None:
    base = LLMPolicy(allowlist=("opencode",))
    overlay = LLMPolicy(allowlist=("ollama",))
    with pytest.raises(PolicyError, match="empty after intersecting"):
        merge_policies(base, overlay)


def test_merge_warnings_concatenated() -> None:
    base = LLMPolicy(warnings=("w1", "w2"))
    overlay = LLMPolicy(warnings=("w3",))
    merged = merge_policies(base, overlay)
    assert merged.warnings == ("w1", "w2", "w3")


def test_merge_sources_dedup_preserves_order() -> None:
    base = LLMPolicy(sources=("env", "file:a"))
    overlay = LLMPolicy(sources=("file:a", "job"))
    merged = merge_policies(base, overlay)
    assert merged.sources == ("env", "file:a", "job")


# ── filter ──────────────────────────────────────────────────────────────────


def test_filter_allowlist_ordering_preserved() -> None:
    providers = [
        DummyProvider("opencode"),
        DummyProvider("anthropic"),
        DummyProvider("ollama"),
    ]
    policy = LLMPolicy(allowlist=("anthropic", "ollama", "opencode"))
    assert [p.name for p in policy.filter(providers)] == ["anthropic", "ollama", "opencode"]


def test_filter_denylist_excluded() -> None:
    providers = [DummyProvider("opencode"), DummyProvider("ollama")]
    policy = LLMPolicy(allowlist=("opencode", "ollama"), denylist=("ollama",))
    assert [p.name for p in policy.filter(providers)] == ["opencode"]


def test_filter_pinned_provider_sets_pinned_model() -> None:
    provider = DummyProvider("opencode", model="default")
    policy = LLMPolicy(pinned_provider="opencode", pinned_model="deepseek-v4-flash")
    result = policy.filter([provider])
    assert result == [provider]
    assert provider.model == "deepseek-v4-flash"


def test_filter_pinned_provider_denied_returns_empty() -> None:
    policy = LLMPolicy(pinned_provider="opencode", denylist=("opencode",))
    assert policy.filter([DummyProvider("opencode")]) == []


def test_filter_unknown_pinned_provider_returns_empty() -> None:
    policy = LLMPolicy(pinned_provider="nonexistent")
    assert policy.filter([DummyProvider("opencode")]) == []


def test_filter_default_priority_sort() -> None:
    providers = [
        DummyProvider("opencode", priority=10),
        DummyProvider("ollama", priority=2),
        DummyProvider("anthropic", priority=1),
    ]
    policy = LLMPolicy(denylist=("openai",))
    assert [p.name for p in policy.filter(providers)] == ["anthropic", "ollama", "opencode"]


# ── to_audit ────────────────────────────────────────────────────────────────


def test_to_audit_exact_shape() -> None:
    policy = LLMPolicy(
        allowlist=("opencode", "ollama"),
        denylist=("openai",),
        pinned_provider="opencode",
        pinned_model="m1",
        strict=True,
        sources=("env", "file:x", "job"),
        warnings=("w1",),
    )
    assert policy.to_audit() == {
        "allowlist": ["opencode", "ollama"],
        "denylist": ["openai"],
        "pinned_provider": "opencode",
        "pinned_model": "m1",
        "strict": True,
        "sources": ["env", "file:x", "job"],
        "warnings": ["w1"],
    }


def test_to_audit_empty_policy_shape() -> None:
    assert LLMPolicy.empty().to_audit() == {
        "allowlist": None,
        "denylist": [],
        "pinned_provider": None,
        "pinned_model": None,
        "strict": False,
        "sources": [],
        "warnings": [],
    }


# ── helper functions ────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (True, True),
        (False, False),
        (None, False),
        ("1", True),
        ("true", True),
        ("TRUE", True),
        ("yes", True),
        ("on", True),
        (" Yes ", True),
        ("0", False),
        ("false", False),
        ("no", False),
        ("off", False),
        ("", False),
        ("2", False),
        ("maybe", False),
        (1, True),
        (0, False),
    ],
)
def test_truthy_edge_cases(value: object, expected: bool) -> None:
    assert _truthy(value) is expected


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (None, ()),
        ("", ()),
        ("opencode, ollama", ("opencode", "ollama")),
        (" OpenCode ,ANTHROPIC ", ("opencode", "anthropic")),
        (["OpenCode", " anthropic "], ("opencode", "anthropic")),
        (("ollama", "openai"), ("ollama", "openai")),
        (42, ()),
        (b"opencode", ()),
    ],
)
def test_split_list_cases(value: object, expected: tuple[str, ...]) -> None:
    assert _split_list(value) == expected


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (None, None),
        ("", None),
        ("   ", None),
        (" OpenCode ", "opencode"),
        ("ANTHROPIC", "anthropic"),
    ],
)
def test_normalize_name_cases(value: object, expected: str | None) -> None:
    assert _normalize_name(value) == expected


def test_known_providers_constant() -> None:
    assert KNOWN_PROVIDERS == ("opencode", "ollama", "anthropic", "openai")
