"""Contract tests for the LLM provider abstraction and the LLM dispatcher.

Author: RawNuke
Copyright (c) 2026 RawNuke. All rights reserved.

Covers LLMResponse fields, the LLMProvider ABC defaults, the concrete
providers (anthropic, ollama, openai, opencode) and the policy-based
candidate selection in LLMDispatcher. No live endpoint is ever called;
availability checks run on monkeypatched subprocess and environ.
"""

from __future__ import annotations

import subprocess
from types import SimpleNamespace
from typing import Any

import pytest

from agent_toolkit.runner.dispatcher import LLMDispatcher
from agent_toolkit.runner.policy import LLMPolicy
from agent_toolkit.runner.providers import (
    AnthropicProvider,
    LLMProvider,
    LLMResponse,
    OllamaProvider,
    OpenAIProvider,
    OpenCodeProvider,
)


class _StubProvider(LLMProvider):
    """Minimal concrete provider for ABC behaviour checks."""

    name = "stub"

    def is_available(self) -> bool:
        return True

    def generate(self, prompt: str, **kwargs: Any) -> LLMResponse:
        return LLMResponse(content="ok", model="stub", provider="stub")


def _stub_run(returncode: int, stdout: str = "") -> Any:
    return SimpleNamespace(returncode=returncode, stdout=stdout)


def _stub_available(monkeypatch: pytest.MonkeyPatch, run: Any) -> Any:
    monkeypatch.setattr(subprocess, "run", lambda *a, **kw: run)
    return run


class TestLLMResponse:
    def test_defaults(self) -> None:
        resp = LLMResponse(content="hi", model="m", provider="p")
        assert resp.content == "hi"
        assert resp.model == "m"
        assert resp.provider == "p"
        assert resp.tokens_used is None
        assert resp.duration_sec is None

    def test_optional_fields_set(self) -> None:
        resp = LLMResponse(content="hi", model="m", provider="p", tokens_used=12, duration_sec=1.5)
        assert resp.tokens_used == 12
        assert resp.duration_sec == 1.5


class TestLLMProviderABC:
    def test_abstract_methods(self) -> None:
        assert LLMProvider.__abstractmethods__ == frozenset({"is_available", "generate"})

    def test_default_behaviour(self) -> None:
        stub = _StubProvider()
        assert stub.get_priority() == 100
        assert stub.supports_directory_context() is False
        assert stub.get_model_name() == "unknown"

    def test_default_class_attributes(self) -> None:
        assert LLMProvider.is_local is False
        assert LLMProvider.is_free is False


class TestAnthropicProvider:
    def test_metadata(self) -> None:
        p = AnthropicProvider()
        assert p.name == "anthropic"
        assert p.is_local is False
        assert p.is_free is False
        assert p.get_priority() == 10
        assert p.supports_directory_context() is False
        assert p.get_model_name() == "claude-3-5-haiku-20241022"

    def test_is_available_with_key(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
        assert AnthropicProvider().is_available() is True

    def test_is_available_without_key(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        assert AnthropicProvider().is_available() is False


class TestOllamaProvider:
    def test_metadata(self) -> None:
        p = OllamaProvider()
        assert p.name == "ollama"
        assert p.is_local is True
        assert p.is_free is True
        assert p.get_priority() == 2
        assert p.supports_directory_context() is False
        assert p.get_model_name() == "llama3.2"

    def test_is_available_model_present(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(0, stdout="llama3.2  other-model\n"))
        assert OllamaProvider().is_available() is True

    def test_is_available_model_missing(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(0, stdout="mistral\n"))
        assert OllamaProvider().is_available() is False

    def test_is_available_nonzero_returncode(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(1, stdout="llama3.2\n"))
        assert OllamaProvider().is_available() is False

    def test_is_available_missing_binary(self, monkeypatch: pytest.MonkeyPatch) -> None:
        def raise_fnf(*args: Any, **kwargs: Any) -> Any:
            raise FileNotFoundError

        monkeypatch.setattr(subprocess, "run", raise_fnf)
        assert OllamaProvider().is_available() is False

    def test_is_available_timeout(self, monkeypatch: pytest.MonkeyPatch) -> None:
        def raise_timeout(*args: Any, **kwargs: Any) -> Any:
            raise subprocess.TimeoutExpired(cmd=["ollama", "list"], timeout=5)

        monkeypatch.setattr(subprocess, "run", raise_timeout)
        assert OllamaProvider().is_available() is False


class TestOpenAIProvider:
    def test_metadata(self) -> None:
        p = OpenAIProvider()
        assert p.name == "openai"
        assert p.is_local is False
        assert p.is_free is False
        assert p.get_priority() == 20
        assert p.supports_directory_context() is False
        assert p.get_model_name() == "gpt-4o-mini"

    def test_is_available_with_key(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("OPENAI_API_KEY", "test-key")
        assert OpenAIProvider().is_available() is True

    def test_is_available_without_key(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        assert OpenAIProvider().is_available() is False


class TestOpenCodeProvider:
    def test_metadata(self) -> None:
        p = OpenCodeProvider()
        assert p.name == "opencode"
        assert p.is_local is True
        assert p.is_free is True
        assert p.get_priority() == 1
        assert p.supports_directory_context() is True
        assert p.get_model_name() == "opencode/big-pickle"

    def test_is_available_returncode_zero(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(0))
        assert OpenCodeProvider().is_available() is True

    def test_is_available_returncode_nonzero(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(1))
        assert OpenCodeProvider().is_available() is False

    def test_is_available_missing_binary(self, monkeypatch: pytest.MonkeyPatch) -> None:
        def raise_fnf(*args: Any, **kwargs: Any) -> Any:
            raise FileNotFoundError

        monkeypatch.setattr(subprocess, "run", raise_fnf)
        assert OpenCodeProvider().is_available() is False

    def test_is_available_timeout(self, monkeypatch: pytest.MonkeyPatch) -> None:
        def raise_timeout(*args: Any, **kwargs: Any) -> Any:
            raise subprocess.TimeoutExpired(cmd=["opencode", "--version"], timeout=5)

        monkeypatch.setattr(subprocess, "run", raise_timeout)
        assert OpenCodeProvider().is_available() is False


class TestLLMDispatcher:
    def test_policy_violation_constant(self) -> None:
        assert LLMDispatcher.POLICY_VIOLATION == "policy_no_provider_available"

    def test_policy_attribute_defaults_to_empty(self) -> None:
        """Dispatcher's policy class is distinct; compare the audit shape."""
        dispatcher = LLMDispatcher()
        assert dispatcher.policy.to_audit() == LLMPolicy.empty().to_audit()

    def test_allowlist_order_wins_over_priority(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(0))
        policy = LLMPolicy(allowlist=("openai", "opencode"))
        dispatcher = LLMDispatcher(policy=policy)
        names = [c.name for c in dispatcher._candidates]
        assert names == ["openai", "opencode"]

    def test_pinned_provider_returns_single_candidate(self) -> None:
        policy = LLMPolicy(pinned_provider="ollama")
        dispatcher = LLMDispatcher(policy=policy)
        assert [c.name for c in dispatcher._candidates] == ["ollama"]

    def test_denylist_excludes_provider(self) -> None:
        policy = LLMPolicy(denylist=("openai",))
        dispatcher = LLMDispatcher(policy=policy)
        assert all(c.name != "openai" for c in dispatcher._candidates)

    def test_get_available_provider_no_candidates_returns_none(self) -> None:
        policy = LLMPolicy(denylist=("opencode", "ollama", "anthropic", "openai"))
        dispatcher = LLMDispatcher(policy=policy)
        assert dispatcher._candidates == []
        assert dispatcher.get_available_provider() is None

    def test_get_available_provider_none_available(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(1))
        policy = LLMPolicy(denylist=("openai", "anthropic"))
        dispatcher = LLMDispatcher(policy=policy)
        assert dispatcher.get_available_provider() is None

    def test_get_available_provider_selects_first_available(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _stub_available(monkeypatch, _stub_run(0))
        dispatcher = LLMDispatcher()
        provider = dispatcher.get_available_provider()
        assert provider is not None
        assert provider.name == "opencode"
        assert dispatcher.get_selected() is provider

    def test_list_candidates_shape(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(0, stdout="llama3.2\n"))
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        dispatcher = LLMDispatcher()
        candidates = dispatcher.list_candidates()
        assert [c["name"] for c in candidates] == ["opencode", "ollama", "anthropic", "openai"]
        assert [c["available"] for c in candidates] == [True, True, False, False]
        for c in candidates:
            assert set(c.keys()) == {
                "name",
                "model",
                "available",
                "is_local",
                "is_free",
                "priority",
            }
            assert c["is_local"] is (c["name"] in ("opencode", "ollama"))

    def test_list_all_providers_shape(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _stub_available(monkeypatch, _stub_run(0, stdout="llama3.2\n"))
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        dispatcher = LLMDispatcher()
        providers = dispatcher.list_all_providers()
        assert [p["name"] for p in providers] == ["opencode", "ollama", "anthropic", "openai"]
        assert [p["available"] for p in providers] == [True, True, False, False]
        for p in providers:
            assert set(p.keys()) == {
                "name",
                "model",
                "available",
                "is_local",
                "is_free",
                "priority",
                "in_policy",
            }
        assert all(p["in_policy"] is True for p in providers)


def test_never_touches_real_subprocess_or_live_endpoint(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Guard: provider availability must not escape to a real CLI."""
    calls: list[list[str]] = []

    def fake_run(cmd: list[str], *args: Any, **kwargs: Any) -> Any:
        calls.append(cmd)
        return _stub_run(0)

    monkeypatch.setattr(subprocess, "run", fake_run)
    for provider in (OllamaProvider(), OpenCodeProvider()):
        provider.is_available()
    assert calls == [["ollama", "list"], ["opencode", "--version"]]
