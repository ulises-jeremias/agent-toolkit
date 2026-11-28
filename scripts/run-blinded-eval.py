#!/usr/bin/env python3
"""Blinded real-task evaluation harness for agent-toolkit vs external baselines.

Implements leak-word sanitization, deterministic seeded blind labeling with a
separate reveal map, transcript tool-call auditing, cross-vendor judge
enforcement, and Goal v1 evidence receipt emission/verification.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
GOAL_EVIDENCE_SCHEMA_PATH = REPO_ROOT / "schemas" / "goal-evidence-v1.schema.json"

EVIDENCE_MODES = ("fixture", "hermetic", "real")
MODE_RANK = {"fixture": 0, "hermetic": 1, "real": 2}
RESULT_VALUES = ("pass", "fail", "inconclusive")

SHA_PATTERN = re.compile(r"^(?:[a-f0-9]{40}|[a-f0-9]{64})$")
DIGEST_PATTERN = re.compile(r"^sha256:[a-f0-9]{64}$")
TASK_ID_PATTERN = re.compile(r"^(?!\.\.?$)[A-Za-z0-9._-]{1,100}$")

VENDOR_ALIASES = {
    "anthropic-ai": "anthropic",
    "claude": "anthropic",
    "deepmind": "google",
    "google-deepmind": "google",
    "openai-codex": "openai",
    "vertex": "google",
    "x-ai": "xai",
}

MODEL_VENDOR_PREFIXES: tuple[tuple[str, str], ...] = (
    ("claude", "anthropic"),
    ("gpt", "openai"),
    ("o1", "openai"),
    ("o3", "openai"),
    ("o4", "openai"),
    ("codex", "openai"),
    ("gemini", "google"),
    ("grok", "xai"),
    ("mistral", "mistral"),
    ("codestral", "mistral"),
    ("deepseek", "deepseek"),
    ("qwen", "alibaba"),
    ("llama", "meta"),
)

DEFAULT_EXACT_LEAK_MARKERS: tuple[str, ...] = (
    "agent-toolkit",
    "agent_toolkit",
    "pstack",
    "claude-code",
    "claude code",
    "cursor",
    "opencode",
    "windsurf",
    "veasel",
    "gemini-cli",
    "copilot-cli",
    "codex-cli",
    "anthropic",
    "openai",
    "google-deepmind",
    "opus",
    "sonnet",
    "haiku",
    "deepseek",
    "codestral",
    "system prompt",
    "<system_instruction>",
    "<<sys>>",
    "begin system prompt",
    "you are claude",
    "you are chatgpt",
    "you are codex",
    "developer instructions:",
)

DEFAULT_PREFIX_LEAK_MARKERS: tuple[str, ...] = (
    "claude-",
    "gpt-",
    "o1-",
    "o3-",
    "o4-",
    "gemini-",
    "llama-",
    "qwen-",
)

TEST_COMMAND_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("test", re.compile(r"(?:^|[;&|\s/])(?:pytest|py\.test|unittest)(?:\s|$)", re.IGNORECASE)),
    (
        "test",
        re.compile(
            r"(?:^|[;&|\s])(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?(?:test|e2e|spec)\b", re.IGNORECASE
        ),
    ),
    (
        "test",
        re.compile(
            r"(?:^|[;&|\s])(?:cargo|go|v)\s+test\b|(?:^|[;&|\s])(?:\./)?make\.vsh\s+test\b",
            re.IGNORECASE,
        ),
    ),
    ("test", re.compile(r"(?:^|[;&|\s])(?:jest|vitest|playwright|mocha)\b", re.IGNORECASE)),
    ("test", re.compile(r"(?:^|[;&|\s])make\s+test\b", re.IGNORECASE)),
    ("lint", re.compile(r"(?:^|[;&|\s])(?:ruff|eslint|shellcheck|markdownlint)\b", re.IGNORECASE)),
    ("typecheck", re.compile(r"(?:^|[;&|\s])(?:mypy|pyright|tsc)\b", re.IGNORECASE)),
    (
        "build",
        re.compile(
            r"(?:^|[;&|\s])(?:cargo\s+build|go\s+build|npm\s+run\s+build|(?:\./)?make\.vsh\s+build)\b",
            re.IGNORECASE,
        ),
    ),
)

CLAIM_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "test",
        re.compile(
            r"\b(?:all\s+\d+\s+tests?|all\s+tests?|unit\s+tests?|the\s+tests?|test\s+suite|pytest|unittest|cargo\s+test|go\s+test|v\s+test|npm\s+test)\b"
            r"[^.\n]{0,40}\b(?:pass(?:ed|es|ing)?|green|succeeded)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "test",
        re.compile(
            r"\b(?:verified|confirmed)\s+(?:that\s+)?(?:all\s+)?tests?\s+(?:pass(?:ed)?|are\s+passing)\b",
            re.IGNORECASE,
        ),
    ),
    ("test", re.compile(r"\b0\s+failed\b|\bzero\s+failures?\b", re.IGNORECASE)),
    (
        "lint",
        re.compile(
            r"\b(?:ruff|eslint|lint(?:er|ing)?|format\s+check)\b[^.\n]{0,30}\b(?:pass(?:ed|es)?|clean|succeeded)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "typecheck",
        re.compile(
            r"\b(?:mypy|pyright|type\s*check(?:ing)?)\b[^.\n]{0,30}\b(?:pass(?:ed|es)?|clean|succeeded)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "build",
        re.compile(
            r"\b(?:build|compilation)\b[^.\n]{0,25}\b(?:succeeded|passed|green)\b",
            re.IGNORECASE,
        ),
    ),
)

SHELL_TOOL_NAMES = {
    "bash",
    "sh",
    "shell",
    "exec",
    "exec_command",
    "execute_command",
    "run_command",
    "terminal",
    "local_shell",
}

EXIT_CODE_TEXT_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"command exited with code\s+(-?\d+)", re.IGNORECASE),
    re.compile(r"exit[_\s]+code\s*[:=]\s*(-?\d+)", re.IGNORECASE),
    re.compile(r"return[_\s]*code\s*[:=]\s*(-?\d+)", re.IGNORECASE),
)


class HarnessError(ValueError):
    """Domain error raised when validation or policy checks fail."""

    def __init__(self, message: str, *, hint: str | None = None) -> None:
        super().__init__(message)
        self.hint = hint


@dataclass(frozen=True)
class LeakFinding:
    location: str
    marker: str
    snippet: str


@dataclass(frozen=True)
class CrossVendorReport:
    passed: bool
    allow_same_vendor: bool
    judge_model: str
    judge_vendor: str
    conflicts: list[str]


def sha256_bytes(data: bytes) -> str:
    return f"sha256:{hashlib.sha256(data).hexdigest()}"


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def canonical_json_bytes(payload: Any) -> bytes:
    return (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode("utf-8")


def load_structured_input(path_arg: str) -> tuple[Any, bytes]:
    """Load JSON or YAML from a file path or '-' for stdin."""
    if path_arg == "-":
        raw = sys.stdin.read()
        source_name = "<stdin>"
    else:
        path = Path(path_arg)
        if not path.is_file():
            raise HarnessError(f"Input file not found: {path}")
        raw = path.read_text(encoding="utf-8")
        source_name = str(path)

    raw_bytes = raw.encode("utf-8")
    stripped = raw.lstrip()
    if path_arg.endswith((".yaml", ".yml")) or (
        stripped and not stripped.startswith("{") and not stripped.startswith("[")
    ):
        try:
            import yaml
        except ImportError as exc:
            raise HarnessError(
                f"PyYAML is required to parse YAML input ({source_name}).",
                hint="Run via `uv run --project packages/pypi/agent-toolkit-cli --directory . python scripts/run-blinded-eval.py ...`",
            ) from exc
        try:
            return yaml.safe_load(raw), raw_bytes
        except yaml.YAMLError as exc:
            raise HarnessError(f"Invalid YAML in {source_name}: {exc}") from exc

    try:
        return json.loads(raw), raw_bytes
    except json.JSONDecodeError as exc:
        raise HarnessError(f"Invalid JSON in {source_name}: {exc}") from exc


def normalize_vendor(vendor: str | None, model: str | None = None) -> str:
    """Normalize a provider/vendor identifier or infer it from a model name."""
    if vendor and vendor.strip():
        cleaned = vendor.strip().lower()
        return VENDOR_ALIASES.get(cleaned, cleaned)
    if model and model.strip():
        model_lower = model.strip().lower()
        for prefix, inferred in MODEL_VENDOR_PREFIXES:
            if model_lower == prefix or model_lower.startswith(f"{prefix}-"):
                return inferred
    return ""


def enforce_cross_vendor(
    judge: dict[str, Any],
    candidates: list[dict[str, Any]],
    *,
    allow_same_vendor: bool = False,
) -> CrossVendorReport:
    """Ensure the judge model/vendor differs from every candidate."""
    if not isinstance(judge, dict):
        raise HarnessError("Manifest 'judge' must be an object with 'model' and/or 'vendor'.")
    judge_model = str(judge.get("model") or "").strip().lower()
    judge_vendor = normalize_vendor(judge.get("vendor"), judge_model)
    if not judge_vendor:
        raise HarnessError(
            "Judge vendor is missing and could not be inferred from judge.model.",
            hint="Set judge.vendor explicitly (for example 'google', 'openai', or 'anthropic').",
        )

    conflicts: list[str] = []
    for idx, candidate in enumerate(candidates):
        cid = str(candidate.get("candidate_id") or f"candidate-{idx + 1}")
        cand_model = str(candidate.get("model") or "").strip().lower()
        cand_vendor = normalize_vendor(candidate.get("vendor"), cand_model)
        if not cand_vendor:
            raise HarnessError(
                f"Candidate {cid!r} has no vendor and it could not be inferred from model {cand_model!r}.",
                hint="Set candidate.vendor explicitly for every candidate.",
            )
        if cand_vendor == judge_vendor:
            conflicts.append(
                f"candidate {cid!r} shares vendor {cand_vendor!r} with judge {judge_vendor!r}"
            )
        elif judge_model and cand_model and cand_model == judge_model:
            conflicts.append(
                f"candidate {cid!r} shares model {cand_model!r} with judge {judge_model!r}"
            )

    if conflicts and not allow_same_vendor:
        joined = "; ".join(conflicts)
        raise HarnessError(
            f"Cross-vendor judge enforcement failed: {joined}.",
            hint="Use a judge from a distinct vendor, or pass --allow-same-vendor only for local dry runs.",
        )

    return CrossVendorReport(
        passed=not conflicts,
        allow_same_vendor=allow_same_vendor,
        judge_model=judge_model,
        judge_vendor=judge_vendor,
        conflicts=conflicts,
    )


def _iter_strings(value: Any, prefix: str) -> list[tuple[str, str]]:
    """Collect (dotted_path, text) pairs from nested JSON-like values."""
    results: list[tuple[str, str]] = []
    if isinstance(value, str):
        results.append((prefix, value))
    elif isinstance(value, list):
        for idx, item in enumerate(value):
            results.extend(_iter_strings(item, f"{prefix}[{idx}]"))
    elif isinstance(value, dict):
        for key, item in value.items():
            results.extend(_iter_strings(item, f"{prefix}.{key}"))
    return results


def _build_leak_patterns(
    candidates: list[dict[str, Any]],
    extra_leak_words: list[str],
    ignore_leak_words: set[str],
) -> list[tuple[str, re.Pattern[str]]]:
    exact_markers: list[str] = list(DEFAULT_EXACT_LEAK_MARKERS)
    for candidate in candidates:
        for field_name in (
            "candidate_id",
            "tool",
            "harness",
            "model",
            "vendor",
            "branch",
            "provider",
        ):
            raw_val = candidate.get(field_name)
            if isinstance(raw_val, str):
                cleaned = raw_val.strip()
                if len(cleaned) >= 3:
                    exact_markers.append(cleaned)
    for word in extra_leak_words:
        cleaned = word.strip()
        if cleaned:
            exact_markers.append(cleaned)

    seen: set[str] = set()
    compiled: list[tuple[str, re.Pattern[str]]] = []
    for marker in exact_markers:
        lowered = marker.lower()
        if lowered in ignore_leak_words or lowered in seen:
            continue
        seen.add(lowered)
        if re.match(r"^[A-Za-z0-9_]", marker) and re.search(r"[A-Za-z0-9_]$", marker):
            pattern = re.compile(
                rf"(?<![A-Za-z0-9_]){re.escape(marker)}(?![A-Za-z0-9_])", re.IGNORECASE
            )
        else:
            pattern = re.compile(re.escape(marker), re.IGNORECASE)
        compiled.append((marker, pattern))

    for prefix in DEFAULT_PREFIX_LEAK_MARKERS:
        if prefix.lower() in ignore_leak_words:
            continue
        compiled.append(
            (
                prefix,
                re.compile(rf"(?<![A-Za-z0-9_]){re.escape(prefix)}[A-Za-z0-9._-]+", re.IGNORECASE),
            )
        )
    return compiled


def find_leak_markers(
    fields: list[tuple[str, Any]],
    *,
    candidates: list[dict[str, Any]] | None = None,
    extra_leak_words: list[str] | None = None,
    ignore_leak_words: list[str] | None = None,
) -> list[LeakFinding]:
    """Scan judge-facing payloads for candidate, tool, model, branch, or prompt leaks."""
    ignored = {w.strip().lower() for w in (ignore_leak_words or []) if w.strip()}
    patterns = _build_leak_patterns(candidates or [], extra_leak_words or [], ignored)

    findings: list[LeakFinding] = []
    for root_name, value in fields:
        for loc, text in _iter_strings(value, root_name):
            for marker, pattern in patterns:
                match = pattern.search(text)
                if match:
                    start = max(0, match.start() - 24)
                    end = min(len(text), match.end() + 24)
                    snippet = text[start:end].replace("\n", " ")
                    findings.append(LeakFinding(location=loc, marker=marker, snippet=snippet))
    return findings


def _blind_label(index: int) -> str:
    """Map 0 -> 'Candidate A', 25 -> 'Candidate Z', 26 -> 'Candidate AA'."""
    letters: list[str] = []
    n = index
    while True:
        letters.append(chr(ord("A") + (n % 26)))
        n = n // 26 - 1
        if n < 0:
            break
    return "Candidate " + "".join(reversed(letters))


def _judge_visible_candidate_payload(candidate: dict[str, Any]) -> dict[str, Any]:
    """Strip all identifying metadata from a candidate before judge exposure."""
    allowed_fields = (
        "summary",
        "diff",
        "notes",
        "artifacts",
        "transcript_summary",
        "audit_summary",
    )
    payload: dict[str, Any] = {}
    for key in allowed_fields:
        if key in candidate and candidate[key] is not None:
            payload[key] = candidate[key]
    return payload


def prepare_blinded_eval(
    manifest: dict[str, Any],
    *,
    seed: str,
    judge_out: Path,
    reveal_out: Path,
    allow_same_vendor: bool = False,
    extra_leak_words: list[str] | None = None,
    ignore_leak_words: list[str] | None = None,
) -> dict[str, Any]:
    """Validate manifest, enforce cross-vendor and leak rules, and emit blinded outputs."""
    if judge_out.resolve() == reveal_out.resolve():
        raise HarnessError(
            "Judge package path and reveal map path must be distinct files.",
            hint="Pass different paths to --judge-out and --reveal-out.",
        )

    for required_key in ("eval_id", "task_id", "task_prompt", "judge", "candidates"):
        if required_key not in manifest:
            raise HarnessError(f"Manifest missing required field {required_key!r}.")

    task_id = str(manifest["task_id"])
    if not TASK_ID_PATTERN.match(task_id):
        raise HarnessError(f"Invalid task_id {task_id!r} for Goal evidence schema.")

    candidates = manifest["candidates"]
    if not isinstance(candidates, list) or not candidates:
        raise HarnessError("Manifest 'candidates' must be a non-empty list.")

    seen_ids: set[str] = set()
    for idx, cand in enumerate(candidates):
        if not isinstance(cand, dict):
            raise HarnessError(f"Candidate at index {idx} must be an object.")
        cid = str(cand.get("candidate_id") or "").strip()
        if not cid:
            raise HarnessError(f"Candidate at index {idx} missing 'candidate_id'.")
        if cid in seen_ids:
            raise HarnessError(f"Duplicate candidate_id {cid!r}.")
        seen_ids.add(cid)

    cross_vendor = enforce_cross_vendor(
        manifest["judge"],
        candidates,
        allow_same_vendor=allow_same_vendor,
    )

    manifest_leak_words = [
        str(w) for w in manifest.get("leak_words", []) if isinstance(w, str) and w.strip()
    ]
    combined_leak_words = manifest_leak_words + list(extra_leak_words or [])

    judge_fields: list[tuple[str, Any]] = [("task_prompt", manifest["task_prompt"])]
    sanitized_candidates: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for cand in candidates:
        visible = _judge_visible_candidate_payload(cand)
        judge_fields.append((f"candidates[{cand['candidate_id']}]", visible))
        sanitized_candidates.append((cand, visible))

    leak_findings = find_leak_markers(
        judge_fields,
        candidates=candidates,
        extra_leak_words=combined_leak_words,
        ignore_leak_words=ignore_leak_words,
    )
    if leak_findings:
        first = leak_findings[0]
        raise HarnessError(
            f"Leak marker detected ({len(leak_findings)} total): {first.marker!r} at {first.location} ({first.snippet!r}).",
            hint="Remove candidate, tool, model, vendor, branch, and system-prompt markers before blinding.",
        )

    ordered = sorted(sanitized_candidates, key=lambda pair: str(pair[0]["candidate_id"]))
    seed_digest = hashlib.sha256(f"{seed}".encode("utf-8")).digest()
    rng = random.Random(int.from_bytes(seed_digest, "big"))
    rng.shuffle(ordered)

    blinded_entries: list[dict[str, Any]] = []
    reveal_mappings: list[dict[str, Any]] = []
    for idx, (raw_cand, visible) in enumerate(ordered):
        label = _blind_label(idx)
        entry = {"blind_label": label, **visible}
        blinded_entries.append(entry)

        cand_model = str(raw_cand.get("model") or "").strip()
        cand_vendor = normalize_vendor(raw_cand.get("vendor"), cand_model)
        reveal_mappings.append(
            {
                "blind_label": label,
                "candidate_id": raw_cand["candidate_id"],
                "tool": raw_cand.get("tool"),
                "harness": raw_cand.get("harness"),
                "model": cand_model or None,
                "vendor": cand_vendor,
                "branch": raw_cand.get("branch"),
                "candidate_sha": raw_cand.get("candidate_sha"),
            }
        )

    evidence_mode = manifest.get("evidence_mode") or manifest.get("mode")
    if evidence_mode is not None and evidence_mode not in EVIDENCE_MODES:
        raise HarnessError(
            f"Manifest evidence_mode {evidence_mode!r} must be one of {EVIDENCE_MODES}."
        )

    judge_package: dict[str, Any] = {
        "schema_version": 1,
        "eval_id": manifest["eval_id"],
        "task_id": task_id,
        "task_prompt": manifest["task_prompt"],
        "judge": {
            "model": cross_vendor.judge_model or manifest["judge"].get("model"),
            "vendor": cross_vendor.judge_vendor,
        },
        "cross_vendor_check": asdict(cross_vendor),
        "candidates": blinded_entries,
    }
    if evidence_mode is not None:
        judge_package["evidence_mode"] = evidence_mode

    judge_bytes = canonical_json_bytes(judge_package)
    judge_digest = sha256_bytes(judge_bytes)

    reveal_map: dict[str, Any] = {
        "schema_version": 1,
        "eval_id": manifest["eval_id"],
        "task_id": task_id,
        "seed": str(seed),
        "judge_package_sha256": judge_digest,
        "cross_vendor_check": asdict(cross_vendor),
        "mappings": reveal_mappings,
    }
    if evidence_mode is not None:
        reveal_map["evidence_mode"] = evidence_mode

    reveal_bytes = canonical_json_bytes(reveal_map)
    judge_out.parent.mkdir(parents=True, exist_ok=True)
    reveal_out.parent.mkdir(parents=True, exist_ok=True)
    judge_out.write_bytes(judge_bytes)
    reveal_out.write_bytes(reveal_bytes)

    return {
        "eval_id": manifest["eval_id"],
        "task_id": task_id,
        "candidate_count": len(blinded_entries),
        "judge_out": str(judge_out),
        "judge_package_sha256": judge_digest,
        "reveal_out": str(reveal_out),
        "reveal_map_sha256": sha256_bytes(reveal_bytes),
        "cross_vendor_passed": cross_vendor.passed,
    }


def _parse_transcript_events(raw_text: str) -> list[dict[str, Any]]:
    stripped = raw_text.strip()
    if not stripped:
        return []
    if stripped.startswith("["):
        data = json.loads(stripped)
        if not isinstance(data, list):
            raise HarnessError("Transcript JSON array expected.")
        return [e for e in data if isinstance(e, dict)]
    if stripped.startswith("{"):
        try:
            obj = json.loads(stripped)
            if isinstance(obj, dict):
                for key in ("events", "messages", "entries", "transcript"):
                    if isinstance(obj.get(key), list):
                        return [e for e in obj[key] if isinstance(e, dict)]
                return [obj]
        except json.JSONDecodeError:
            pass

    events: list[dict[str, Any]] = []
    for lineno, line in enumerate(raw_text.splitlines(), start=1):
        line_str = line.strip()
        if not line_str:
            continue
        try:
            parsed = json.loads(line_str)
        except json.JSONDecodeError as exc:
            raise HarnessError(f"Invalid JSONL at transcript line {lineno}: {exc}") from exc
        if not isinstance(parsed, dict):
            raise HarnessError(f"Transcript line {lineno} must be a JSON object.")
        events.append(parsed)
    return events


def _extract_command_from_args(tool_name: str, args: Any) -> str | None:
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except json.JSONDecodeError:
            if tool_name.lower() in SHELL_TOOL_NAMES:
                return args.strip() or None
            return None
    if isinstance(args, dict):
        for key in ("command", "CommandLine", "cmd", "script"):
            val = args.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
    return None


def _extract_exit_code(payload: Any) -> tuple[int | None, bool]:
    """Return (exit_code, is_error) from tool_result payloads."""
    if not isinstance(payload, dict):
        if isinstance(payload, str):
            for pat in EXIT_CODE_TEXT_PATTERNS:
                match = pat.search(payload)
                if match:
                    code = int(match.group(1))
                    return code, code != 0
        return None, False

    is_error = bool(payload.get("is_error") or payload.get("error") is True)
    for key in ("exit_code", "returncode", "exitCode", "status_code"):
        val = payload.get(key)
        if isinstance(val, int) and not isinstance(val, bool):
            return val, is_error or val != 0

    for nested_key in ("metadata", "result", "details"):
        nested = payload.get(nested_key)
        if isinstance(nested, dict):
            code, nested_err = _extract_exit_code(nested)
            if code is not None:
                return code, is_error or nested_err

    for text_key in ("output", "content", "stdout", "stderr", "text"):
        val = payload.get(text_key)
        if isinstance(val, str):
            stripped = val.strip()
            if stripped.startswith("{"):
                try:
                    inner = json.loads(stripped)
                    code, inner_err = _extract_exit_code(inner)
                    if code is not None:
                        return code, is_error or inner_err
                except json.JSONDecodeError:
                    pass
            for pat in EXIT_CODE_TEXT_PATTERNS:
                match = pat.search(val)
                if match:
                    code = int(match.group(1))
                    return code, is_error or code != 0
        elif isinstance(val, list):
            for item in val:
                code, item_err = _extract_exit_code(item)
                if code is not None:
                    return code, is_error or item_err

    return None, is_error


def _classify_test_command(command: str) -> str | None:
    for category, pattern in TEST_COMMAND_PATTERNS:
        if pattern.search(command):
            return category
    return None


def _extract_assistant_texts(events: list[dict[str, Any]]) -> list[str]:
    texts: list[str] = []
    for event in events:
        role = str(event.get("role") or "").lower()
        etype = str(event.get("type") or "").lower()
        is_assistant = role == "assistant" or etype in ("assistant", "assistant_message", "text")
        if not is_assistant:
            continue
        for key in ("text", "message", "summary"):
            val = event.get(key)
            if isinstance(val, str) and val.strip():
                texts.append(val)
        content = event.get("content")
        if isinstance(content, str) and content.strip():
            texts.append(content)
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") in (None, "text", "output_text"):
                    btext = block.get("text")
                    if isinstance(btext, str) and btext.strip():
                        texts.append(btext)
    return texts


def audit_transcript_events(
    events: list[dict[str, Any]],
    *,
    transcript_digest: str,
    claims_text: str | None = None,
) -> dict[str, Any]:
    """Audit observed tool invocations, exit codes, and self-reported test claims."""
    pending_calls: dict[str, dict[str, Any]] = {}
    observed_calls: list[dict[str, Any]] = []

    def record_call(call_id: str | None, tool_name: str, command: str | None) -> None:
        entry = {
            "call_id": call_id,
            "tool": tool_name,
            "command": command,
            "exit_code": None,
            "is_error": False,
            "has_result": False,
        }
        observed_calls.append(entry)
        if call_id:
            pending_calls[call_id] = entry

    def apply_result(call_id: str | None, event_obj: dict[str, Any]) -> None:
        exit_code, is_error = _extract_exit_code(event_obj)
        if call_id and call_id in pending_calls:
            entry = pending_calls[call_id]
            entry["exit_code"] = exit_code
            entry["is_error"] = is_error
            entry["has_result"] = True
            return
        cmd = _extract_command_from_args(
            str(event_obj.get("tool") or event_obj.get("name") or "shell"), event_obj
        )
        if cmd:
            observed_calls.append(
                {
                    "call_id": call_id,
                    "tool": str(event_obj.get("tool") or event_obj.get("name") or "shell"),
                    "command": cmd,
                    "exit_code": exit_code,
                    "is_error": is_error,
                    "has_result": True,
                }
            )

    for event in events:
        etype = str(event.get("type") or "").lower()
        role = str(event.get("role") or "").lower()

        if etype in ("tool_use", "function_call"):
            call_id = event.get("id") or event.get("call_id")
            tool_name = str(event.get("name") or event.get("tool") or "")
            args = event.get("input") if "input" in event else event.get("arguments")
            cmd = _extract_command_from_args(tool_name, args)
            record_call(str(call_id) if call_id else None, tool_name, cmd)
        elif etype in ("tool_result", "function_call_output"):
            call_id = event.get("tool_use_id") or event.get("call_id") or event.get("tool_call_id")
            apply_result(str(call_id) if call_id else None, event)
        elif etype in ("command", "exec", "shell") or ("command" in event and "exit_code" in event):
            tool_name = str(event.get("tool") or event.get("name") or "shell")
            cmd = _extract_command_from_args(tool_name, event)
            exit_code, is_error = _extract_exit_code(event)
            observed_calls.append(
                {
                    "call_id": event.get("call_id") or event.get("id"),
                    "tool": tool_name,
                    "command": cmd,
                    "exit_code": exit_code,
                    "is_error": is_error,
                    "has_result": exit_code is not None or is_error,
                }
            )

        if isinstance(event.get("tool_calls"), list):
            for tc in event["tool_calls"]:
                if not isinstance(tc, dict):
                    continue
                fn = tc.get("function") if isinstance(tc.get("function"), dict) else {}
                tool_name = str(tc.get("name") or fn.get("name") or "")
                args = tc.get("arguments") if "arguments" in tc else fn.get("arguments")
                cmd = _extract_command_from_args(tool_name, args)
                tc_id = tc.get("id") or tc.get("call_id")
                record_call(str(tc_id) if tc_id else None, tool_name, cmd)

        if role == "tool":
            call_id = event.get("tool_call_id") or event.get("call_id")
            apply_result(str(call_id) if call_id else None, event)

        content = event.get("content")
        if isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = str(block.get("type") or "").lower()
                if btype == "tool_use":
                    b_id = block.get("id")
                    b_name = str(block.get("name") or "")
                    b_cmd = _extract_command_from_args(b_name, block.get("input"))
                    record_call(str(b_id) if b_id else None, b_name, b_cmd)
                elif btype == "tool_result":
                    b_id = block.get("tool_use_id") or block.get("call_id")
                    apply_result(str(b_id) if b_id else None, block)

    verified_commands: list[dict[str, Any]] = []
    observed_test_runs: list[dict[str, Any]] = []
    unmatched_command_runs: list[dict[str, Any]] = []

    for call in observed_calls:
        cmd = call["command"]
        if not cmd:
            continue
        exit_code = call["exit_code"]
        is_error = call["is_error"]
        if exit_code is not None:
            passed = exit_code == 0 and not is_error
            verified_commands.append(
                {
                    "tool": call["tool"],
                    "command": cmd,
                    "exit_code": exit_code,
                    "passed": passed,
                    "call_id": call["call_id"],
                }
            )
        else:
            unmatched_command_runs.append(call)

        category = _classify_test_command(cmd)
        if category is not None:
            passed_test = (exit_code == 0 and not is_error) if exit_code is not None else False
            observed_test_runs.append(
                {
                    "tool": call["tool"],
                    "command": cmd,
                    "exit_code": exit_code,
                    "passed": passed_test,
                    "category": category,
                    "has_result": call["has_result"],
                }
            )

    claim_sources: list[tuple[str, str]] = [
        ("assistant_message", text) for text in _extract_assistant_texts(events)
    ]
    if claims_text and claims_text.strip():
        claim_sources.append(("claims_input", claims_text))

    unverified_claims: list[dict[str, Any]] = []
    seen_claims: set[tuple[str, str]] = set()
    for source_name, text in claim_sources:
        for category, pattern in CLAIM_PATTERNS:
            for match in pattern.finditer(text):
                claim_str = match.group(0).strip()
                key = (category, claim_str.lower())
                if key in seen_claims:
                    continue
                seen_claims.add(key)

                matching_runs = [r for r in observed_test_runs if r["category"] == category]
                if not matching_runs and category == "test":
                    matching_runs = list(observed_test_runs)

                if not matching_runs:
                    unverified_claims.append(
                        {
                            "claim": claim_str,
                            "category": category,
                            "source": source_name,
                            "reason": f"no matching observed {category} command execution in transcript",
                            "contradicts_exit_code": None,
                        }
                    )
                    continue

                latest_run = matching_runs[-1]
                if latest_run["exit_code"] is None:
                    unverified_claims.append(
                        {
                            "claim": claim_str,
                            "category": category,
                            "source": source_name,
                            "reason": "matching command invoked without a recorded exit code",
                            "contradicts_exit_code": None,
                        }
                    )
                elif not latest_run["passed"]:
                    unverified_claims.append(
                        {
                            "claim": claim_str,
                            "category": category,
                            "source": source_name,
                            "reason": (
                                f"claimed pass contradicts observed failing command "
                                f"{latest_run['command']!r} (exit_code={latest_run['exit_code']})"
                            ),
                            "contradicts_exit_code": latest_run["exit_code"],
                        }
                    )

    passed_test_count = sum(1 for run in observed_test_runs if run["passed"])
    failed_test_count = sum(
        1 for run in observed_test_runs if run["exit_code"] is not None and not run["passed"]
    )
    latest_test_passed: bool | None = (
        observed_test_runs[-1]["passed"] if observed_test_runs else None
    )
    has_contradiction = any(c["contradicts_exit_code"] is not None for c in unverified_claims)

    if has_contradiction or latest_test_passed is False:
        audit_result = "fail"
    elif unverified_claims or not observed_test_runs:
        audit_result = "inconclusive"
    else:
        audit_result = "pass"

    return {
        "schema_version": 1,
        "transcript_sha256": transcript_digest,
        "total_events": len(events),
        "verified_commands": verified_commands,
        "observed_test_runs": observed_test_runs,
        "unverified_claims": unverified_claims,
        "has_unverified_claims": bool(unverified_claims),
        "passed_test_count": passed_test_count,
        "failed_test_count": failed_test_count,
        "latest_test_passed": latest_test_passed,
        "audit_result": audit_result,
    }


def _validate_against_goal_evidence_schema(receipt: dict[str, Any]) -> None:
    """Validate receipt against schemas/goal-evidence-v1.schema.json."""
    if not GOAL_EVIDENCE_SCHEMA_PATH.is_file():
        raise HarnessError(f"Missing schema file: {GOAL_EVIDENCE_SCHEMA_PATH}")
    schema = json.loads(GOAL_EVIDENCE_SCHEMA_PATH.read_text(encoding="utf-8"))

    try:
        import jsonschema
    except ImportError:
        jsonschema = None

    if jsonschema is not None:
        try:
            jsonschema.Draft202012Validator(schema).validate(receipt)
        except jsonschema.ValidationError as exc:
            raise HarnessError(
                f"Receipt failed goal-evidence-v1 schema validation: {exc.message}"
            ) from exc
        return

    # Strict fallback when invoked via bare python3 without jsonschema installed.
    for field in schema["required"]:
        if field not in receipt:
            raise HarnessError(f"Receipt missing required field {field!r}.")
    if not TASK_ID_PATTERN.match(str(receipt["task_id"])):
        raise HarnessError(f"Invalid task_id {receipt['task_id']!r}.")
    if (
        not isinstance(receipt["attempt"], int)
        or isinstance(receipt["attempt"], bool)
        or receipt["attempt"] < 1
    ):
        raise HarnessError("Receipt 'attempt' must be an integer >= 1.")
    for non_empty in ("repository", "environment", "verifier_identity", "verifier_version"):
        val = receipt[non_empty]
        if not isinstance(val, str) or not val:
            raise HarnessError(f"Receipt {non_empty!r} must be a non-empty string.")
    for sha_field in ("base_sha", "candidate_sha"):
        val = receipt[sha_field]
        if not isinstance(val, str) or not SHA_PATTERN.match(val):
            raise HarnessError(f"Receipt {sha_field!r} must be 40 or 64 lowercase hex characters.")
    if receipt["mode"] not in EVIDENCE_MODES:
        raise HarnessError(f"Receipt 'mode' must be one of {EVIDENCE_MODES}.")
    if receipt["result"] not in RESULT_VALUES:
        raise HarnessError(f"Receipt 'result' must be one of {RESULT_VALUES}.")
    digests = receipt["digests"]
    if (
        not isinstance(digests, list)
        or not digests
        or any(not isinstance(d, str) or not DIGEST_PATTERN.match(d) for d in digests)
    ):
        raise HarnessError("Receipt 'digests' must be a non-empty list of sha256:<64hex> strings.")


def _check_mode_not_upgraded(
    requested_mode: str, source_mode: str | None, source_name: str
) -> None:
    if source_mode is None:
        return
    if source_mode not in MODE_RANK:
        raise HarnessError(f"Invalid source mode {source_mode!r} in {source_name}.")
    if MODE_RANK[requested_mode] > MODE_RANK[source_mode]:
        raise HarnessError(
            f"Cannot upgrade evidence mode from {source_mode!r} ({source_name}) to {requested_mode!r}.",
            hint=f"Use --mode {source_mode} or re-run against an actual {requested_mode} environment.",
        )


def emit_receipt(
    *,
    task_id: str,
    attempt: int,
    repository: str,
    base_sha: str,
    candidate_sha: str,
    mode: str,
    environment: str,
    verifier_identity: str,
    verifier_version: str,
    result: str | None,
    source_mode: str | None = None,
    artifact_paths: list[Path] | None = None,
    extra_digests: list[str] | None = None,
    audit_path: Path | None = None,
    judge_package_path: Path | None = None,
    reveal_map_path: Path | None = None,
    allow_same_vendor: bool = False,
) -> dict[str, Any]:
    """Build and schema-validate a Goal v1 evidence receipt bound to candidate_sha."""
    if mode not in EVIDENCE_MODES:
        raise HarnessError(f"Invalid evidence mode {mode!r}; expected one of {EVIDENCE_MODES}.")
    _check_mode_not_upgraded(mode, source_mode, "--source-mode")

    digests: list[str] = []
    seen_digests: set[str] = set()

    def add_digest(digest: str) -> None:
        if digest not in seen_digests:
            seen_digests.add(digest)
            digests.append(digest)

    for digest in extra_digests or []:
        if not DIGEST_PATTERN.match(digest):
            raise HarnessError(
                f"Invalid SHA-256 digest {digest!r}; expected sha256:<64 lowercase hex>."
            )
        add_digest(digest)

    for artifact in artifact_paths or []:
        if not artifact.is_file():
            raise HarnessError(f"Artifact file not found: {artifact}")
        add_digest(sha256_file(artifact))

    eval_meta: dict[str, Any] = {}
    effective_source_mode = source_mode

    judge_pkg_digest: str | None = None
    if judge_package_path is not None:
        if not judge_package_path.is_file():
            raise HarnessError(f"Judge package not found: {judge_package_path}")
        judge_pkg = json.loads(judge_package_path.read_text(encoding="utf-8"))
        judge_pkg_digest = sha256_file(judge_package_path)
        add_digest(judge_pkg_digest)
        pkg_mode = judge_pkg.get("evidence_mode")
        _check_mode_not_upgraded(mode, pkg_mode, str(judge_package_path))
        if pkg_mode and (
            effective_source_mode is None or MODE_RANK[pkg_mode] < MODE_RANK[effective_source_mode]
        ):
            effective_source_mode = pkg_mode
        cv = judge_pkg.get("cross_vendor_check")
        if isinstance(cv, dict):
            eval_meta["cross_vendor_check"] = cv
            if not cv.get("passed", False) and not allow_same_vendor:
                raise HarnessError(
                    "Judge package cross-vendor check failed; refusing to emit receipt.",
                    hint="Pass --allow-same-vendor only for local dry runs.",
                )

    if reveal_map_path is not None:
        if not reveal_map_path.is_file():
            raise HarnessError(f"Reveal map not found: {reveal_map_path}")
        reveal_map = json.loads(reveal_map_path.read_text(encoding="utf-8"))
        add_digest(sha256_file(reveal_map_path))
        rev_mode = reveal_map.get("evidence_mode")
        _check_mode_not_upgraded(mode, rev_mode, str(reveal_map_path))
        if rev_mode and (
            effective_source_mode is None or MODE_RANK[rev_mode] < MODE_RANK[effective_source_mode]
        ):
            effective_source_mode = rev_mode
        if judge_pkg_digest and reveal_map.get("judge_package_sha256") != judge_pkg_digest:
            raise HarnessError("Reveal map judge_package_sha256 does not match --judge-package.")
        mappings = reveal_map.get("mappings", [])
        matched = [m for m in mappings if m.get("candidate_sha") == candidate_sha]
        if any(m.get("candidate_sha") for m in mappings) and not matched:
            raise HarnessError(
                f"candidate_sha {candidate_sha!r} does not appear in reveal map {reveal_map_path}."
            )
        if matched:
            eval_meta["blind_label"] = matched[0].get("blind_label")
            eval_meta["candidate_id"] = matched[0].get("candidate_id")

    audit_result: str | None = None
    if audit_path is not None:
        if not audit_path.is_file():
            raise HarnessError(f"Audit report not found: {audit_path}")
        audit = json.loads(audit_path.read_text(encoding="utf-8"))
        add_digest(sha256_file(audit_path))
        audit_mode = audit.get("evidence_mode")
        _check_mode_not_upgraded(mode, audit_mode, str(audit_path))
        audit_result = str(audit.get("audit_result") or "inconclusive")
        eval_meta["transcript_audit"] = {
            "audit_result": audit_result,
            "verified_command_count": len(audit.get("verified_commands", [])),
            "observed_test_run_count": len(audit.get("observed_test_runs", [])),
            "unverified_claim_count": len(audit.get("unverified_claims", [])),
        }
        if result == "pass" and (audit.get("has_unverified_claims") or audit_result != "pass"):
            raise HarnessError(
                f"Cannot emit 'pass' receipt when transcript audit status is {audit_result!r} "
                f"(unverified_claims={len(audit.get('unverified_claims', []))}).",
                hint="Inspect the transcript audit or omit --result so it reflects the audited outcome.",
            )

    final_result = result or audit_result
    if final_result not in RESULT_VALUES:
        raise HarnessError(
            f"Missing or invalid receipt result {final_result!r}; expected one of {RESULT_VALUES}.",
            hint="Pass --result pass|fail|inconclusive or provide --audit.",
        )

    if not digests:
        raise HarnessError(
            "At least one artifact or digest is required to emit a receipt.",
            hint="Pass --artifact <file>, --audit <file>, or --digest sha256:<64hex>.",
        )

    receipt: dict[str, Any] = {
        "task_id": task_id,
        "attempt": attempt,
        "repository": repository,
        "base_sha": base_sha,
        "candidate_sha": candidate_sha,
        "mode": mode,
        "evidence_mode": mode,
        "environment": environment,
        "verifier_identity": verifier_identity,
        "verifier_version": verifier_version,
        "result": final_result,
        "digests": digests,
    }
    if effective_source_mode is not None:
        receipt["source_mode"] = effective_source_mode
    if eval_meta:
        receipt["blinded_eval"] = eval_meta

    _validate_against_goal_evidence_schema(receipt)
    return receipt


def verify_receipt(
    receipt: dict[str, Any],
    *,
    expected_candidate_sha: str | None = None,
    expected_base_sha: str | None = None,
    expected_task_id: str | None = None,
    disallow_fixture: bool = False,
    allow_same_vendor: bool = False,
    artifact_paths: list[Path] | None = None,
) -> dict[str, Any]:
    """Verify a Goal v1 evidence receipt against schema, mode, SHA, and artifact digests."""
    if not isinstance(receipt, dict):
        raise HarnessError("Receipt must be a JSON object.")
    _validate_against_goal_evidence_schema(receipt)

    mode = receipt["mode"]
    evidence_mode = receipt.get("evidence_mode")
    if evidence_mode is not None and evidence_mode != mode:
        raise HarnessError(
            f"Receipt evidence_mode ({evidence_mode!r}) disagrees with mode ({mode!r})."
        )

    source_mode = receipt.get("source_mode")
    if source_mode is not None:
        _check_mode_not_upgraded(mode, str(source_mode), "receipt.source_mode")

    if disallow_fixture and mode == "fixture":
        raise HarnessError(
            "Receipt uses mode 'fixture', which is rejected when --disallow-fixture is set.",
            hint="Run verification in a hermetic or real environment and emit a new receipt.",
        )

    if expected_candidate_sha and receipt["candidate_sha"] != expected_candidate_sha:
        raise HarnessError(
            f"Receipt candidate_sha ({receipt['candidate_sha']}) does not match expected {expected_candidate_sha}."
        )
    if expected_base_sha and receipt["base_sha"] != expected_base_sha:
        raise HarnessError(
            f"Receipt base_sha ({receipt['base_sha']}) does not match expected {expected_base_sha}."
        )
    if expected_task_id and receipt["task_id"] != expected_task_id:
        raise HarnessError(
            f"Receipt task_id ({receipt['task_id']!r}) does not match expected {expected_task_id!r}."
        )

    blinded_eval = receipt.get("blinded_eval")
    if isinstance(blinded_eval, dict):
        cv = blinded_eval.get("cross_vendor_check")
        if isinstance(cv, dict) and not cv.get("passed", False) and not allow_same_vendor:
            raise HarnessError(
                "Receipt records a failed cross-vendor judge check.",
                hint="Pass --allow-same-vendor only when auditing dry-run receipts.",
            )

    recorded_digests = set(receipt["digests"])
    checked_artifacts: list[dict[str, str]] = []
    for artifact in artifact_paths or []:
        if not artifact.is_file():
            raise HarnessError(f"Artifact file not found: {artifact}")
        actual = sha256_file(artifact)
        if actual not in recorded_digests:
            raise HarnessError(
                f"Artifact digest mismatch for {artifact}: {actual} not in receipt.digests."
            )
        checked_artifacts.append({"path": str(artifact), "digest": actual})

    return {
        "verified": True,
        "task_id": receipt["task_id"],
        "candidate_sha": receipt["candidate_sha"],
        "mode": mode,
        "result": receipt["result"],
        "checked_artifacts": checked_artifacts,
    }


def _write_json_output(payload: Any, output_path: str | None) -> None:
    content = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if output_path is None or output_path == "-":
        sys.stdout.write(content)
        return
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _build_parser() -> argparse.ArgumentParser:
    root_epilog = """Examples:
  scripts/run-blinded-eval.py prepare --manifest eval.json --seed 42 --judge-out out/judge.json --reveal-out out/reveal.json
  scripts/run-blinded-eval.py audit-transcript --transcript run.jsonl --output out/audit.json
  scripts/run-blinded-eval.py emit-receipt --task-id gap4-check --repository ulises-jeremias/agent-toolkit --base-sha <40hex> --candidate-sha <40hex> --mode hermetic --environment local-pytest --audit out/audit.json --output out/receipt.json
  scripts/run-blinded-eval.py verify-receipt --receipt out/receipt.json --expected-candidate-sha <40hex> --disallow-fixture
"""
    parser = argparse.ArgumentParser(
        prog="run-blinded-eval.py",
        description="Deterministic blinded real-task evaluation harness.",
        epilog=root_epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # prepare
    prep_epilog = """Examples:
  scripts/run-blinded-eval.py prepare --manifest eval.json --seed 42 --judge-out judge.json --reveal-out reveal.json
  cat eval.yaml | scripts/run-blinded-eval.py prepare --manifest - --seed run-1 --judge-out judge.json --reveal-out reveal.json --allow-same-vendor
"""
    prep = subparsers.add_parser(
        "prepare",
        help="Sanitize leaks, check cross-vendor judge, and emit blinded judge/reveal files.",
        epilog=prep_epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    prep.add_argument(
        "--manifest", required=True, help="Manifest JSON/YAML path, or '-' for stdin."
    )
    prep.add_argument("--seed", required=True, help="Deterministic shuffle seed.")
    prep.add_argument(
        "--judge-out", required=True, type=Path, help="Output path for blinded judge package."
    )
    prep.add_argument(
        "--reveal-out", required=True, type=Path, help="Output path for separate reveal map."
    )
    prep.add_argument(
        "--allow-same-vendor",
        action="store_true",
        help="Allow judge vendor/model to match a candidate (for local dry runs only).",
    )
    prep.add_argument(
        "--leak-word",
        action="append",
        default=[],
        help="Additional case-insensitive leak marker to reject (repeatable).",
    )
    prep.add_argument(
        "--ignore-leak-word",
        action="append",
        default=[],
        help="Explicitly allow a built-in leak word when intentionally part of a fixture.",
    )

    # audit-transcript
    audit_epilog = """Examples:
  scripts/run-blinded-eval.py audit-transcript --transcript run.jsonl
  cat run.jsonl | scripts/run-blinded-eval.py audit-transcript --transcript - --output audit.json
"""
    audit = subparsers.add_parser(
        "audit-transcript",
        help="Verify observed tool commands and exit codes in JSONL/JSON transcripts.",
        epilog=audit_epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    audit.add_argument(
        "--transcript", required=True, help="Transcript JSON/JSONL path, or '-' for stdin."
    )
    audit.add_argument(
        "--claims-file", type=Path, help="Optional summary/claims file to cross-check."
    )
    audit.add_argument("--output", help="Output JSON path (defaults to stdout).")

    # emit-receipt
    emit_epilog = """Examples:
  scripts/run-blinded-eval.py emit-receipt --task-id eval-1 --repository ulises-jeremias/agent-toolkit --base-sha 0000000000000000000000000000000000000000 --candidate-sha 1111111111111111111111111111111111111111 --mode fixture --environment local-dry-run --result pass --artifact judge.json --output receipt.json
  scripts/run-blinded-eval.py emit-receipt --task-id eval-1 --repository ulises-jeremias/agent-toolkit --base-sha 0000000000000000000000000000000000000000 --candidate-sha 1111111111111111111111111111111111111111 --mode hermetic --environment pytest-sandbox --audit audit.json --output receipt.json
"""
    emit = subparsers.add_parser(
        "emit-receipt",
        help="Emit a Goal v1 evidence receipt bound to candidate_sha.",
        epilog=emit_epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    emit.add_argument("--task-id", required=True, help="Task identifier matching Goal v1 pattern.")
    emit.add_argument("--attempt", type=int, default=1, help="Attempt number (>= 1).")
    emit.add_argument("--repository", required=True, help="Repository slug or URL.")
    emit.add_argument("--base-sha", required=True, help="40 or 64 char lowercase hex base SHA.")
    emit.add_argument(
        "--candidate-sha", required=True, help="40 or 64 char lowercase hex candidate SHA."
    )
    emit.add_argument(
        "--mode",
        "--evidence-mode",
        dest="mode",
        required=True,
        choices=EVIDENCE_MODES,
        help="Evidence mode: fixture, hermetic, or real.",
    )
    emit.add_argument(
        "--source-mode",
        choices=EVIDENCE_MODES,
        help="Underlying source execution mode (prevents upgrading fixture -> real).",
    )
    emit.add_argument("--environment", required=True, help="Observed execution environment label.")
    emit.add_argument(
        "--verifier-identity", default="blinded-eval-harness", help="Verifier identifier."
    )
    emit.add_argument("--verifier-version", default="v1", help="Verifier version string.")
    emit.add_argument(
        "--result",
        choices=RESULT_VALUES,
        help="Outcome (defaults to audit_result when --audit given).",
    )
    emit.add_argument(
        "--artifact",
        action="append",
        type=Path,
        default=[],
        help="Artifact file to hash (repeatable).",
    )
    emit.add_argument(
        "--digest", action="append", default=[], help="Explicit sha256:<64hex> digest (repeatable)."
    )
    emit.add_argument("--audit", type=Path, help="Transcript audit JSON report path.")
    emit.add_argument("--judge-package", type=Path, help="Blinded judge package JSON path.")
    emit.add_argument("--reveal-map", type=Path, help="Separate reveal map JSON path.")
    emit.add_argument(
        "--allow-same-vendor", action="store_true", help="Allow dry-run same-vendor receipts."
    )
    emit.add_argument("--output", help="Output receipt JSON path (defaults to stdout).")

    # verify-receipt
    verify_epilog = """Examples:
  scripts/run-blinded-eval.py verify-receipt --receipt receipt.json --expected-candidate-sha 1111111111111111111111111111111111111111
  cat receipt.json | scripts/run-blinded-eval.py verify-receipt --receipt - --disallow-fixture --artifact judge.json
"""
    verify = subparsers.add_parser(
        "verify-receipt",
        help="Validate a Goal v1 evidence receipt against schema, SHA, mode, and artifacts.",
        epilog=verify_epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    verify.add_argument("--receipt", required=True, help="Receipt JSON path, or '-' for stdin.")
    verify.add_argument("--expected-candidate-sha", help="Expected candidate SHA.")
    verify.add_argument("--expected-base-sha", help="Expected base SHA.")
    verify.add_argument("--expected-task-id", help="Expected task ID.")
    verify.add_argument(
        "--disallow-fixture", action="store_true", help="Fail if receipt mode is 'fixture'."
    )
    verify.add_argument(
        "--allow-same-vendor", action="store_true", help="Allow receipts with same-vendor flag."
    )
    verify.add_argument(
        "--artifact",
        action="append",
        type=Path,
        default=[],
        help="Artifact whose digest must appear in receipt.",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        if args.subcommand == "prepare":
            manifest, _ = load_structured_input(args.manifest)
            if not isinstance(manifest, dict):
                raise HarnessError("Manifest root must be a JSON/YAML object.")
            summary = prepare_blinded_eval(
                manifest,
                seed=args.seed,
                judge_out=args.judge_out,
                reveal_out=args.reveal_out,
                allow_same_vendor=args.allow_same_vendor,
                extra_leak_words=args.leak_word,
                ignore_leak_words=args.ignore_leak_word,
            )
            _write_json_output(summary, None)
            return 0

        if args.subcommand == "audit-transcript":
            if args.transcript == "-":
                raw_text = sys.stdin.read()
            else:
                tpath = Path(args.transcript)
                if not tpath.is_file():
                    raise HarnessError(f"Transcript file not found: {tpath}")
                raw_text = tpath.read_text(encoding="utf-8")
            claims_text = None
            if args.claims_file is not None:
                if not args.claims_file.is_file():
                    raise HarnessError(f"Claims file not found: {args.claims_file}")
                claims_text = args.claims_file.read_text(encoding="utf-8")
            events = _parse_transcript_events(raw_text)
            report = audit_transcript_events(
                events,
                transcript_digest=sha256_bytes(raw_text.encode("utf-8")),
                claims_text=claims_text,
            )
            _write_json_output(report, args.output)
            return 0

        if args.subcommand == "emit-receipt":
            receipt = emit_receipt(
                task_id=args.task_id,
                attempt=args.attempt,
                repository=args.repository,
                base_sha=args.base_sha,
                candidate_sha=args.candidate_sha,
                mode=args.mode,
                environment=args.environment,
                verifier_identity=args.verifier_identity,
                verifier_version=args.verifier_version,
                result=args.result,
                source_mode=args.source_mode,
                artifact_paths=args.artifact,
                extra_digests=args.digest,
                audit_path=args.audit,
                judge_package_path=args.judge_package,
                reveal_map_path=args.reveal_map,
                allow_same_vendor=args.allow_same_vendor,
            )
            _write_json_output(receipt, args.output)
            return 0

        if args.subcommand == "verify-receipt":
            receipt, _ = load_structured_input(args.receipt)
            summary = verify_receipt(
                receipt,
                expected_candidate_sha=args.expected_candidate_sha,
                expected_base_sha=args.expected_base_sha,
                expected_task_id=args.expected_task_id,
                disallow_fixture=args.disallow_fixture,
                allow_same_vendor=args.allow_same_vendor,
                artifact_paths=args.artifact,
            )
            _write_json_output(summary, None)
            return 0
    except HarnessError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        if exc.hint:
            print(f"Hint: {exc.hint}", file=sys.stderr)
        return 2

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
