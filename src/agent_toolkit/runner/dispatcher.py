"""LLM dispatcher for the dev-companion runner.

Selects the best available LLM provider, constrained by an :class:`LLMPolicy`
that captures client-driven privacy/billing requirements (allowlist, denylist,
pinned provider/model, fail-closed ``strict`` mode).

When no policy is supplied, behaviour is backwards-compatible: providers are
ordered by their hard-coded ``get_priority()`` and the first available one is
selected.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Optional

import sys
from pathlib import Path as _Path

sys.path.insert(0, str(_Path(__file__).parent))

from policy import LLMPolicy
from providers import (
    AnthropicProvider,
    LLMProvider,
    LLMResponse,
    OllamaProvider,
    OpenAIProvider,
    OpenCodeProvider,
)

logger = logging.getLogger(__name__)


class LLMDispatcher:
    """Pick a provider that satisfies the active :class:`LLMPolicy`.

    The dispatcher never silently falls back to a denied provider: if the
    policy filters every provider out and ``strict`` is set, the caller gets
    an explicit ``policy_no_provider_available`` error. Non-strict mode keeps
    the previous behaviour (returns ``None``; caller can use a skeleton plan).
    """

    POLICY_VIOLATION = "policy_no_provider_available"

    def __init__(self, policy: LLMPolicy | None = None) -> None:
        self._policy: LLMPolicy = policy or LLMPolicy.empty()
        self._providers: list[LLMProvider] = []
        self._candidates: list[LLMProvider] = []
        self._selected: Optional[LLMProvider] = None
        self._initialize_providers()

    @property
    def policy(self) -> LLMPolicy:
        return self._policy

    def _initialize_providers(self) -> None:
        all_providers: list[LLMProvider] = [
            OpenCodeProvider(),
            OllamaProvider(),
            AnthropicProvider(),
            OpenAIProvider(),
        ]
        # Stable hard-coded ordering for the unfiltered case.
        all_providers.sort(key=lambda p: p.get_priority())
        self._providers = all_providers
        self._candidates = self._policy.filter(all_providers)

    def list_candidates(self) -> list[dict]:
        """Detailed status for every candidate after policy filtering, without
        executing the model. Used by the ``llm-status`` diagnostic."""
        return [
            {
                "name": p.name,
                "model": p.get_model_name(),
                "available": p.is_available(),
                "is_local": getattr(p, "is_local", False),
                "is_free": getattr(p, "is_free", False),
                "priority": p.get_priority(),
            }
            for p in self._candidates
        ]

    def list_all_providers(self) -> list[dict]:
        """Status for every known provider, regardless of policy. Useful for
        operators who need to see what was filtered out and why."""
        candidate_names = {p.name for p in self._candidates}
        return [
            {
                "name": p.name,
                "model": p.get_model_name(),
                "available": p.is_available(),
                "is_local": getattr(p, "is_local", False),
                "is_free": getattr(p, "is_free", False),
                "priority": p.get_priority(),
                "in_policy": p.name in candidate_names,
            }
            for p in self._providers
        ]

    def get_available_provider(self) -> Optional[LLMProvider]:
        if not self._candidates:
            logger.warning(
                "LLM policy filtered out every provider (allowlist=%s, deny=%s, pinned=%s)",
                list(self._policy.allowlist) if self._policy.allowlist else None,
                list(self._policy.denylist),
                self._policy.pinned_provider,
            )
            return None
        for provider in self._candidates:
            if provider.is_available():
                logger.info(
                    "Selected provider: %s (model: %s)",
                    provider.name,
                    provider.get_model_name(),
                )
                self._selected = provider
                return provider
        logger.warning(
            "No allowed LLM provider is available (strict=%s)",
            self._policy.strict,
        )
        return None

    def get_selected(self) -> Optional[LLMProvider]:
        return self._selected

    def list_providers(self) -> list[dict]:
        # Backwards-compatible alias used by ``dots_ai_devcompanion_runner``.
        return self.list_candidates() or self.list_all_providers()

    def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        repo_path: Optional[Path] = None,
        timeout_sec: int = 300,
    ) -> tuple[Optional[LLMResponse], Optional[str]]:
        provider = self.get_selected()
        if not provider:
            if self._policy.strict:
                return None, self.POLICY_VIOLATION
            return None, "no_provider"

        try:
            response = provider.generate(
                prompt=prompt,
                system_prompt=system_prompt,
                repo_path=repo_path,
                timeout_sec=timeout_sec,
            )
            return response, None
        except Exception as exc:  # pragma: no cover - safety net
            logger.error("Provider %s failed: %s", provider.name, exc)
            return None, str(exc)


def create_dispatcher(policy: LLMPolicy | None = None) -> LLMDispatcher:
    debug = os.environ.get("DOTS_WORKSTATION_LLM_DEBUG", "").lower() in ("1", "true", "yes", "on")
    if debug:
        logging.basicConfig(level=logging.DEBUG)
    return LLMDispatcher(policy=policy)
