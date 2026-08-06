#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
bin/loop — Loop engineering CLI for AI Workspace.

A "loop" is a recurring AI-driven process with durable state, safety gates,
and cost budgets. Inspired by loop engineering principles (Cobus Greyling,
Boris Cherny, Peter Steinberger, Addy Osmani — 2026).

Usage:
    loop init <pattern>           Scaffold a loop from a starter template
    loop run <loop> [options]     Execute a loop run
    loop status [loop]            Show loop status (all, or one)
    loop audit [loop]             Summarize past runs (success rate, cost)
    loop cost <loop>              Estimate cost for one run
    loop schedule <loop>          Install systemd/launchd timer
    loop sync                     Regenerate knowledge todos from completed runs
    loop help                     Show this help

loop run options:
    --force                 Bypass max_runs_per_day only (not wall/token budgets)
    --quiet                 Suppress live runner output and trace progress lines
    --pack PATH             Apply loop overrides (enabled/cadence/budget) from pack YAML
    --runner NAME           Force a runner (default: auto, or $AGENT_TOOLKIT_LOOP_RUNNER)

Runners (auto tries in order until one is available):
    auto        Try harness → claude → opencode → cursor → copilot → codex → queue
    harness     agentic-workstation / dots-ai-devcompanion runner (HARNESS_RUNNER_DIR)
    claude      Claude Code CLI (`claude --print`)
    opencode    OpenCode CLI (`opencode run`)
    cursor      Cursor Agent CLI (`cursor-agent` / `agent` / `cursor` --print)
    copilot     GitHub Copilot CLI (`copilot -p`)
    codex       OpenAI Codex CLI (`codex exec`)
    queue       Queue via agent-toolkit devcompanion (async worker)
    skeleton    Write plan.md only (no LLM)

Environment:
    AGENT_TOOLKIT_LOOP_RUNNER   Default --runner when the flag is omitted (e.g. claude)
    AGENT_TOOLKIT_WORKSPACE     Workspace root override (also: HARNESS_DIR)
    HARNESS_RUNNER_DIR          Path to dots-ai-devcompanion runner package (harness)
    HARNESS_DC_HOME             Devcompanion queue home (queue runner / harness jobs)
    CURSOR_API_KEY              Auth for Cursor Agent CLI (cursor runner)
    COPILOT_GITHUB_TOKEN        Auth for Copilot CLI (also: GH_TOKEN / GITHUB_TOKEN)
    OPENAI_API_KEY / CODEX_API_KEY
                                Auth for Codex CLI (codex runner)
"""

from __future__ import annotations

import sys as _sys_win

# Windows: force UTF-8 output so Unicode chars (── ✓ ✗) don't crash
if _sys_win.platform == "win32":
    try:
        _sys_win.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore
        _sys_win.stderr.reconfigure(encoding="utf-8", errors="replace")  # type: ignore
    except Exception:
        pass

import hashlib
import json
import os
import platform
import re
import shutil
import signal
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── cancellation ──────────────────────────────────────────────────────────────

_CANCELLED = False
_PROGRESS_QUIET = False

# Explicit + auto runner selection (--runner / AGENT_TOOLKIT_LOOP_RUNNER)
RUNNER_AUTO = "auto"
RUNNER_NAMES = (
    "harness",
    "claude",
    "opencode",
    "cursor",
    "copilot",
    "codex",
    "queue",
    "skeleton",
)
RUNNER_ALIASES = {
    "devcompanion": "queue",
    "dc": "queue",
    "agent-toolkit": "harness",
    "cursor-agent": "cursor",
    "github-copilot": "copilot",
    "openai-codex": "codex",
}


class _TraceTailer:
    """Print trace.jsonl events as they are appended during a run."""

    def __init__(self, trace_file: Path, *, max_tokens: int | None = None) -> None:
        self._trace_file = trace_file
        self._offset = 0
        self._stop = False
        self._max_tokens = max_tokens
        self.tokens_used = 0
        self.budget_exhausted = False

    def poll(self) -> None:
        if not self._trace_file.exists():
            return
        data = self._trace_file.read_text(encoding="utf-8")
        if len(data) <= self._offset:
            return
        chunk = data[self._offset :]
        self._offset = len(data)
        for line in chunk.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            self._emit(event)

    def _emit(self, event: dict[str, Any]) -> None:
        kind = event.get("kind", "")
        if kind in ("run_start", "run_end", "worktree_created", "queued"):
            log(f"trace:{kind}")
        elif kind == "repo":
            log(f"repo: {event.get('name', event.get('path', '?'))}")
        elif kind == "token_usage":
            total = event.get("total_tokens") or event.get("total")
            if total is not None:
                self.tokens_used = max(self.tokens_used, int(total))
            cost = event.get("cost_usd")
            if cost is not None:
                log(f"tokens: {total} (~${cost})")
            elif total is not None:
                log(f"tokens: {total}")
            if self._max_tokens is not None and self.tokens_used >= self._max_tokens:
                self.budget_exhausted = True
        elif kind in ("prompt", "completion"):
            self.tokens_used += int(event.get("prompt_tokens", 0) or 0)
            self.tokens_used += int(event.get("completion_tokens", 0) or 0)
            if self._max_tokens is not None and self.tokens_used >= self._max_tokens:
                self.budget_exhausted = True
        elif kind == "progress":
            current = event.get("current")
            total = event.get("total")
            label = event.get("label", "progress")
            if current is not None and total is not None:
                log(f"{label}: {current}/{total}")
            else:
                log(f"{label}: {event.get('message', '')}")

    def stop(self) -> None:
        self._stop = True


def _run_with_live_output(
    cmd: list[str],
    *,
    input_text: str,
    cwd: str,
    env: dict[str, str],
    trace_file: Path | None = None,
    timeout: int = 900,
    max_tokens: int | None = None,
) -> subprocess.CompletedProcess[str]:
    """Run a subprocess, streaming stdout/stderr unless --quiet."""
    if _PROGRESS_QUIET:
        return subprocess.run(
            cmd,
            input=input_text,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=timeout,
            env=env,
        )

    import threading
    import time

    tailer = _TraceTailer(trace_file, max_tokens=max_tokens) if trace_file else None
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=cwd,
        env=env,
    )
    assert proc.stdin is not None and proc.stdout is not None
    proc.stdin.write(input_text)
    proc.stdin.close()

    lines: list[str] = []

    def _pump() -> None:
        for line in iter(proc.stdout.readline, ""):
            lines.append(line)
            print(f"{dim('[runner]')} {line.rstrip()}", flush=True)

    def _tail() -> None:
        while proc.poll() is None and not _CANCELLED:
            if tailer:
                tailer.poll()
                if tailer.budget_exhausted:
                    warn(
                        f"Token budget exhausted ({tailer.tokens_used:,} tokens); "
                        "terminating runner"
                    )
                    proc.kill()
                    break
            time.sleep(0.25)
        if tailer:
            tailer.poll()

    pump_thread = threading.Thread(target=_pump, daemon=True)
    tail_thread = threading.Thread(target=_tail, daemon=True)
    pump_thread.start()
    tail_thread.start()
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        raise
    if tailer and tailer.budget_exhausted:
        raise subprocess.TimeoutExpired(cmd, timeout)
    pump_thread.join(timeout=1)
    tail_thread.join(timeout=1)
    stdout = "".join(lines)
    return subprocess.CompletedProcess(cmd, proc.returncode or 0, stdout, "")


def _handle_sig(signum: int, _frame) -> None:
    global _CANCELLED
    if _CANCELLED:
        sys.exit(1)
    _CANCELLED = True
    print(file=sys.stderr)
    warn("Received signal — cancelling (press again to force exit)")


signal.signal(signal.SIGINT, _handle_sig)
signal.signal(signal.SIGTERM, _handle_sig)


# ── paths ─────────────────────────────────────────────────────────────────────


def _find_toolkit_root() -> Path:
    """Locate toolkit data (bundled loops/profiles). Prefer shared toolkit_root()."""
    try:
        from agent_toolkit._paths import toolkit_root

        return toolkit_root()
    except Exception:
        pass
    try:
        pkg_data = Path(__file__).resolve().parent.parent / "data"
        if pkg_data.is_dir() and (pkg_data / "loops").is_dir():
            return pkg_data
    except Exception:
        pass
    here = Path(__file__).resolve().parent
    for candidate in [here.parent.parent.parent, here.parent.parent, here.parent]:
        if (candidate / "loops").is_dir():
            return candidate
    return Path.cwd()


def workspace_root() -> Path:
    """User workspace root for loop instances (#200 / #207)."""
    from agent_toolkit._paths import find_workspace_root

    ws = find_workspace_root()
    if ws is not None:
        return ws
    for env in ("AGENT_TOOLKIT_ROOT", "AI_WORKSPACE"):
        val = os.environ.get(env, "").strip()
        if val:
            return Path(val).expanduser().resolve()
    return Path.cwd()


def loops_dir() -> Path:
    """User-created loop instances live under workspace/loops/ (#200)."""
    return workspace_root() / "loops"


def toolkit_loops_dir() -> Path:
    """Bundled reference templates under toolkit data/loops/."""
    return _find_toolkit_root() / "loops"


# Back-compat aliases (recomputed each access via functions preferred)
WORKSPACE_ROOT = Path.cwd()  # placeholder; prefer workspace_root()
LOOPS_DIR = Path.cwd() / "loops"
TEMPLATES_DIR = Path.cwd() / "loops"
WORKTREES_HOME = Path(
    os.environ.get("HARNESS_WORKTREES_DIR", "")
    or Path.home() / ".local" / "share" / "agent-toolkit" / "worktrees"
)

# Devcompanion queue paths (shared with bin/devcompanion)
_DC_HOME = Path(
    os.environ.get("HARNESS_DC_HOME")
    or Path.home() / ".local" / "share" / "agent-toolkit" / "dev-companion"
)
_QUEUE_PENDING = _DC_HOME / "queue" / "pending"
_QUEUE_DONE = _DC_HOME / "queue" / "done"
_QUEUE_FAILED = _DC_HOME / "queue" / "failed"

# ── colors ────────────────────────────────────────────────────────────────────

_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def blue(t: str) -> str:
    return _c("1;34", t)


def green(t: str) -> str:
    return _c("1;32", t)


def yellow(t: str) -> str:
    return _c("1;33", t)


def red(t: str) -> str:
    return _c("1;31", t)


def dim(t: str) -> str:
    return _c("0;37", t)


def log(msg: str) -> None:
    print(f"{blue('[loop]')} {msg}")


def ok(msg: str) -> None:
    print(f"{green('[loop]')} {msg}")


def warn(msg: str) -> None:
    print(f"{yellow('[loop]')} {msg}", file=sys.stderr)


def err(msg: str) -> None:
    print(f"{red('[loop]')} {msg}", file=sys.stderr)


# ── helpers ───────────────────────────────────────────────────────────────────


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_id() -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    import uuid

    return f"{ts}-{uuid.uuid4().hex[:6]}"


def parse_md_frontmatter(md_path: Path) -> dict[str, Any]:
    """Parse YAML frontmatter from any markdown file."""
    if not md_path.exists():
        return {}

    text = md_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    end = next((i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if end is None:
        return {}

    yaml_block = "\n".join(lines[1:end])
    try:
        import yaml  # type: ignore

        return yaml.safe_load(yaml_block) or {}
    except ImportError:
        return _parse_simple_yaml(yaml_block)


def parse_loop_md(loop_dir: Path) -> dict[str, Any]:
    """Parse loop config from LOOP.md frontmatter or loop.yaml."""
    loop_md = loop_dir / "LOOP.md"
    loop_yaml = loop_dir / "loop.yaml"
    if loop_md.exists():
        return parse_md_frontmatter(loop_md)
    if loop_yaml.exists():
        text = loop_yaml.read_text()
        return _parse_simple_yaml(text)
    return {}


def _parse_simple_yaml(text: str) -> dict[str, Any]:
    """Minimal YAML parser for loop frontmatter (no PyYAML required)."""
    result: dict[str, Any] = {}
    current_key: str | None = None
    list_items: list[str] = []
    in_budget = False
    budget: dict[str, Any] = {}

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if stripped == "budget:":
            in_budget = True
            current_key = "budget"
            continue

        if in_budget and line.startswith("  ") and ":" in stripped:
            k, _, v = stripped.partition(":")
            try:
                budget[k.strip()] = int(v.strip())
            except ValueError:
                budget[k.strip()] = v.strip()
            continue
        else:
            in_budget = False
            if "budget" in result and isinstance(result.get("budget"), dict):
                pass
            elif current_key == "budget":
                result["budget"] = budget
                budget = {}

        if stripped.startswith("- ") and current_key:
            list_items.append(stripped[2:].strip().strip('"').strip("'"))
            result[current_key] = list_items[:]
            continue
        elif ":" in stripped and not stripped.startswith("-"):
            if current_key and isinstance(result.get(current_key), list):
                list_items = []
            k, _, v = stripped.partition(":")
            current_key = k.strip()
            val = v.strip().strip('"').strip("'")
            if val:
                result[current_key] = val
            else:
                list_items = []
                result[current_key] = list_items

    if current_key == "budget":
        result["budget"] = budget

    return result


def parse_state_md(loop_dir: Path) -> dict[str, Any]:
    """Parse STATE.md frontmatter."""
    return parse_md_frontmatter(loop_dir / "STATE.md")


def write_state_md(loop_dir: Path, state: dict[str, Any]) -> None:
    """Write STATE.md with updated frontmatter.

    List/string values that contain '#' or ':' are quoted so PyYAML / the
    simple parser cannot treat PR numbers like ``#136`` as comments.
    """
    state_md = loop_dir / "STATE.md"

    def _fmt_scalar(v: Any) -> str:
        if v is None:
            return ""
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return str(v)
        # Always JSON-quote strings so PyYAML cannot coerce true/null/dates.
        return json.dumps(str(v), ensure_ascii=False)

    lines = ["---"]
    for k, v in state.items():
        if isinstance(v, list):
            lines.append(f"{k}:")
            for item in v:
                lines.append(f"  - {_fmt_scalar(item)}")
        elif isinstance(v, dict):
            lines.append(f"{k}:")
            for dk, dv in v.items():
                lines.append(f"  {dk}: {_fmt_scalar(dv)}")
        else:
            lines.append(f"{k}: {_fmt_scalar(v)}")
    lines.append("---")
    lines.append("")
    state_md.write_text("\n".join(lines), encoding="utf-8")


def list_loops() -> list[Path]:
    """Return user loop instances under workspace/loops/ (#201).

    Prefers directories with LOOP.md (init output). Also accepts loop.yaml for
    compatibility. Bundled templates are not listed here — use list_templates().
    """
    if not loops_dir().is_dir():
        return []
    return sorted(
        [
            d
            for d in loops_dir().iterdir()
            if d.is_dir() and ((d / "LOOP.md").exists() or (d / "loop.yaml").exists())
        ]
    )


def list_templates() -> list[Path]:
    """Return available loop templates (workspace overrides + bundled) (#200/#202)."""
    results: list[Path] = []
    seen: set[str] = set()

    ws = workspace_root()
    user_flat = ws / "templates" / "loops"
    if user_flat.is_dir():
        for f in sorted(user_flat.glob("*.yaml")):
            results.append(f)
            seen.add(f.stem)
        for d in sorted(user_flat.iterdir()):
            if d.is_dir() and (d / "loop.yaml").exists() and d.name not in seen:
                results.append(d / "loop.yaml")
                seen.add(d.name)

    bundled = toolkit_loops_dir()
    if bundled.is_dir():
        for d in sorted(bundled.iterdir()):
            if d.is_dir() and (d / "loop.yaml").exists() and d.name not in seen:
                results.append(d / "loop.yaml")
                seen.add(d.name)
        for f in sorted(bundled.glob("*.yaml")):
            if f.stem not in seen:
                results.append(f)
                seen.add(f.stem)
    return results


def resolve_template(pattern: str) -> Path | None:
    """Resolve a loop template path (#200 / #202).

    Order:
    1. ``$WORKSPACE/templates/loops/<pattern>.yaml``
    2. ``$WORKSPACE/templates/loops/<pattern>/loop.yaml``
    3. Bundled ``data/loops/<pattern>/loop.yaml``
    4. Bundled flat ``data/loops/<pattern>.yaml``
    """
    ws = workspace_root()
    candidates = [
        ws / "templates" / "loops" / f"{pattern}.yaml",
        ws / "templates" / "loops" / pattern / "loop.yaml",
        toolkit_loops_dir() / pattern / "loop.yaml",
        toolkit_loops_dir() / f"{pattern}.yaml",
    ]
    for path in candidates:
        if path.is_file():
            return path
    return None


def resolve_loop_dir(name: str) -> Path | None:
    """Resolve a runnable loop directory (#201).

    Prefer user instance ``$WORKSPACE/loops/<name>/`` (LOOP.md or loop.yaml).
    Fall back to bundled toolkit ``loops/<name>/`` when present.
    """
    user = loops_dir() / name
    if user.is_dir() and ((user / "LOOP.md").exists() or (user / "loop.yaml").exists()):
        return user
    bundled = toolkit_loops_dir() / name
    if bundled.is_dir() and ((bundled / "LOOP.md").exists() or (bundled / "loop.yaml").exists()):
        return bundled
    return None


# ── autonomy / prompt assembly ────────────────────────────────────────────────


def _as_str_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(x) for x in value]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def _load_request_body(loop_dir: Path, meta: dict[str, Any], loop_name: str) -> str:
    """Prefer request.md; fall back to LOOP.md goal / generic execute line."""
    request_md = loop_dir / "request.md"
    if request_md.exists():
        body = request_md.read_text(encoding="utf-8").strip()
        if body:
            return body
    if meta.get("request"):
        return str(meta["request"]).strip()
    goal = meta.get("goal")
    if goal:
        return f"Execute the '{loop_name}' loop.\n\nGoal: {goal}"
    return f"Execute the '{loop_name}' loop."


def _autonomy_contract(meta: dict[str, Any], loop_dir: Path) -> str:
    """Hard constraints injected into every runner prompt (not honor-system only)."""
    tier = str(meta.get("tier", "L1")).upper()
    allow = _as_str_list(meta.get("allowlist"))
    deny = _as_str_list(meta.get("deny"))
    verifier = meta.get("verifier") or "(none — treat all mutating actions as escalations)"
    state = parse_state_md(loop_dir)
    pending = _as_str_list(state.get("pending"))
    escalations = _as_str_list(state.get("escalations"))

    lines = [
        "## Autonomy contract (HARD — violate = human_escalation)",
        f"- Tier: {tier}",
        f"- Allowlist (may do without asking): {', '.join(allow) if allow else '(empty — no mutations)'}",
        f"- Deny (never do): {', '.join(deny) if deny else '(none listed)'}",
        f"- Verifier for mutating actions: {verifier}",
        "",
        "Tier rules:",
    ]
    if tier.startswith("L1") or tier == "1":
        lines.append(
            "- L1 report-only: READ and write plan.md/report.md/STATE.md only. "
            "Do NOT comment, label, assign, merge, close, push, commit, or approve."
        )
    elif tier.startswith("L2") or tier == "2":
        lines.append(
            "- L2 assisted: only allowlisted mutations (typically comment/label/assign). "
            "Never merge/close/push/commit/approve. Unsure → escalate, do not act."
        )
    else:
        lines.append(
            "- L3 unattended: only allowlisted mutations. Deny list is absolute. "
            "Human PRs: comment only — never merge/close. Unsure → escalate."
        )
        lines.append(
            f"- HARD GATE: `gh` is wrapped by `bin/loop-gh-gate`. merge/close require a "
            f"verifier receipt under `{loop_dir.name}/runs/<id>/verifier-receipts/`."
        )

    lines += [
        "",
        "Hard gate (enforced by PATH shim — not honor-system):",
        "- Mutating `gh` commands are intercepted. Denied actions exit with code 78 "
        "(from the intercepted `gh` process).",
        "- For merge/close: an *independent* verifier must write a receipt JSON "
        "(do NOT self-approve as the maker):",
        "  `$OUTPUT_DIR/verifier-receipts/<slug>.json` with keys:",
        "  `action`, `repo` (owner/name), `number`, `approved` (true), "
        f'`verifier` ("{verifier}"), `rationale`, `ts` (ISO8601 Z).',
        "- When `LOOP_GATE_RECEIPT_SECRET` is set, receipts must include "
        "`sig` (HMAC-SHA256 hex of the canonical JSON payload).",
        "- Receipts require exact repo + number + verifier match and expire after 1 hour.",
        "",
        "Before finishing:",
        f"1. Update `{loop_dir / 'STATE.md'}` frontmatter `pending:` and `escalations:` "
        "(replace with current lists; use empty lists if clear). "
        "Quote every list item that contains `#` (PR/issue numbers), e.g. "
        '`- "owner/repo#123 — reason"`.',
        "2. Write plan.md and report.md under the output directory.",
        "3. If exiting with human_escalation, put the reason in escalations and report.md.",
    ]
    if pending:
        lines += ["", "Carried pending from last run:"] + [f"- {p}" for p in pending]
    if escalations:
        lines += ["", "Open escalations:"] + [f"- {e}" for e in escalations]
    return "\n".join(lines)


def _build_runner_prompt(
    loop_dir: Path,
    meta: dict[str, Any],
    loop_name: str,
    run_dir: Path,
) -> str:
    request = _load_request_body(loop_dir, meta, loop_name)
    contract = _autonomy_contract(meta, loop_dir)
    return (
        "You are executing an autonomous loop run in an agent-toolkit workspace.\n"
        f"Workspace root: {workspace_root()}\n"
        f"Loop directory: {loop_dir}\n"
        f"Output directory: {run_dir}\n\n"
        f"{contract}\n\n"
        "---\n\n"
        f"{request}\n\n"
        "---\n\n"
        f"Write your final report to {run_dir}/report.md and your plan to "
        f"{run_dir}/plan.md. Work from the workspace root shown above."
    )


# ── built-in runners ──────────────────────────────────────────────────────────


def _gate_script() -> Path:
    return Path(__file__).resolve().parent / "loop-gh-gate"


def _runner_env(run_dir: Path, meta: dict[str, Any]) -> dict[str, str]:
    """Env for runners: PATH-first `gh` shim enforcing allowlist/deny/receipts.

    Fails closed: if the gate cannot be installed, raises RuntimeError so the
    run aborts rather than dispatching with an ungated `gh`.
    """
    import runpy

    gate_path = _gate_script()
    if not gate_path.exists():
        raise RuntimeError(f"loop-gh-gate missing at {gate_path} — refusing ungated run")

    try:
        mod = runpy.run_path(str(gate_path))
        tier = str(meta.get("tier", "L1"))
        allow = _as_str_list(meta.get("allowlist"))
        deny = _as_str_list(meta.get("deny"))
        verifier = str(meta.get("verifier") or "")
        env = mod["install_gh_shim"](
            run_dir,
            tier=tier,
            allowlist=allow,
            deny=deny,
            verifier=verifier,
            gate_script=gate_path,
        )
        log(
            f"Hard gate active: gh shim → allow=[{', '.join(allow) or '∅'}] "
            f"deny=[{', '.join(deny) or '∅'}]"
        )
        return env
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"failed to install gh gate ({exc}) — refusing ungated run") from exc


def _install_gate_into_environ(run_dir: Path, meta: dict[str, Any]) -> dict[str, str]:
    """Install the gh gate and apply its env to this process (and return a copy)."""
    env = _runner_env(run_dir, meta)
    # Mediate every subsequent child (agent-toolkit runner, etc.).
    for key, value in env.items():
        if key.startswith("LOOP_GATE_") or key == "PATH":
            os.environ[key] = value
    return env


def _try_claude_runner(
    prompt: str,
    run_dir: Path,
    meta: dict[str, Any] | None = None,
    *,
    trace_file: Path | None = None,
    wall_timeout: int | None = None,
    max_tokens: int | None = None,
) -> bool:
    """Invoke `claude --print` as a built-in runner for Claude Code users."""
    claude_bin = shutil.which("claude")
    if not claude_bin:
        return False

    from agent_toolkit.loop.budget import DEFAULT_WALL_SECONDS

    timeout = wall_timeout if wall_timeout is not None else DEFAULT_WALL_SECONDS
    env = _install_gate_into_environ(run_dir, meta or {})
    try:
        result = _run_with_live_output(
            [claude_bin, "--print", "--allowedTools", "Bash,Read,Write,Edit,Glob,Grep"],
            input_text=prompt,
            cwd=str(workspace_root()),
            env=env,
            trace_file=trace_file or (run_dir / "trace.jsonl"),
            timeout=timeout,
            max_tokens=max_tokens,
        )
    except subprocess.TimeoutExpired:
        warn(f"claude runner hit budget limit (wall={timeout}s or max_tokens)")
        return False

    if result.returncode == 0:
        report_md = run_dir / "report.md"
        if not report_md.exists() and result.stdout.strip():
            report_md.write_text(result.stdout, encoding="utf-8")
        ok("claude runner completed")
        return True

    # Claude Code writes auth/error output to stdout, not stderr — show both.
    error_output = (result.stderr + result.stdout).strip()[:400]
    warn(f"claude runner exited {result.returncode}: {error_output or '(no output)'}")
    if result.returncode == 1 and not error_output:
        warn("  Hint: Claude Code may not be authenticated — run: claude /login")
    return False


def _try_opencode_runner(
    prompt: str,
    run_dir: Path,
    meta: dict[str, Any] | None = None,
    *,
    trace_file: Path | None = None,
    wall_timeout: int | None = None,
    max_tokens: int | None = None,
) -> bool:
    """Invoke `opencode run` as a headless runner."""
    opencode_bin = shutil.which("opencode")
    if not opencode_bin:
        return False

    from agent_toolkit.loop.budget import DEFAULT_WALL_SECONDS

    timeout = wall_timeout if wall_timeout is not None else DEFAULT_WALL_SECONDS
    env = _install_gate_into_environ(run_dir, meta or {})
    try:
        result = _run_with_live_output(
            [opencode_bin, "run", "--print-logs"],
            input_text=prompt,
            cwd=str(workspace_root()),
            env=env,
            trace_file=trace_file or (run_dir / "trace.jsonl"),
            timeout=timeout,
            max_tokens=max_tokens,
        )
    except subprocess.TimeoutExpired:
        warn(f"opencode runner hit budget limit (wall={timeout}s or max_tokens)")
        return False

    if result.returncode == 0:
        report_md = run_dir / "report.md"
        if not report_md.exists() and result.stdout.strip():
            report_md.write_text(result.stdout, encoding="utf-8")
        ok("opencode runner completed")
        return True

    error_output = (result.stderr + result.stdout).strip()[:400]
    warn(f"opencode runner exited {result.returncode}: {error_output or '(no output)'}")
    return False


def _resolve_cursor_cli_bin() -> str | None:
    """Locate Cursor Agent CLI (`cursor-agent`, then `agent`, then `cursor`)."""
    for name in ("cursor-agent", "agent", "cursor"):
        found = shutil.which(name)
        if found:
            return found
    return None


def _try_cursor_runner(
    prompt: str,
    run_dir: Path,
    meta: dict[str, Any] | None = None,
    *,
    trace_file: Path | None = None,
    wall_timeout: int | None = None,
    max_tokens: int | None = None,
) -> bool:
    """Invoke Cursor Agent CLI headless (`--print`) as a loop runner (#223).

    Official headless form: ``agent -p --force --trust`` (also shipped as
    ``cursor-agent``). See https://cursor.com/docs/cli/headless
    """
    cursor_bin = _resolve_cursor_cli_bin()
    if not cursor_bin:
        return False

    from agent_toolkit.loop.budget import DEFAULT_WALL_SECONDS

    timeout = wall_timeout if wall_timeout is not None else DEFAULT_WALL_SECONDS
    env = _install_gate_into_environ(run_dir, meta or {})
    # Prompt as CLI arg (print mode); --force applies edits; --trust skips
    # workspace trust prompts in headless environments.
    cmd = [
        cursor_bin,
        "--print",
        "--force",
        "--trust",
        "--output-format",
        "text",
        prompt,
    ]
    try:
        result = _run_with_live_output(
            cmd,
            input_text="",
            cwd=str(workspace_root()),
            env=env,
            trace_file=trace_file or (run_dir / "trace.jsonl"),
            timeout=timeout,
            max_tokens=max_tokens,
        )
    except subprocess.TimeoutExpired:
        warn(f"cursor runner hit budget limit (wall={timeout}s or max_tokens)")
        return False

    if result.returncode == 0:
        report_md = run_dir / "report.md"
        if not report_md.exists() and result.stdout.strip():
            report_md.write_text(result.stdout, encoding="utf-8")
        ok("cursor runner completed")
        return True

    error_output = (result.stderr + result.stdout).strip()[:400]
    warn(f"cursor runner exited {result.returncode}: {error_output or '(no output)'}")
    if result.returncode != 0 and not error_output:
        warn("  Hint: Cursor Agent CLI may not be authenticated — run: agent login")
    return False


def _resolve_copilot_cli_bin() -> str | None:
    """Locate GitHub Copilot CLI (`copilot`).

    Prefers the standalone ``copilot`` binary (programmatic ``-p`` mode).
    Does not use legacy ``gh copilot suggest``, which is not a free-form agent.
    """
    return shutil.which("copilot")


def _try_copilot_runner(
    prompt: str,
    run_dir: Path,
    meta: dict[str, Any] | None = None,
    *,
    trace_file: Path | None = None,
    wall_timeout: int | None = None,
    max_tokens: int | None = None,
) -> bool:
    """Invoke GitHub Copilot CLI headless (``copilot -p``) as a loop runner (#224).

    See https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/run-cli-programmatically
    """
    copilot_bin = _resolve_copilot_cli_bin()
    if not copilot_bin:
        return False

    from agent_toolkit.loop.budget import DEFAULT_WALL_SECONDS

    timeout = wall_timeout if wall_timeout is not None else DEFAULT_WALL_SECONDS
    env = _install_gate_into_environ(run_dir, meta or {})
    # -p: non-interactive prompt; -s: silent (response only); --no-ask-user /
    # --allow-all: unattended tool use (gh mutations still go through loop-gh-gate).
    cmd = [
        copilot_bin,
        "-p",
        prompt,
        "-s",
        "--no-ask-user",
        "--allow-all",
    ]
    try:
        result = _run_with_live_output(
            cmd,
            input_text="",
            cwd=str(workspace_root()),
            env=env,
            trace_file=trace_file or (run_dir / "trace.jsonl"),
            timeout=timeout,
            max_tokens=max_tokens,
        )
    except subprocess.TimeoutExpired:
        warn(f"copilot runner hit budget limit (wall={timeout}s or max_tokens)")
        return False

    if result.returncode == 0:
        report_md = run_dir / "report.md"
        if not report_md.exists() and result.stdout.strip():
            report_md.write_text(result.stdout, encoding="utf-8")
        ok("copilot runner completed")
        return True

    error_output = (result.stderr + result.stdout).strip()[:400]
    warn(f"copilot runner exited {result.returncode}: {error_output or '(no output)'}")
    if result.returncode != 0 and not error_output:
        warn(
            "  Hint: Copilot CLI may not be authenticated — set COPILOT_GITHUB_TOKEN or run: copilot"
        )
    return False


def _try_codex_runner(
    prompt: str,
    run_dir: Path,
    meta: dict[str, Any] | None = None,
    *,
    trace_file: Path | None = None,
    wall_timeout: int | None = None,
    max_tokens: int | None = None,
) -> bool:
    """Invoke OpenAI Codex CLI headless (``codex exec``) as a loop runner (#225).

    See https://developers.openai.com/codex/noninteractive
    """
    codex_bin = shutil.which("codex")
    if not codex_bin:
        return False

    from agent_toolkit.loop.budget import DEFAULT_WALL_SECONDS

    timeout = wall_timeout if wall_timeout is not None else DEFAULT_WALL_SECONDS
    env = _install_gate_into_environ(run_dir, meta or {})
    report_md = run_dir / "report.md"
    # ``codex exec -`` reads the full prompt from stdin; workspace-write + never
    # ask keeps loops unattended; ``-o`` captures the final agent message.
    cmd = [
        codex_bin,
        "exec",
        "--ask-for-approval",
        "never",
        "--sandbox",
        "workspace-write",
        "--output-last-message",
        str(report_md),
        "-",
    ]
    try:
        result = _run_with_live_output(
            cmd,
            input_text=prompt,
            cwd=str(workspace_root()),
            env=env,
            trace_file=trace_file or (run_dir / "trace.jsonl"),
            timeout=timeout,
            max_tokens=max_tokens,
        )
    except subprocess.TimeoutExpired:
        warn(f"codex runner hit budget limit (wall={timeout}s or max_tokens)")
        return False

    if result.returncode == 0:
        if not report_md.exists() and result.stdout.strip():
            report_md.write_text(result.stdout, encoding="utf-8")
        ok("codex runner completed")
        return True

    error_output = (result.stderr + result.stdout).strip()[:400]
    warn(f"codex runner exited {result.returncode}: {error_output or '(no output)'}")
    if result.returncode != 0 and not error_output:
        warn("  Hint: Codex CLI may not be authenticated — set OPENAI_API_KEY / CODEX_API_KEY")
    return False


def _queue_via_devcompanion(
    request: str,
    run_dir: Path,
    loop_name: str,
    rid: str,
    meta: dict[str, Any] | None = None,
    *,
    wall_timeout: int | None = None,
) -> bool:
    """Queue the loop run as a devcompanion job for async processing.

    The job will be picked up by the systemd worker (dev-companion-worker)
    or via `devcompanion run-once`. Returns True if queued successfully.

    This avoids the subprocess-in-subprocess problem when running `loop run`
    from within an interactive LLM session (opencode, claude, etc.).
    """
    # Install gate into this process and persist gate metadata for the worker.
    gate_meta: dict[str, Any] = {}
    if meta is not None:
        env = _install_gate_into_environ(run_dir, meta)
        gate_meta = {
            "tier": str(meta.get("tier", "L1")),
            "allowlist": _as_str_list(meta.get("allowlist")),
            "deny": _as_str_list(meta.get("deny")),
            "verifier": str(meta.get("verifier") or ""),
            "run_dir": str(run_dir),
            "real_gh": env.get("LOOP_GATE_REAL_GH", ""),
        }

    job_id = f"loop-{loop_name}-{rid}"
    job = {
        "id": job_id,
        "created_at": utc_now(),
        "request": request,
        "repo_path": str(workspace_root()),
        "loop_run_dir": str(run_dir),
        "llm": True,
        "limits": {
            "timeout_sec": wall_timeout or 1800,
            "max_steps": 25,
        },
        "actions_allowed": ["plan_only"],
        "loop_gate": gate_meta,
    }

    job_file = _QUEUE_PENDING / f"{job_id}.job"
    try:
        job_file.parent.mkdir(parents=True, exist_ok=True)
        job_file.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
        log(f"Queued as devcompanion job: {job_id}")
        log(f"  Job file  : {job_file}")
        log(f"  Run dir   : {run_dir}")
        log("  Next step : the worker (systemd timer every 5m) will pick it up")
        log("  Or run    : devcompanion run-once  to process immediately")
        log("  Check     : devcompanion status")
        return True
    except OSError as e:
        warn(f"Could not queue devcompanion job: {e}")
        return False


# ── commands ──────────────────────────────────────────────────────────────────


def cmd_init(args: list[str]) -> int:
    """Scaffold a new loop from a starter template (#200)."""
    if not args or args[0] in ("-h", "--help"):
        err("Usage: agent-toolkit loop init <pattern> [--name <custom-name>]")
        print("\nAvailable patterns:")
        for t in list_templates():
            label = t.parent.name if t.name == "loop.yaml" else t.stem
            print(f"  {label}")
        return 0 if args and args[0] in ("-h", "--help") else 1

    pattern = args[0]
    loop_name = pattern
    i = 1
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            loop_name = args[i + 1]
            i += 2
        else:
            i += 1

    template_file = resolve_template(pattern)
    if template_file is None:
        err(f"Template '{pattern}' not found.")
        print("\nAvailable patterns:")
        for t in list_templates():
            label = t.parent.name if t.name == "loop.yaml" else t.stem
            print(f"  {label}")
        return 1

    text = template_file.read_text(encoding="utf-8")
    name_match = re.search(r"^name:\s+(\S+)", text, re.MULTILINE)
    if loop_name == pattern and name_match:
        loop_name = name_match.group(1)

    loop_dir = loops_dir() / loop_name
    if loop_dir.exists():
        warn(f"Loop '{loop_name}' already exists at {loop_dir}")
        return 1

    loop_dir.mkdir(parents=True)
    (loop_dir / "runs").mkdir()

    # Body of frontmatter: drop full-line comments from template YAML
    fm_lines = [
        line for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")
    ]
    # Ensure name matches instance directory
    rewritten: list[str] = []
    saw_name = False
    for line in fm_lines:
        if re.match(r"^name:\s+", line):
            rewritten.append(f"name: {loop_name}")
            saw_name = True
        else:
            rewritten.append(line)
    if not saw_name:
        rewritten.insert(0, f"name: {loop_name}")

    (loop_dir / "LOOP.md").write_text(
        "---\n" + "\n".join(rewritten) + "\n---\n\n"
        f"# {loop_name.replace('-', ' ').title()} Loop\n\n"
        "<!-- Describe the goal, constraints, and escalation rules here. -->\n",
        encoding="utf-8",
    )

    write_state_md(
        loop_dir,
        {
            "last_run": "never",
            "last_run_status": "not_run",
            "last_run_id": "",
            "runs_today": 0,
            "pending": [],
            "escalations": [],
        },
    )

    rel = loop_dir.relative_to(workspace_root())
    ok(f"Initialized loop '{loop_name}' at {rel}")
    print(f"\n  Edit {rel}/LOOP.md to customize.")
    print(f"  Then run: agent-toolkit loop run {loop_name}")
    return 0


def _normalize_runner_name(raw: str | None) -> str:
    """Return a canonical runner name or raise ValueError."""
    if raw is None or not str(raw).strip():
        return RUNNER_AUTO
    name = str(raw).strip().lower().replace("_", "-")
    name = RUNNER_ALIASES.get(name, name)
    if name == RUNNER_AUTO:
        return RUNNER_AUTO
    if name not in RUNNER_NAMES:
        known = ", ".join((RUNNER_AUTO,) + RUNNER_NAMES)
        raise ValueError(f"Unknown runner '{raw}'. Choose one of: {known}")
    return name


def _parse_run_args(args: list[str]) -> tuple[str, bool, bool, Path | None, str]:
    """Parse loop run argv into (loop_name, force, quiet, pack_path, runner)."""
    force = "--force" in args
    quiet = "--quiet" in args
    pack_path: Path | None = None
    runner_flag: str | None = None
    positional: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--pack" and i + 1 < len(args):
            pack_path = Path(args[i + 1]).expanduser()
            i += 2
            continue
        if args[i] == "--runner" and i + 1 < len(args):
            runner_flag = args[i + 1]
            i += 2
            continue
        if args[i].startswith("--runner="):
            runner_flag = args[i].split("=", 1)[1]
            i += 1
            continue
        if args[i].startswith("-"):
            i += 1
            continue
        positional.append(args[i])
        i += 1

    env_runner = os.environ.get("AGENT_TOOLKIT_LOOP_RUNNER", "").strip() or None
    runner = _normalize_runner_name(runner_flag if runner_flag is not None else env_runner)
    return positional[0] if positional else "", force, quiet, pack_path, runner


def _run_harness_runner_with_timeout(
    runner_mod: Any,
    job_file: Path,
    run_dir: Path,
    wall_timeout: int,
) -> None:
    """Invoke harness runner with a wall-clock timeout."""
    import threading

    exc_holder: list[BaseException] = []

    def _target() -> None:
        try:
            runner_mod.main(["--job", str(job_file), "--out", str(run_dir)])
        except BaseException as exc:  # noqa: BLE001
            exc_holder.append(exc)

    thread = threading.Thread(target=_target, daemon=True)
    thread.start()
    thread.join(timeout=wall_timeout)
    if thread.is_alive():
        raise subprocess.TimeoutExpired(["harness-runner", str(job_file)], wall_timeout)
    if exc_holder:
        raise exc_holder[0]


def _load_harness_runner_mod() -> Any | None:
    runner_dir = Path(
        os.environ.get("HARNESS_RUNNER_DIR", "")
        or Path.home() / ".local" / "share" / "agent-toolkit" / "runner"
    )
    if not runner_dir.is_dir():
        return None
    if str(runner_dir) not in sys.path:
        sys.path.insert(0, str(runner_dir))
    try:
        import dots_ai_devcompanion_runner as r  # type: ignore

        return r
    except ImportError:
        return None


def _try_harness_runner(
    prompt: str,
    run_dir: Path,
    rid: str,
    meta: dict[str, Any],
    *,
    wall_timeout: int,
) -> tuple[bool, bool]:
    """Run harness/devcompanion-runner. Returns (handled, budget_exhausted)."""
    runner_mod = _load_harness_runner_mod()
    if runner_mod is None:
        return False, False
    _install_gate_into_environ(run_dir, meta)
    try:
        job_file = run_dir / "job.json"
        job_file.write_text(
            json.dumps(
                {
                    "id": rid,
                    "created_at": utc_now(),
                    "request": prompt,
                    "loop_gate": {
                        "tier": str(meta.get("tier", "L1")),
                        "allowlist": _as_str_list(meta.get("allowlist")),
                        "deny": _as_str_list(meta.get("deny")),
                        "verifier": str(meta.get("verifier") or ""),
                        "run_dir": str(run_dir),
                    },
                    "limits": {"timeout_sec": wall_timeout},
                }
            ),
            encoding="utf-8",
        )
        _run_harness_runner_with_timeout(runner_mod, job_file, run_dir, wall_timeout)
        return True, False
    except subprocess.TimeoutExpired:
        warn(f"Run exceeded max_wall_seconds ({wall_timeout}s)")
        return True, True
    except Exception as e:
        err(f"Runner error: {e}")
        return True, False


def _write_skeleton_plan(
    plan_md: Path,
    *,
    loop_name: str,
    rid: str,
    tier: str,
    meta: dict[str, Any],
    reason: str,
) -> None:
    plan_md.write_text(
        f"# Loop Run: {loop_name}\n\n"
        f"**Run ID**: {rid}  \n"
        f"**Tier**: {tier}  \n"
        f"**Started**: {utc_now()}  \n\n"
        "## Goal\n\n"
        f"{meta.get('goal', '(no goal defined in LOOP.md)')}\n\n"
        "## Status\n\n"
        f"⚠ {reason}\n\n"
        "Options:\n"
        "  1. `agent-toolkit loop run <loop> --runner claude` (Claude Code CLI in PATH)\n"
        "  2. `--runner opencode` / `cursor` / `copilot` / `codex`\n"
        "  3. `--runner harness` with `HARNESS_RUNNER_DIR` set\n"
        "  4. `--runner queue` for async devcompanion processing\n"
        "See: `agent-toolkit loop help`\n",
        encoding="utf-8",
    )


def _dispatch_loop_runner(
    runner: str,
    *,
    prompt: str,
    run_dir: Path,
    rid: str,
    loop_name: str,
    meta: dict[str, Any],
    trace_file: Path,
    wall_timeout: int,
    token_limit: int | None,
    plan_md: Path,
    tier: str,
) -> tuple[bool, bool]:
    """Dispatch to the selected runner.

    Returns ``(queued, budget_exhausted)``.
    Raises ``RuntimeError`` for gate failures (caller maps to exit 2).
    Raises ``ValueError`` when an explicit runner is unavailable.
    """
    kwargs = dict(
        trace_file=trace_file,
        wall_timeout=wall_timeout,
        max_tokens=token_limit,
    )

    def _one(name: str) -> bool | None:
        """Return True if handled, False if unavailable, None if failed after attempt."""
        if name == "harness":
            handled, _budget = _try_harness_runner(
                prompt, run_dir, rid, meta, wall_timeout=wall_timeout
            )
            return handled
        if name == "claude":
            if not shutil.which("claude"):
                return False
            return True if _try_claude_runner(prompt, run_dir, meta, **kwargs) else None
        if name == "opencode":
            if not shutil.which("opencode"):
                return False
            return True if _try_opencode_runner(prompt, run_dir, meta, **kwargs) else None
        if name == "cursor":
            if _resolve_cursor_cli_bin() is None:
                return False
            return True if _try_cursor_runner(prompt, run_dir, meta, **kwargs) else None
        if name == "copilot":
            if _resolve_copilot_cli_bin() is None:
                return False
            return True if _try_copilot_runner(prompt, run_dir, meta, **kwargs) else None
        if name == "codex":
            if not shutil.which("codex"):
                return False
            return True if _try_codex_runner(prompt, run_dir, meta, **kwargs) else None
        if name == "queue":
            return (
                True
                if _queue_via_devcompanion(
                    prompt, run_dir, loop_name, rid, meta, wall_timeout=wall_timeout
                )
                else False
            )
        if name == "skeleton":
            _write_skeleton_plan(
                plan_md,
                loop_name=loop_name,
                rid=rid,
                tier=tier,
                meta=meta,
                reason="Skeleton runner requested (--runner skeleton).",
            )
            return True
        return False

    queued = False
    budget_exhausted = False

    if runner == RUNNER_AUTO:
        # Preserve prior semantics: if harness package is present, use it and
        # do not fall through to CLI runners on failure.
        if _load_harness_runner_mod() is not None:
            _handled, budget_exhausted = _try_harness_runner(
                prompt, run_dir, rid, meta, wall_timeout=wall_timeout
            )
            return False, budget_exhausted
        for name in ("claude", "opencode", "cursor", "copilot", "codex", "queue"):
            result = _one(name)
            if result is True:
                if name == "queue":
                    queued = True
                    log(
                        "Loop dispatched to devcompanion queue — "
                        "worker will process asynchronously."
                    )
                return queued, budget_exhausted
            # False = missing; None = attempted and failed → try next
            continue
        warn("No runner found — writing skeleton plan.md")
        if not _PROGRESS_QUIET:
            log("step: prepare skeleton plan")
        _write_skeleton_plan(
            plan_md,
            loop_name=loop_name,
            rid=rid,
            tier=tier,
            meta=meta,
            reason="No runner found.",
        )
        if not _PROGRESS_QUIET:
            log("step: skeleton plan written (no LLM runner available)")
            trace_file.write_text(
                trace_file.read_text(encoding="utf-8")
                + json.dumps(
                    {
                        "ts": utc_now(),
                        "kind": "progress",
                        "label": "skeleton",
                        "message": "plan.md written",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
        return False, False

    # Explicit runner — do not silently fall through.
    log(f"Using runner: {runner}")
    if runner == "harness":
        if _load_harness_runner_mod() is None:
            raise ValueError(
                "harness runner unavailable — set HARNESS_RUNNER_DIR to the "
                "dots-ai-devcompanion runner package"
            )
        _handled, budget_exhausted = _try_harness_runner(
            prompt, run_dir, rid, meta, wall_timeout=wall_timeout
        )
        return False, budget_exhausted

    result = _one(runner)
    if result is False:
        hints = {
            "claude": "install Claude Code CLI (`claude` on PATH)",
            "opencode": "install OpenCode (`opencode` on PATH)",
            "cursor": "install Cursor Agent CLI (`cursor-agent` / `agent` on PATH); set CURSOR_API_KEY",
            "copilot": "install GitHub Copilot CLI (`copilot` on PATH); set COPILOT_GITHUB_TOKEN",
            "codex": "install Codex CLI (`codex` on PATH); set OPENAI_API_KEY or CODEX_API_KEY",
            "queue": "ensure workspace queue dirs are writable (HARNESS_DC_HOME / workspace)",
        }
        raise ValueError(
            f"runner '{runner}' is not available — {hints.get(runner, 'check installation')}"
        )
    if result is None:
        raise ValueError(f"runner '{runner}' started but exited unsuccessfully")
    if runner == "queue":
        queued = True
        log("Loop dispatched to devcompanion queue — worker will process asynchronously.")
    return queued, budget_exhausted


def cmd_run(args: list[str]) -> int:
    """Execute one loop run.

    Usage: loop run <loop-name> [--force] [--quiet] [--pack PATH] [--runner NAME]
    """
    global _PROGRESS_QUIET

    usage = (
        "Usage: loop run <loop-name> [--force] [--quiet] [--pack PATH] [--runner NAME]\n"
        "  --runner  auto|harness|claude|opencode|cursor|copilot|codex|queue|skeleton\n"
        "  (default: auto, or $AGENT_TOOLKIT_LOOP_RUNNER)\n"
        "See: agent-toolkit loop help"
    )
    if not args:
        err(usage)
        return 1

    try:
        loop_name, force, quiet, pack_path, runner = _parse_run_args(args)
    except ValueError as exc:
        err(str(exc))
        return 1
    _PROGRESS_QUIET = quiet
    if not loop_name:
        err(usage)
        return 1

    loop_dir = resolve_loop_dir(loop_name)
    if loop_dir is None:
        err(f"Loop '{loop_name}' not found. Run: agent-toolkit loop init {loop_name}")
        return 1

    meta = parse_loop_md(loop_dir)

    if pack_path is not None:
        from agent_toolkit.loop.pack import (
            apply_loop_pack_overrides,
            load_pack,
            resolve_pack_path,
        )

        resolved = resolve_pack_path(pack_path, workspace_root())
        if resolved is None:
            err(f"Pack not found: {pack_path}")
            return 1
        pack_data = load_pack(resolved)
        meta = apply_loop_pack_overrides(meta, pack_data, loop_name)
        if meta.get("enabled") is False:
            warn(f"Loop '{loop_name}' disabled in pack {resolved.name}. Skipping.")
            return 0
        log(f"Pack overrides loaded from {resolved}")

    from agent_toolkit.loop.budget import (
        max_tokens_limit,
        soft_token_precheck,
        token_budget_exceeded,
        tokens_from_trace,
        wall_timeout_seconds,
    )

    tier = meta.get("tier", "L1")
    budget = meta.get("budget", {})
    if not isinstance(budget, dict):
        budget = {}
    max_runs = int(budget.get("max_runs_per_day", 10))
    wall_timeout = wall_timeout_seconds(budget)
    token_limit = max_tokens_limit(budget)

    # Load current state
    state_md = loop_dir / "STATE.md"
    state = {
        "last_run": "never",
        "last_run_status": "not_run",
        "last_run_id": "",
        "runs_today": 0,
        "pending": [],
        "escalations": [],
    }
    if state_md.exists():
        loaded = parse_state_md(loop_dir)
        state.update(loaded)

    # Budget gate: check runs_today
    runs_today = int(state.get("runs_today", 0) or 0)
    last_run_ts = state.get("last_run", "never")
    if last_run_ts not in (None, "never", ""):
        try:
            # PyYAML may parse ISO timestamps as datetime objects
            if hasattr(last_run_ts, "isoformat"):
                last_dt = (
                    last_run_ts if last_run_ts.tzinfo else last_run_ts.replace(tzinfo=timezone.utc)
                )
            else:
                last_dt = datetime.fromisoformat(str(last_run_ts).replace("Z", "+00:00"))
            today = datetime.now(timezone.utc).date()
            if last_dt.date() != today:
                runs_today = 0  # Reset on new day
        except (ValueError, TypeError, AttributeError):
            runs_today = 0

    if runs_today >= max_runs and not force:
        warn(f"Budget: max_runs_per_day ({max_runs}) reached for today. Skipping.")
        warn("  Re-run with: agent-toolkit loop run <loop> --force")
        return 0
    if force and runs_today >= max_runs:
        warn(f"Budget gate bypassed via --force (runs_today={runs_today}, max={max_runs})")

    precheck_msg = soft_token_precheck(state, budget)
    if precheck_msg:
        warn(f"Budget: {precheck_msg}")

    log(
        f"Budget: max_wall_seconds={wall_timeout}, "
        f"max_tokens={token_limit if token_limit is not None else 'unset'}"
    )

    # Create run directory
    rid = run_id()
    run_dir = loop_dir / "runs" / rid
    run_dir.mkdir(parents=True)

    log(f"Starting run {rid} for '{loop_name}' (tier={tier})")
    log(f"Run artifacts: {run_dir.relative_to(workspace_root())}")
    allow = _as_str_list(meta.get("allowlist"))
    deny = _as_str_list(meta.get("deny"))
    log(
        f"Autonomy: allow=[{', '.join(allow) or '∅'}] "
        f"deny=[{', '.join(deny) or '∅'}] "
        f"verifier={meta.get('verifier') or 'none'}"
    )

    # Write initial trace entry with AGENTS.md spec hash
    agents_md = workspace_root() / "AGENTS.md"
    agents_md_hash = (
        hashlib.sha256(agents_md.read_bytes()).hexdigest()[:12] if agents_md.exists() else "?"
    )

    trace_file = run_dir / "trace.jsonl"
    trace_file.write_text(
        json.dumps(
            {
                "ts": utc_now(),
                "kind": "run_start",
                "run_id": rid,
                "tier": tier,
                "allowlist": allow,
                "deny": deny,
                "verifier": meta.get("verifier"),
                "agents_md_hash": agents_md_hash,
                "force": force,
                "runner": runner,
                "max_wall_seconds": wall_timeout,
                "max_tokens": token_limit,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    # Create git worktree (if in a git repo)
    worktree_path: Path | None = None
    if (
        subprocess.run(
            ["git", "-C", str(workspace_root()), "rev-parse", "--git-dir"],
            capture_output=True,
        ).returncode
        == 0
    ):
        worktree_base = WORKTREES_HOME / loop_name / rid
        worktree_base.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            ["git", "-C", str(workspace_root()), "worktree", "add", str(worktree_base), "HEAD"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            worktree_path = worktree_base
            log(f"Worktree: {worktree_path}")
            trace_file.write_text(
                trace_file.read_text(encoding="utf-8")
                + json.dumps(
                    {"ts": utc_now(), "kind": "worktree_created", "path": str(worktree_path)}
                )
                + "\n",
                encoding="utf-8",
            )
        else:
            warn(f"Could not create worktree (non-fatal): {result.stderr.strip()}")

    # Check cancellation before dispatching
    if _CANCELLED:
        warn("Run cancelled before dispatch")
        finalize_run(loop_dir, run_dir, rid, worktree_path, trace_file, "cancelled")
        return 1

    # Dispatch to selected runner (auto chain or --runner NAME)
    plan_md = run_dir / "plan.md"
    prompt = _build_runner_prompt(loop_dir, meta, loop_name, run_dir)
    # Persist the exact prompt for audit / autonomy debugging
    (run_dir / "prompt.md").write_text(prompt, encoding="utf-8")

    queued = False
    budget_exhausted = False
    try:
        queued, budget_exhausted = _dispatch_loop_runner(
            runner,
            prompt=prompt,
            run_dir=run_dir,
            rid=rid,
            loop_name=loop_name,
            meta=meta,
            trace_file=trace_file,
            wall_timeout=wall_timeout,
            token_limit=token_limit,
            plan_md=plan_md,
            tier=tier,
        )
    except ValueError as runner_exc:
        err(str(runner_exc))
        finalize_run(loop_dir, run_dir, rid, worktree_path, trace_file, "runner_unavailable")
        return 1
    except RuntimeError as gate_exc:
        err(str(gate_exc))
        finalize_run(loop_dir, run_dir, rid, worktree_path, trace_file, "gate_failed")
        return 2

    tokens_used = tokens_from_trace(trace_file)
    if token_budget_exceeded(tokens_used, budget):
        budget_exhausted = True
        warn(f"Run exceeded max_tokens ({token_limit:,}); recorded {tokens_used:,} in trace")

    if budget_exhausted:
        trace_file.write_text(
            trace_file.read_text(encoding="utf-8")
            + json.dumps(
                {
                    "ts": utc_now(),
                    "kind": "budget_exhausted",
                    "tokens_used": tokens_used,
                    "max_wall_seconds": wall_timeout,
                    "max_tokens": token_limit,
                }
            )
            + "\n",
            encoding="utf-8",
        )

    # Update state — preserve pending/escalations/notes the agent wrote (or prior)
    if budget_exhausted:
        run_status = "partial (budget_exhausted)"
    else:
        run_status = "queued" if queued else "completed"
    post = parse_state_md(loop_dir) if state_md.exists() else {}
    new_state: dict[str, Any] = {
        "last_run": utc_now(),
        "last_run_status": run_status,
        "last_run_id": rid,
        "runs_today": runs_today + 1,
        "last_run_tokens": tokens_used,
    }
    # Prefer agent-updated lists when present; otherwise keep prior
    for key in ("pending", "escalations", "notes"):
        if key in post and post[key] is not None:
            new_state[key] = post[key]
        elif key in state and state[key] is not None:
            new_state[key] = state[key]
        elif key in ("pending", "escalations"):
            new_state[key] = []
    if queued:
        queued_pending = list(_as_str_list(new_state.get("pending")))
        queued_pending.append(f"devcompanion:loop-{loop_name}-{rid}")
        new_state["pending"] = queued_pending
    write_state_md(loop_dir, new_state)

    # For queued runs, add trace entry and clean up worktree
    if queued:
        trace_file.write_text(
            trace_file.read_text(encoding="utf-8")
            + json.dumps({"ts": utc_now(), "kind": "queued", "job_id": f"loop-{loop_name}-{rid}"})
            + "\n",
            encoding="utf-8",
        )
        # Clean up worktree — the devcompanion worker runs independently
        if worktree_path and worktree_path.is_dir():
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(workspace_root()),
                    "worktree",
                    "remove",
                    str(worktree_path),
                    "--force",
                ],
                capture_output=True,
            )
        ok(f"Run {rid} queued for async processing. State: {run_status}")
        ok("  Check later with: devcompanion status")
        return 0

    # Cleanup worktree on inline completion
    if worktree_path and worktree_path.is_dir():
        subprocess.run(
            [
                "git",
                "-C",
                str(workspace_root()),
                "worktree",
                "remove",
                str(worktree_path),
                "--force",
            ],
            capture_output=True,
        )

    finalize_run(
        loop_dir,
        run_dir,
        rid,
        worktree_path,
        trace_file,
        "budget_exhausted" if budget_exhausted else "completed",
    )
    return 1 if budget_exhausted else 0


def finalize_run(
    loop_dir: Path,
    run_dir: Path,
    rid: str,
    worktree_path: Path | None,
    trace_file: Path,
    status: str,
) -> None:
    """Clean up worktree, finalize trace, and close the loop."""
    global _CANCELLED
    if _CANCELLED and status != "cancelled":
        status = "cancelled"

    # Cleanup worktree
    if worktree_path and worktree_path.is_dir():
        subprocess.run(
            [
                "git",
                "-C",
                str(workspace_root()),
                "worktree",
                "remove",
                str(worktree_path),
                "--force",
            ],
            capture_output=True,
        )

    # Finalize trace
    trace_file.write_text(
        trace_file.read_text(encoding="utf-8")
        + json.dumps({"ts": utc_now(), "kind": "run_end", "status": status})
        + "\n",
        encoding="utf-8",
    )

    if status == "completed":
        # Loop closure: extract learning events from trace and sync to knowledge
        _close_loop(run_dir, rid)
        ok(f"Run {rid} complete. Artifacts at: {run_dir.relative_to(workspace_root())}")
    else:
        warn(f"Run {rid} finished with status: {status}")


def _close_loop(run_dir: Path, rid: str) -> None:
    """Extract learning/decision events from trace and sync to knowledge."""
    trace_file = run_dir / "trace.jsonl"
    if not trace_file.exists():
        return

    added = 0
    for line in trace_file.read_text(encoding="utf-8").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("kind") == "decision" and event.get("tag") == "learning":
            content = event.get("content", "")
            if content:
                add_script = workspace_root() / "bin" / "assistant-memory"
                if add_script.exists():
                    subprocess.run(
                        [
                            sys.executable,
                            str(add_script),
                            "add",
                            "--type",
                            "learning",
                            "--from-loop",
                            rid,
                            content,
                        ],
                        capture_output=True,
                    )
                    added += 1
        if event.get("kind") == "run_start":
            event.get("run_id", rid)

    if added:
        ok(f"Synced {added} learning event(s) from run {rid} to knowledge base")


def cmd_status(args: list[str]) -> int:
    """Show loop status."""
    target = args[0] if args else None
    if target:
        loops = [resolve_loop_dir(target)]
    else:
        loops = list_loops()
        # No user instances yet — show bundled templates so uvx/pip installs
        # still discover the 10 reference loops (validate.yml uvx job).
        if not loops:
            bundled = toolkit_loops_dir()
            if bundled.is_dir():
                loops = [
                    d
                    for d in sorted(bundled.iterdir())
                    if d.is_dir() and ((d / "loop.yaml").exists() or (d / "LOOP.md").exists())
                ]

    if not loops:
        print("No loops found. Run: agent-toolkit loop init <pattern>")
        return 0

    print("")
    print(blue("── Loop Status ──────────────────────────────────────────"))
    for loop_dir in loops:
        if not loop_dir.exists():
            err(f"Loop '{loop_dir.name}' not found.")
            continue
        meta = parse_loop_md(loop_dir)
        tier = meta.get("tier", "?")
        cadence = meta.get("cadence", "?")
        runs = list(sorted((loop_dir / "runs").glob("*"))) if (loop_dir / "runs").is_dir() else []
        state_file = loop_dir / "STATE.md"
        last_status = "not_run"
        if state_file.exists():
            # Read STATE.md directly (parse_loop_md would read LOOP.md)
            state_text = state_file.read_text(encoding="utf-8")
            lines = state_text.splitlines()
            # Extract frontmatter
            if lines and lines[0].strip() == "---":
                end = next(
                    (i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None
                )
                if end:
                    for line in lines[1:end]:
                        if line.strip().startswith("last_run_status:"):
                            last_status = line.split(":", 1)[1].strip()
                            break
        print(
            f"  {dim(loop_dir.name):<35} tier={tier}  cadence={cadence}  "
            f"runs={len(runs)}  last={last_status}"
        )
    print("")
    return 0


def cmd_audit(args: list[str]) -> int:
    """Summarize past runs."""
    target = args[0] if args else None
    loops = [resolve_loop_dir(target)] if target else list_loops()

    print("")
    print(blue("── Loop Audit ───────────────────────────────────────────"))
    for loop_dir in loops:
        if not loop_dir.exists():
            continue
        runs_dir = loop_dir / "runs"
        if not runs_dir.is_dir():
            continue
        runs = sorted(runs_dir.iterdir())
        if not runs:
            print(f"\n  {loop_dir.name}: no runs yet")
            continue

        completed = 0
        failed = 0
        total_tokens = 0

        for run in runs:
            trace = run / "trace.jsonl"
            if not trace.exists():
                continue
            for line in trace.read_text(encoding="utf-8").splitlines():
                try:
                    event = json.loads(line)
                    if event.get("kind") == "run_end":
                        if event.get("status") == "completed":
                            completed += 1
                        else:
                            failed += 1
                    if event.get("kind") in ("prompt", "completion"):
                        total_tokens += event.get("prompt_tokens", 0)
                        total_tokens += event.get("completion_tokens", 0)
                except json.JSONDecodeError:
                    pass

        total = completed + failed
        rate = f"{completed / total * 100:.0f}%" if total else "—"
        print(
            f"\n  {dim(loop_dir.name)}\n"
            f"    runs={total}  success={completed}  failed={failed}  "
            f"rate={rate}  tokens≈{total_tokens:,}"
        )

    print("")
    return 0


def cmd_cost(args: list[str]) -> int:
    """Estimate cost for one run."""
    if not args:
        err("Usage: loop cost <loop-name>")
        return 1

    loop_name = args[0]
    loop_dir = resolve_loop_dir(loop_name)
    if loop_dir is None:
        err(f"Loop '{loop_name}' not found. Run: agent-toolkit loop init {loop_name}")
        return 1
    meta = parse_loop_md(loop_dir) if loop_dir.exists() else {}

    tier = meta.get("tier", "L1")
    budget = meta.get("budget", {})
    max_tokens = budget.get("max_tokens", "?")
    cadence = meta.get("cadence", "?")

    cost_tiers = {
        "daily-triage": ("low", "~$0.01-0.05"),
        "issue-triage": ("low", "~$0.01-0.05"),
        "changelog-drafter": ("low", "~$0.01-0.05"),
        "post-merge-cleanup": ("low", "~$0.01-0.05"),
        "dep-sweeper": ("medium", "~$0.05-0.20"),
        "pr-babysitter": ("high", "~$0.20-1.00/run"),
        "ci-sweeper": ("very-high", "~$0.50-2.00/run"),
    }
    tier_label, est = cost_tiers.get(loop_name, ("unknown", "—"))

    print(f"\n  Loop: {loop_name}")
    print(f"  Tier: {tier}")
    print(f"  Cadence: {cadence}")
    print(f"  Budget max_tokens: {max_tokens}")
    print(f"  Cost tier: {tier_label}")
    print(f"  Estimated per run: {est}")
    print("")
    return 0


def cmd_schedule(args: list[str]) -> int:
    """Install or manage OS-level timer for a loop."""
    list_mode = "--list" in args
    remove_mode = "--remove" in args
    status_mode = "--status" in args
    dry_run = "--dry-run" in args
    cron_override = None

    # Extract --cron value
    for i, a in enumerate(args):
        if a == "--cron" and i + 1 < len(args):
            cron_override = args[i + 1]
            break
        if a.startswith("--cron="):
            cron_override = a.split("=", 1)[1]
            break

    # --list: show all scheduled loops
    if list_mode:
        return _schedule_list()
    if status_mode:
        return _schedule_status()

    # --remove: remove schedule for a loop
    if remove_mode:
        loop_name = next((a for a in args if not a.startswith("-") and a != "schedule"), None)
        if not loop_name:
            err("Usage: agent-toolkit loop schedule <name> --remove")
            return 1
        return _schedule_remove(loop_name, dry_run)

    # schedule <name>: install timer
    loop_name = next((a for a in args if not a.startswith("-") and a != "schedule"), None)
    if not loop_name:
        err("Usage: agent-toolkit loop schedule <name> [--cron EXPR] [--dry-run]")
        return 1

    loop_dir = resolve_loop_dir(loop_name)
    if loop_dir is None:
        err(f"Loop '{loop_name}' not found. Run: agent-toolkit loop init {loop_name}")
        return 1
    if not loop_dir.is_dir():
        err(f"Loop not found: {loop_name} (run 'agent-toolkit loop init {loop_name}' first)")
        return 1

    loopyaml = loop_dir / "LOOP.md"
    if not loopyaml.exists():
        err(f"LOOP.md not found in {loop_dir}")
        return 1

    loop_cfg = parse_loop_md(loopyaml)
    cron = cron_override or loop_cfg.get("schedule", "daily")

    if dry_run:
        log(f"[DRY-RUN] Would schedule: {loop_name}")
        log(f"  Cron: {cron}")
        return _schedule_dry_run(loop_name, cron)

    return _schedule_install(loop_name, cron)


def _schedule_dry_run(loop_name: str, cron: str) -> int:
    """Print timer files without installing."""
    system = platform.system()
    harness_dir = workspace_root()
    loop_cmd = f"{harness_dir}/bin/loop run {loop_name}"

    print(f"\n{blue('[loop]')} Would schedule: {loop_name}")
    print(f"  Cron: {cron}")
    print(f"  Command: {loop_cmd}")
    print()

    if system == "Linux":
        svc = _systemd_service(loop_name, loop_cmd)
        timer = _systemd_timer(loop_name, cron)
        print(dim("--- systemd service (would create) ---"))
        print(svc)
        print(dim("--- systemd timer (would create) ---"))
        print(timer)
        print(dim(f"Would enable: systemctl --user enable agent-toolkit-{loop_name}.timer"))
        print(dim(f"Would start:  systemctl --user start agent-toolkit-{loop_name}.timer"))
    elif system == "Darwin":
        plist = _launchd_plist(loop_name, cron)
        print(dim("--- launchd plist (would create) ---"))
        print(plist)
        print(
            dim(
                f"Would load: launchctl load ~/Library/LaunchAgents/com.agent-toolkit.{loop_name}.plist"
            )
        )
    else:
        print(yellow(f"Manual scheduling required on {system}:"))
        print(f"  {loop_cmd}")
        print(f"  Schedule: {cron}")
        print()

    return 0


def _schedule_install(loop_name: str, cron: str) -> int:
    """Install systemd timer (Linux) or launchd plist (macOS)."""
    system = platform.system()
    harness_dir = workspace_root()
    loop_cmd = f"{harness_dir}/bin/loop run {loop_name}"

    if system == "Linux":
        systemd_user = Path.home() / ".config" / "systemd" / "user"
        systemd_user.mkdir(parents=True, exist_ok=True)

        svc_path = systemd_user / f"agent-toolkit-{loop_name}.service"
        timer_path = systemd_user / f"agent-toolkit-{loop_name}.timer"

        svc_path.write_text(_systemd_service(loop_name, loop_cmd), encoding="utf-8")
        timer_path.write_text(_systemd_timer(loop_name, cron), encoding="utf-8")

        ok(f"Created: {svc_path}")
        ok(f"Created: {timer_path}")

        # Enable and start
        try:
            subprocess.run(
                ["systemctl", "--user", "enable", f"agent-toolkit-{loop_name}.timer"],
                capture_output=True,
                text=True,
                check=False,
            )
            subprocess.run(
                ["systemctl", "--user", "start", f"agent-toolkit-{loop_name}.timer"],
                capture_output=True,
                text=True,
                check=False,
            )
            ok(f"Enabled and started: agent-toolkit-{loop_name}.timer")
        except Exception as e:
            warn(f"Could not enable timer: {e}")
            ok(
                "Timer files created manually — enable with: systemctl --user enable agent-toolkit-{loop_name}.timer"
            )

        return 0

    elif system == "Darwin":
        launchd_dir = Path.home() / "Library" / "LaunchAgents"
        launchd_dir.mkdir(parents=True, exist_ok=True)

        plist_path = launchd_dir / f"com.agent-toolkit.{loop_name}.plist"
        plist_path.write_text(_launchd_plist(loop_name, cron), encoding="utf-8")

        ok(f"Created: {plist_path}")

        try:
            subprocess.run(
                ["launchctl", "load", str(plist_path)],
                capture_output=True,
                text=True,
                check=False,
            )
            ok(f"Loaded: com.agent-toolkit.{loop_name}")
        except Exception as e:
            warn(f"Could not load plist: {e}")
            ok(
                f"Plist created — load with: launchctl load ~/Library/LaunchAgents/com.agent-toolkit.{loop_name}.plist"
            )

        return 0

    else:
        print(f"\n{yellow('Manual scheduling required on ' + system + ':')}")
        print(f"  Command: {loop_cmd}")
        print(f"  Schedule: {cron}")
        print()
        return 0


def _schedule_list() -> int:
    """List all scheduled loops."""
    system = platform.system()
    loops = []
    if system == "Linux":
        systemd_user = Path.home() / ".config" / "systemd" / "user"
        for p in sorted(systemd_user.glob("agent-toolkit-*.timer")):
            name = p.stem.replace("agent-toolkit-", "").replace(".timer", "")
            loops.append(name)
    elif system == "Darwin":
        launchd_dir = Path.home() / "Library" / "LaunchAgents"
        for p in sorted(launchd_dir.glob("com.agent-toolkit.*.plist")):
            name = p.stem.replace("com.agent-toolkit.", "")
            loops.append(name)

    if not loops:
        print(dim("No scheduled loops found."))
        return 0

    print(f"\n{blue('[loop]')} Scheduled loops:")
    for name in loops:
        enabled = _schedule_enabled(name)
        enabled_str = green("enabled") if enabled else yellow("disabled")
        print(f"  {name:30s} {enabled_str}")
    print()
    return 0


def _schedule_status() -> int:
    """Check schedule health."""
    system = platform.system()
    issues = []
    if system == "Linux":
        systemd_user = Path.home() / ".config" / "systemd" / "user"
        for p in sorted(systemd_user.glob("agent-toolkit-*.timer")):
            name = p.stem.replace("agent-toolkit-", "").replace(".timer", "")
            # Check if timer is active
            result = subprocess.run(
                ["systemctl", "--user", "is-active", f"agent-toolkit-{name}.timer"],
                capture_output=True,
                text=True,
                check=False,
            )
            status = result.stdout.strip()
            if status != "active":
                issues.append(f"{name}: {status}")
    elif system == "Darwin":
        launchd_dir = Path.home() / "Library" / "LaunchAgents"
        for p in sorted(launchd_dir.glob("com.agent-toolkit.*.plist")):
            name = p.stem.replace("com.agent-toolkit.", "")
            result = subprocess.run(
                ["launchctl", "list", f"com.agent-toolkit.{name}"],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0:
                issues.append(f"{name}: not loaded")

    if issues:
        print(f"\n{yellow('[loop]')} Schedule issues:")
        for issue in issues:
            print(f"  {yellow('!')} {issue}")
        print()
    else:
        ok("All schedules healthy.")
    return 0


def _schedule_remove(loop_name: str, dry_run: bool) -> int:
    """Remove schedule for a loop."""
    system = platform.system()
    if system == "Linux":
        systemd_user = Path.home() / ".config" / "systemd" / "user"
        svc = systemd_user / f"agent-toolkit-{loop_name}.service"
        timer = systemd_user / f"agent-toolkit-{loop_name}.timer"

        if dry_run:
            log(f"[DRY-RUN] Would remove: {svc}")
            log(f"[DRY-RUN] Would remove: {timer}")
            return 0

        # Stop and disable first
        subprocess.run(
            ["systemctl", "--user", "stop", f"agent-toolkit-{loop_name}.timer"],
            capture_output=True,
            text=True,
            check=False,
        )
        subprocess.run(
            ["systemctl", "--user", "disable", f"agent-toolkit-{loop_name}.timer"],
            capture_output=True,
            text=True,
            check=False,
        )
        svc.unlink(missing_ok=True)
        timer.unlink(missing_ok=True)
        ok(f"Removed schedule: {loop_name}")

    elif system == "Darwin":
        plist = Path.home() / "Library" / "LaunchAgents" / f"com.agent-toolkit.{loop_name}.plist"
        if dry_run:
            log(f"[DRY-RUN] Would remove: {plist}")
            return 0

        subprocess.run(
            ["launchctl", "unload", str(plist)],
            capture_output=True,
            text=True,
            check=False,
        )
        plist.unlink(missing_ok=True)
        ok(f"Removed schedule: {loop_name}")

    else:
        warn(f"Manual removal required on {system}.")

    return 0


def _schedule_enabled(loop_name: str) -> bool:
    """Check if a loop timer is enabled."""
    system = platform.system()
    if system == "Linux":
        result = subprocess.run(
            ["systemctl", "--user", "is-enabled", f"agent-toolkit-{loop_name}.timer"],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.stdout.strip() == "enabled"
    elif system == "Darwin":
        plist = Path.home() / "Library" / "LaunchAgents" / f"com.agent-toolkit.{loop_name}.plist"
        if not plist.exists():
            return False
        result = subprocess.run(
            ["launchctl", "list", f"com.agent-toolkit.{loop_name}"],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode == 0
    return False


def _systemd_service(loop_name: str, exec_cmd: str) -> str:
    """Generate systemd service file content."""
    return f"""[Unit]
Description=agent-toolkit loop: {loop_name}
After=network-online.target

[Service]
Type=oneshot
ExecStart={exec_cmd}
StandardOutput=journal
StandardError=journal
"""


def _systemd_timer(loop_name: str, cron: str) -> str:
    """Generate systemd timer file content."""
    on_calendar = cron
    # Convert common patterns to systemd OnCalendar format
    if cron == "hourly":
        on_calendar = "*-*-* *:00:00"
    elif cron == "daily":
        on_calendar = "*-*-* 09:00:00"
    elif cron == "weekly":
        on_calendar = "Mon *-*-* 09:00:00"

    return f"""[Unit]
Description=agent-toolkit loop timer: {loop_name}

[Timer]
OnCalendar={on_calendar}
Persistent=true

[Install]
WantedBy=timers.target
"""


def _launchd_plist(loop_name: str, cron: str) -> str:
    """Generate launchd plist content."""
    interval = 86400  # daily default
    if cron == "hourly":
        interval = 3600
    elif cron == "weekly":
        interval = 604800

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agent-toolkit.{loop_name}</string>
    <key>ProgramArguments</key>
    <array>
        <string>{workspace_root()}/bin/loop</string>
        <string>run</string>
        <string>{loop_name}</string>
    </array>
    <key>StartInterval</key>
    <integer>{interval}</integer>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
"""


def cmd_sync() -> int:
    """Regenerate knowledge todos from completed loop runs."""
    knowledge_todos = workspace_root() / "knowledge" / "todos" / "pending.md"
    if not loops_dir().is_dir():
        return 0

    entries = []
    for loop_dir in sorted(loops_dir().iterdir()):
        if not (loop_dir / "STATE.md").exists():
            continue
        state = parse_state_md(loop_dir)
        escalations = state.get("escalations", []) or []
        for esc in escalations:
            entries.append(f"- [ ] [loop-escalation] {loop_dir.name}: {esc}")

    if entries and knowledge_todos.exists():
        existing = knowledge_todos.read_text(encoding="utf-8")
        header = "<!-- loop-escalations -->"
        block = "\n".join(entries) + "\n"
        if header in existing:
            existing = re.sub(
                r"<!-- loop-escalations -->.*?<!-- /loop-escalations -->",
                f"{header}\n{block}<!-- /loop-escalations -->",
                existing,
                flags=re.DOTALL,
            )
        else:
            existing += f"\n{header}\n{block}<!-- /loop-escalations -->\n"
        knowledge_todos.write_text(existing, encoding="utf-8")
        ok(
            f"Synced {len(entries)} escalation(s) to {knowledge_todos.relative_to(workspace_root())}"
        )

    return 0


# ── main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        sys.exit(0)

    command = argv[0]
    rest = argv[1:]

    match command:
        case "init":
            sys.exit(cmd_init(rest))
        case "run":
            sys.exit(cmd_run(rest))
        case "status":
            sys.exit(cmd_status(rest))
        case "audit":
            sys.exit(cmd_audit(rest))
        case "cost":
            sys.exit(cmd_cost(rest))
        case "schedule":
            sys.exit(cmd_schedule(rest))
        case "sync":
            sys.exit(cmd_sync())
        case "templates":
            for t in list_templates():
                print(f"  {t.stem}")
        case _:
            err(f"Unknown command: {command}")
            print("Run 'agent-toolkit loop help' for usage.")
            sys.exit(1)


if __name__ == "__main__":
    main()
