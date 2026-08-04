"""LLM execution policy for the agent-toolkit dev-companion runner.

Defines which LLM providers are allowed to run, in what order, and whether
the runner is required to fail closed when no allowed provider is available
(for client engagements that mandate a single billing/data identity).

Policy sources, in order of precedence — each layer can only RESTRICT the
prior one, never widen it:

1. Global environment variables (machine baseline / engagement env file).
2. Optional JSON config file at ``~/.config/agent-toolkit/devcompanion-llm.json``
   (path overridable with ``DOTS_WORKSTATION_DEVCOMPANION_LLM_CONFIG``).
3. Per-job ``llm`` object inside the ``.job`` JSON.

A job may further restrict (subset of ``allowlist``, additional ``denylist``
entries, ``strict: true``) but cannot expand the global allowlist or relax
strict mode that was set globally.
"""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping

logger = logging.getLogger(__name__)

KNOWN_PROVIDERS: tuple[str, ...] = ("opencode", "ollama", "anthropic", "openai")
DEFAULT_CONFIG_PATH = Path.home() / ".config" / "agent-toolkit" / "devcompanion-llm.json"


class PolicyError(ValueError):
    """Raised when policy values are inconsistent (for example a job tries to widen
    the globally allowed set, or a pinned provider is denied)."""


def _truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in ("1", "true", "yes", "on")


def _split_list(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, str):
        items: list[str] = [s.strip() for s in value.split(",")]
    elif isinstance(value, Iterable) and not isinstance(value, (bytes, bytearray)):
        items = [str(s).strip() for s in value]
    else:
        return ()
    return tuple(item.lower() for item in items if item)


def _normalize_name(name: Any) -> str | None:
    if name is None:
        return None
    text = str(name).strip().lower()
    return text or None


@dataclass(frozen=True)
class LLMPolicy:
    """Effective execution policy for the LLM dispatcher.

    ``allowlist`` preserves order: when set, the dispatcher keeps providers in
    that order rather than the implementation's hard-coded priority. This lets
    operators express "prefer Anthropic first, then OpenAI" explicitly.

    ``sources`` is for audit only; it lists which layers contributed to the
    effective policy (``env``, ``file``, ``job``).
    """

    allowlist: tuple[str, ...] | None = None
    denylist: tuple[str, ...] = ()
    pinned_provider: str | None = None
    pinned_model: str | None = None
    strict: bool = False
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = field(default_factory=tuple)

    # ── loaders ────────────────────────────────────────────────────────────
    @classmethod
    def empty(cls) -> "LLMPolicy":
        return cls()

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> "LLMPolicy":
        env = os.environ if env is None else env
        allow = _split_list(env.get("DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST"))
        deny = _split_list(env.get("DOTS_WORKSTATION_DEVCOMPANION_LLM_DENYLIST"))
        pinned = _normalize_name(env.get("DOTS_WORKSTATION_DEVCOMPANION_LLM_PINNED_PROVIDER"))
        pinned_model_raw = env.get("DOTS_WORKSTATION_DEVCOMPANION_LLM_PINNED_MODEL")
        pinned_model = (
            pinned_model_raw.strip() if isinstance(pinned_model_raw, str) and pinned_model_raw.strip() else None
        )
        strict = _truthy(env.get("DOTS_WORKSTATION_DEVCOMPANION_LLM_STRICT"))

        warnings = list(_unknown_warnings("env", allow, deny, pinned))
        sources = ("env",) if (allow or deny or pinned or pinned_model or strict) else ()
        return cls(
            allowlist=allow or None,
            denylist=deny,
            pinned_provider=pinned,
            pinned_model=pinned_model,
            strict=strict,
            sources=sources,
            warnings=tuple(warnings),
        )

    @classmethod
    def from_file(cls, path: Path | str | None = None) -> "LLMPolicy":
        env_override = os.environ.get("DOTS_WORKSTATION_DEVCOMPANION_LLM_CONFIG")
        if path is None:
            path = Path(env_override) if env_override else DEFAULT_CONFIG_PATH
        path = Path(path).expanduser()
        if not path.is_file():
            return cls.empty()

        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            return cls(
                warnings=(f"failed to parse policy file {path}: {exc}",),
            )

        if not isinstance(data, Mapping):
            return cls(
                warnings=(f"policy file {path} must contain a JSON object",),
            )

        allow = _split_list(data.get("allowlist"))
        deny = _split_list(data.get("denylist"))
        pinned = _normalize_name(data.get("pinned_provider") or data.get("provider"))
        pinned_model = data.get("pinned_model") or data.get("model")
        if isinstance(pinned_model, str):
            pinned_model = pinned_model.strip() or None
        else:
            pinned_model = None
        strict = _truthy(data.get("strict"))
        warnings = list(_unknown_warnings(f"file {path}", allow, deny, pinned))
        sources = (f"file:{path}",) if (allow or deny or pinned or pinned_model or strict) else ()
        return cls(
            allowlist=allow or None,
            denylist=deny,
            pinned_provider=pinned,
            pinned_model=pinned_model,
            strict=strict,
            sources=sources,
            warnings=tuple(warnings),
        )

    @classmethod
    def from_job(cls, job_llm: Any) -> "LLMPolicy":
        if job_llm is None or isinstance(job_llm, bool):
            return cls.empty()
        if not isinstance(job_llm, Mapping):
            return cls.empty()

        allow = _split_list(job_llm.get("allowlist"))
        deny = _split_list(job_llm.get("denylist"))
        pinned = _normalize_name(job_llm.get("provider") or job_llm.get("pinned_provider"))
        pinned_model = job_llm.get("model") or job_llm.get("pinned_model")
        if isinstance(pinned_model, str):
            pinned_model = pinned_model.strip() or None
        else:
            pinned_model = None
        strict = _truthy(job_llm.get("strict"))
        warnings = list(_unknown_warnings("job", allow, deny, pinned))
        sources = ("job",) if (allow or deny or pinned or pinned_model or strict) else ()
        return cls(
            allowlist=allow or None,
            denylist=deny,
            pinned_provider=pinned,
            pinned_model=pinned_model,
            strict=strict,
            sources=sources,
            warnings=tuple(warnings),
        )

    @classmethod
    def load(
        cls,
        *,
        env: Mapping[str, str] | None = None,
        config_path: Path | str | None = None,
        job_llm: Any | None = None,
    ) -> "LLMPolicy":
        """Compose ``env`` → ``file`` → ``job`` and validate that later layers only
        restrict (never widen) earlier ones. Raises :class:`PolicyError` when a job
        tries to escape the global allowlist."""
        base = merge_policies(cls.from_env(env), cls.from_file(config_path))
        if job_llm is None:
            return base
        job = cls.from_job(job_llm)
        return merge_policies(base, job, _validate_restriction=True)

    # ── filtering ──────────────────────────────────────────────────────────
    def filter(self, providers: Iterable[Any]) -> list[Any]:
        """Return providers permitted by the policy, ordered by preference.

        Mutates the ``model`` attribute on a pinned provider when ``pinned_model``
        is set, so the caller can use the pinned model without changing the
        provider classes.
        """
        by_name: dict[str, Any] = {}
        for p in providers:
            name = _provider_name(p)
            if name:
                by_name[name] = p

        if self.pinned_provider:
            if self.pinned_provider in self.denylist:
                return []
            provider = by_name.get(self.pinned_provider)
            if provider is None:
                return []
            if self.pinned_model and hasattr(provider, "model"):
                try:
                    setattr(provider, "model", self.pinned_model)
                except Exception:
                    logger.debug("Could not set pinned model on provider %s", self.pinned_provider)
            return [provider]

        denied = set(self.denylist)
        if self.allowlist:
            ordered: list[Any] = []
            for name in self.allowlist:
                if name in denied:
                    continue
                provider = by_name.get(name)
                if provider is not None:
                    ordered.append(provider)
            return ordered

        sorted_providers = sorted(by_name.values(), key=lambda p: getattr(p, "get_priority", lambda: 100)())
        return [p for p in sorted_providers if _provider_name(p) not in denied]

    # ── audit ──────────────────────────────────────────────────────────────
    def to_audit(self) -> dict[str, Any]:
        return {
            "allowlist": list(self.allowlist) if self.allowlist else None,
            "denylist": list(self.denylist),
            "pinned_provider": self.pinned_provider,
            "pinned_model": self.pinned_model,
            "strict": self.strict,
            "sources": list(self.sources),
            "warnings": list(self.warnings),
        }


def _provider_name(provider: Any) -> str:
    return str(getattr(provider, "name", "")).strip().lower()


def _unknown_warnings(
    layer: str,
    allow: tuple[str, ...],
    deny: tuple[str, ...],
    pinned: str | None,
) -> Iterable[str]:
    for name in allow:
        if name not in KNOWN_PROVIDERS:
            yield f"{layer}: allowlist contains unknown provider '{name}'"
    for name in deny:
        if name not in KNOWN_PROVIDERS:
            yield f"{layer}: denylist contains unknown provider '{name}'"
    if pinned and pinned not in KNOWN_PROVIDERS:
        yield f"{layer}: pinned provider '{pinned}' is unknown"


def merge_policies(
    base: LLMPolicy,
    overlay: LLMPolicy,
    *,
    _validate_restriction: bool = False,
) -> LLMPolicy:
    """Merge ``overlay`` on top of ``base``.

    When ``_validate_restriction`` is true (job over global), ``overlay`` may only
    restrict ``base``. Attempting to widen raises :class:`PolicyError`.
    """
    # Allowlist
    if overlay.allowlist is None:
        merged_allow = base.allowlist
    elif base.allowlist is None:
        merged_allow = overlay.allowlist
    else:
        if _validate_restriction:
            extras = [name for name in overlay.allowlist if name not in base.allowlist]
            if extras:
                raise PolicyError(
                    "job allowlist tries to add provider(s) not allowed globally: "
                    + ", ".join(extras)
                )
        # Keep overlay order, but only entries also in base.
        merged_allow = tuple(name for name in overlay.allowlist if name in base.allowlist)
        if not merged_allow:
            raise PolicyError(
                "job allowlist is empty after intersecting with global allowlist"
            )

    # Denylist (always additive)
    merged_deny = tuple(sorted(set(base.denylist) | set(overlay.denylist)))

    # Pinned provider/model
    merged_pin_provider = overlay.pinned_provider or base.pinned_provider
    merged_pin_model = overlay.pinned_model or base.pinned_model

    if _validate_restriction and overlay.pinned_provider:
        if base.allowlist and overlay.pinned_provider not in base.allowlist:
            raise PolicyError(
                f"job pins provider '{overlay.pinned_provider}' but it is not in the global allowlist"
            )
        if overlay.pinned_provider in merged_deny:
            raise PolicyError(
                f"job pins provider '{overlay.pinned_provider}' but it is denied by policy"
            )

    # Strict can only escalate (False -> True). A job cannot lower a globally-strict policy.
    merged_strict = base.strict or overlay.strict
    if _validate_restriction and base.strict and overlay.strict is False and "job" in overlay.sources:
        # Job explicitly set strict=false but base is strict: warn, keep True.
        warnings = list(base.warnings) + list(overlay.warnings) + [
            "job tried to set strict=false while global policy is strict; keeping strict=true",
        ]
    else:
        warnings = list(base.warnings) + list(overlay.warnings)

    sources = tuple(dict.fromkeys(list(base.sources) + list(overlay.sources)))

    return LLMPolicy(
        allowlist=merged_allow,
        denylist=merged_deny,
        pinned_provider=merged_pin_provider,
        pinned_model=merged_pin_model,
        strict=merged_strict,
        sources=sources,
        warnings=tuple(warnings),
    )
