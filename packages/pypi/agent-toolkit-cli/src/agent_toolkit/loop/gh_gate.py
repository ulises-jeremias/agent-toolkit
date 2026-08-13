#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
bin/loop-gh-gate — Hard autonomy gate for `gh` during loop runs.

Installed on PATH as a `gh` shim while a loop runner is active. Intercepts
mutating GitHub CLI commands and enforces LOOP.md allowlist / deny / tier
rules. Merge and close additionally require a verifier receipt under the
active run directory.

Environment (set by agent-toolkit loop / install_gh_shim):
  LOOP_GATE_REAL_GH       Absolute path to the real `gh` binary
  LOOP_GATE_RUN_DIR       Active run artifacts directory
  LOOP_GATE_TIER          L1 | L2 | L3
  LOOP_GATE_ALLOWLIST     Comma-separated allowlisted actions
  LOOP_GATE_DENY          Comma-separated denied actions
  LOOP_GATE_VERIFIER      Verifier skill/agent name (optional)
  LOOP_GATE_RECEIPT_SECRET  If set, verifier receipts must carry a matching HMAC
  LOOP_GATE_DISABLED      If "1", pass through without checks (tests only)
  LOOP_GATE_ATTRIBUTION   "1" (default) or "0" to disable comment attribution
  LOOP_GATE_LOOP_NAME     Loop name for attribution footer (optional)
  LOOP_GATE_GITHUB_LOGIN  Authenticated GitHub login (optional; resolved at install)
  LOOP_GATE_ATTRIBUTION_TEMPLATE  Optional custom prefix template with
                                  {login} and {loop} placeholders

Usage (normally via shim):
  loop-gh-gate -- pr merge 123 --repo owner/repo --squash
  loop-gh-gate --classify pr merge 123 --repo owner/repo
  loop-gh-gate --check-receipt merge --repo owner/repo --number 123
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Actions that mutate GitHub state and must be gated.
MUTATING_ACTIONS = frozenset(
    {
        "merge",
        "close",
        "comment",
        "label",
        "assign",
        "approve",
        "push",
        "commit",
        "force-push",
        "delete",
    }
)

# Merge/close always need a verifier receipt at L2+ (and are denied at L1).
RECEIPT_REQUIRED = frozenset({"merge", "close"})

# Max age for a verifier receipt (seconds).
RECEIPT_MAX_AGE_SEC = 3600

# Outbound prose posted via gh that should carry AI attribution (default ON).
ATTRIBUTION_ACTIONS = frozenset({"comment"})

ATTRIBUTION_MARKER = "> 🤖 AI-assisted"

DEFAULT_ATTRIBUTION_TEMPLATE = (
    "> 🤖 AI-assisted message posted as `@{login}` by "
    "[agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit)"
    "{loop_suffix}."
)

AGENT_TOOLKIT_REPO_URL = "https://github.com/ulises-jeremias/agent-toolkit"


def _split_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return [p.strip() for p in value.split(",") if p.strip()]


def _env_flag_enabled(name: str, *, default: bool = True) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    return raw.strip().lower() not in {"0", "false", "no", "off"}


def gate_config_from_env() -> dict[str, Any]:
    return {
        "real_gh": os.environ.get("LOOP_GATE_REAL_GH", ""),
        "run_dir": Path(os.environ["LOOP_GATE_RUN_DIR"])
        if os.environ.get("LOOP_GATE_RUN_DIR")
        else None,
        "tier": (os.environ.get("LOOP_GATE_TIER") or "L1").upper(),
        "allowlist": _split_csv(os.environ.get("LOOP_GATE_ALLOWLIST")),
        "deny": _split_csv(os.environ.get("LOOP_GATE_DENY")),
        "verifier": os.environ.get("LOOP_GATE_VERIFIER") or "",
        "receipt_secret": os.environ.get("LOOP_GATE_RECEIPT_SECRET") or "",
        "disabled": os.environ.get("LOOP_GATE_DISABLED") == "1",
        "attribution_enabled": _env_flag_enabled("LOOP_GATE_ATTRIBUTION", default=True),
        "loop_name": os.environ.get("LOOP_GATE_LOOP_NAME") or "",
        "github_login": os.environ.get("LOOP_GATE_GITHUB_LOGIN") or "",
        "attribution_template": os.environ.get("LOOP_GATE_ATTRIBUTION_TEMPLATE") or "",
    }


_SENSITIVE_FLAGS = frozenset(
    {
        "-H",
        "--header",
        "-b",
        "--body",
        "--body-file",
        "-F",
        "-f",
        "--raw-field",
        "--field",
        "--input",
        "-i",
        "--jq",
    }
)


def redact_argv(argv: list[str]) -> list[str]:
    """Return argv with secret-bearing values replaced by <redacted>."""
    out: list[str] = []
    skip_next = False
    for a in argv:
        if skip_next:
            out.append("<redacted>")
            skip_next = False
            continue
        if a in _SENSITIVE_FLAGS:
            out.append(a)
            skip_next = True
            continue
        if "=" in a and a.startswith("-"):
            flag, _, _val = a.partition("=")
            # Redact inline sensitive values (Authorization headers, body=, etc.)
            low = flag.lower()
            if any(s in low for s in ("header", "body", "field", "input", "token", "auth")):
                out.append(f"{flag}=<redacted>")
                continue
        out.append(a)
    return out


def classify_gh_argv(argv: list[str]) -> tuple[str | None, dict[str, Any]]:
    """Classify a `gh` argv into an action + metadata.

    Returns (action_or_None_if_readonly, meta).
    Unknown mutating forms return a gated action (typically ``push``) rather
    than falling through as read-only.
    """
    args = [a for a in argv if a != "--"]
    meta: dict[str, Any] = {"repo": None, "number": None, "raw": list(args)}

    if not args:
        return None, meta

    # Collect --repo / -R anywhere in argv (gh accepts them mid-command).
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("-R", "--repo") and i + 1 < len(args):
            meta["repo"] = args[i + 1]
            i += 2
            continue
        if a.startswith("--repo="):
            meta["repo"] = a.split("=", 1)[1]
            i += 1
            continue
        i += 1

    # Strip leading global flags for subcommand detection.
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("-R", "--repo") and i + 1 < len(args):
            i += 2
            continue
        if a.startswith("--repo="):
            i += 1
            continue
        break

    rest = args[i:]
    if not rest:
        return None, meta

    # gh pr ...
    if rest[0] == "pr" and len(rest) >= 2:
        sub = rest[1]
        if len(rest) >= 3 and rest[2].isdigit():
            meta["number"] = int(rest[2])
        if sub == "merge":
            return "merge", meta
        if sub == "close":
            return "close", meta
        if sub == "comment":
            return "comment", meta
        if sub == "create":
            return "push", meta  # opening a PR is a write
        if sub == "review":
            joined = " ".join(rest)
            if "--approve" in rest or " --approve" in f" {joined}":
                return "approve", meta
            return "comment", meta  # request-changes / comment reviews
        if sub == "edit":
            if "--add-label" in rest or "--remove-label" in rest:
                return "label", meta
            if "--add-assignee" in rest or "--remove-assignee" in rest:
                return "assign", meta
            # title/body/base/state edits are mutating but not label/assign
            if any(
                f in rest or any(a.startswith(f"{f}=") for a in rest)
                for f in ("--title", "--body", "--body-file", "--base", "--state")
            ):
                return "push", meta
            return "push", meta  # unknown pr edit → deny by default (fail closed)
        if sub in ("ready", "reopen", "lock", "unlock", "delete"):
            return "push" if sub != "delete" else "delete", meta
        if sub in ("list", "view", "status", "diff", "checks"):
            return None, meta
        return "push", meta  # unknown pr subcommand → treat as mutating

    # gh issue ...
    if rest[0] == "issue" and len(rest) >= 2:
        sub = rest[1]
        if len(rest) >= 3 and rest[2].isdigit():
            meta["number"] = int(rest[2])
        if sub == "comment":
            return "comment", meta
        if sub == "create":
            if "--label" in rest or "-l" in rest:
                return "label", meta
            return "push", meta
        if sub == "edit":
            if "--add-assignee" in rest or "--remove-assignee" in rest:
                return "assign", meta
            if "--add-label" in rest or "--remove-label" in rest:
                return "label", meta
            # --state closed / --state open
            for i, a in enumerate(rest):
                if a == "--state" and i + 1 < len(rest) and rest[i + 1] == "closed":
                    return "close", meta
                if a.startswith("--state=") and a.split("=", 1)[1] == "closed":
                    return "close", meta
            if any(
                f in rest or any(a.startswith(f"{f}=") for a in rest)
                for f in ("--title", "--body", "--body-file")
            ):
                return "push", meta
            return "push", meta
        if sub in ("close",):
            return "close", meta
        if sub in ("list", "view", "status"):
            return None, meta
        return "push", meta

    # gh api ...
    if rest[0] == "api":
        method = "GET"
        method_explicit = False
        path = ""
        has_field = False
        skip_next = False
        for a in rest[1:]:
            if skip_next:
                skip_next = False
                continue
            if a in ("-X", "--method"):
                skip_next = True
                continue
            if a.startswith("--method="):
                method = a.split("=", 1)[1].upper()
                method_explicit = True
                continue
            if a.startswith("-"):
                if a in ("-F", "-f", "--field", "--raw-field", "-H", "--header", "--input", "-i"):
                    if a in ("-F", "-f", "--field", "--raw-field"):
                        has_field = True
                    skip_next = True
                elif a.startswith(("-F", "-f")) and "=" in a:
                    has_field = True
                continue
            if not path:
                path = a
        # Re-scan for method if -X was used
        for i, a in enumerate(rest[1:], 1):
            if a in ("-X", "--method") and i + 1 < len(rest):
                method = rest[i + 1].upper()
                method_explicit = True
            elif a.startswith("--method="):
                method = a.split("=", 1)[1].upper()
                method_explicit = True
        # gh api switches to POST when -f/-F are present unless method is set.
        if has_field and not method_explicit:
            method = "POST"
        if method in ("POST", "PUT", "PATCH", "DELETE"):
            if "/merge" in path:
                return "merge", meta
            if "/comments" in path:
                return "comment", meta
            if "/assignees" in path or "assignees" in path:
                return "assign", meta
            if "/labels" in path:
                return "label", meta
            if re.search(r"/pulls/\d+$", path) and method == "PATCH":
                return "close", meta
            if re.search(r"/issues/\d+$", path) and method == "PATCH":
                # Could be close or assign; treat as push unless assignees/labels
                return "push", meta
            if method == "DELETE":
                return "delete", meta
            return "push", meta  # unknown mutating API → typically denied
        return None, meta

    # Other top-level mutating commands
    if rest[0] in ("release", "gist", "repo", "secret", "variable", "workflow"):
        if len(rest) >= 2 and rest[1] in ("list", "view", "status", "get"):
            return None, meta
        return "push", meta

    return None, meta


def tier_forbids(tier: str, action: str) -> str | None:
    """Return a reason if the tier itself forbids the action."""
    t = tier.upper()
    if t.startswith("L1") or t == "1":
        return f"L1 report-only forbids '{action}'"
    if (t.startswith("L2") or t == "2") and action in (
        "merge",
        "close",
        "approve",
        "push",
        "commit",
        "force-push",
        "delete",
    ):
        return f"L2 assisted forbids '{action}' (allow comment/label/assign only)"
    return None


def evaluate_action(
    action: str,
    *,
    tier: str,
    allowlist: list[str],
    deny: list[str],
) -> tuple[bool, str]:
    """Return (allowed, reason)."""
    if action not in MUTATING_ACTIONS:
        return True, "non-mutating"

    reason = tier_forbids(tier, action)
    if reason:
        return False, reason

    if action in deny:
        return False, f"action '{action}' is on deny list"

    if action not in allowlist:
        return False, f"action '{action}' is not on allowlist"

    return True, "allowlisted"


def receipts_dir(run_dir: Path) -> Path:
    d = run_dir / "verifier-receipts"
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_denial(run_dir: Path | None, record: dict[str, Any]) -> None:
    if run_dir is None:
        return
    path = run_dir / "gate-denials.jsonl"
    if "argv" in record:
        record = {**record, "argv": redact_argv(list(record["argv"]))}
    record = {**record, "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


def receipt_canonical_payload(data: dict[str, Any]) -> str:
    """Stable JSON payload used for HMAC (excludes `sig`)."""
    payload = {
        "action": data.get("action"),
        "repo": data.get("repo"),
        "number": data.get("number"),
        "approved": bool(data.get("approved")),
        "verifier": data.get("verifier"),
        "rationale": data.get("rationale"),
        "ts": data.get("ts"),
    }
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sign_receipt(data: dict[str, Any], secret: str) -> str:
    digest = hmac.new(
        secret.encode("utf-8"),
        receipt_canonical_payload(data).encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return digest


def verify_receipt_signature(data: dict[str, Any], secret: str) -> bool:
    expected = data.get("sig")
    if not expected or not isinstance(expected, str):
        return False
    actual = sign_receipt(data, secret)
    return hmac.compare_digest(actual, expected)


def find_verifier_receipt(
    run_dir: Path,
    action: str,
    *,
    repo: str | None = None,
    number: int | None = None,
    verifier: str = "",
    receipt_secret: str = "",
    max_age_sec: int = RECEIPT_MAX_AGE_SEC,
) -> dict[str, Any] | None:
    """Find a matching approved receipt for this action/target."""
    d = receipts_dir(run_dir)
    now = datetime.now(timezone.utc)
    candidates: list[tuple[datetime, Path, dict[str, Any]]] = []

    for path in sorted(d.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if data.get("action") != action:
            continue
        if not data.get("approved"):
            continue
        # Exact binding when the command targets a specific repo/number.
        if number is not None and data.get("number") != number:
            continue
        if repo is not None and data.get("repo") != repo:
            continue
        if verifier and data.get("verifier") != verifier:
            continue
        ts_raw = data.get("ts") or ""
        try:
            ts = datetime.fromisoformat(str(ts_raw).replace("Z", "+00:00"))
        except ValueError:
            continue
        if ts.tzinfo is None:
            continue
        if (now - ts).total_seconds() > max_age_sec or (now - ts).total_seconds() < -60:
            continue
        if receipt_secret and not verify_receipt_signature(data, receipt_secret):
            continue
        candidates.append((ts, path, data))

    if not candidates:
        return None
    # Prefer newest when multiple match.
    candidates.sort(key=lambda item: item[0].timestamp(), reverse=True)
    return candidates[0][2]


def require_receipt(
    run_dir: Path,
    action: str,
    *,
    repo: str | None,
    number: int | None,
    verifier: str,
    receipt_secret: str = "",
) -> tuple[bool, str]:
    if action not in RECEIPT_REQUIRED:
        return True, "receipt not required"
    if repo is None or number is None:
        return False, "merge/close require --repo and PR/issue number for receipt binding"
    receipt = find_verifier_receipt(
        run_dir,
        action,
        repo=repo,
        number=number,
        verifier=verifier,
        receipt_secret=receipt_secret,
    )
    if receipt is None:
        sig_hint = ', "sig":"<hmac-sha256>"' if receipt_secret else ""
        return (
            False,
            f"missing verifier receipt for {action} {repo}#{number}"
            + f" — write {run_dir / 'verifier-receipts'}/<id>.json "
            f'{{"action":"{action}","repo":"{repo}","number":{number},'
            f'"approved":true,"verifier":"{verifier or "configured-verifier"}",'
            f'"rationale":"...","ts":"<ISO8601>Z"{sig_hint}}}',
        )
    return True, "receipt ok"


def check_command(
    argv: list[str],
    cfg: dict[str, Any] | None = None,
) -> tuple[bool, str, str | None, dict[str, Any]]:
    """Full check. Returns (ok, reason, action, meta)."""
    cfg = cfg or gate_config_from_env()
    if cfg.get("disabled"):
        return True, "gate disabled", None, {}

    action, meta = classify_gh_argv(argv)
    if action is None:
        return True, "readonly / ungated", None, meta

    ok, reason = evaluate_action(
        action,
        tier=str(cfg.get("tier") or "L1"),
        allowlist=list(cfg.get("allowlist") or []),
        deny=list(cfg.get("deny") or []),
    )
    if not ok:
        return False, reason, action, meta

    run_dir = cfg.get("run_dir")
    if action in RECEIPT_REQUIRED:
        if run_dir is None:
            return False, "LOOP_GATE_RUN_DIR not set (cannot verify receipt)", action, meta
        ok_r, reason_r = require_receipt(
            Path(run_dir),
            action,
            repo=meta.get("repo"),
            number=meta.get("number"),
            verifier=str(cfg.get("verifier") or ""),
            receipt_secret=str(cfg.get("receipt_secret") or ""),
        )
        if not ok_r:
            return False, reason_r, action, meta

    return True, reason, action, meta


def body_already_attributed(body: str) -> bool:
    """Return True when the body already starts with the AI-assisted marker."""
    return body.lstrip().startswith(ATTRIBUTION_MARKER)


def format_attribution_prefix(
    *,
    login: str = "",
    loop_name: str = "",
    template: str = "",
) -> str:
    """Build the markdown attribution blockquote line(s)."""
    login_s = (login or "unknown").lstrip("@")
    loop_s = (loop_name or "").strip()
    loop_suffix = f" (`{loop_s}`)" if loop_s else ""
    raw = (template or "").strip() or DEFAULT_ATTRIBUTION_TEMPLATE
    try:
        text = raw.format(
            login=login_s,
            loop=loop_s or "loop",
            loop_suffix=loop_suffix,
            url=AGENT_TOOLKIT_REPO_URL,
        )
    except (KeyError, ValueError, IndexError):
        text = DEFAULT_ATTRIBUTION_TEMPLATE.format(
            login=login_s,
            loop_suffix=loop_suffix,
        )
    text = text.rstrip()
    if not text.startswith(">"):
        text = f"> {text}"
    return text


def apply_attribution_to_body(body: str, prefix: str) -> str:
    """Prepend attribution when missing. Idempotent."""
    if body_already_attributed(body):
        return body
    prefix = prefix.rstrip()
    if not body:
        return f"{prefix}\n"
    return f"{prefix}\n\n{body.lstrip()}"


def resolve_github_login(real_gh: str | None = None) -> str:
    """Resolve the authenticated GitHub login via `gh api user`."""
    cached = os.environ.get("LOOP_GATE_GITHUB_LOGIN") or ""
    if cached:
        return cached
    real = real_gh or shutil_which_gh() or os.environ.get("LOOP_GATE_REAL_GH") or ""
    if not real:
        return ""
    try:
        result = subprocess.run(
            [real, "api", "user", "-q", ".login"],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    if result.returncode != 0:
        return ""
    return (result.stdout or "").strip()


def _rewrite_flag_value(
    argv: list[str],
    *,
    flags: tuple[str, ...],
    new_value: str,
) -> tuple[list[str], bool]:
    """Replace the value for any of the given CLI flags. Returns (argv, changed)."""
    out = list(argv)
    changed = False
    i = 0
    while i < len(out):
        a = out[i]
        for flag in flags:
            if a == flag and i + 1 < len(out):
                out[i + 1] = new_value
                changed = True
                i += 2
                break
            if a.startswith(f"{flag}="):
                out[i] = f"{flag}={new_value}"
                changed = True
                i += 1
                break
        else:
            i += 1
    return out, changed


def _rewrite_field_body(argv: list[str], new_body: str) -> tuple[list[str], bool]:
    """Rewrite `-f body=` / `-F body=` / `--raw-field body=` style args."""
    out = list(argv)
    changed = False
    field_flags = ("-f", "-F", "--field", "--raw-field")
    i = 0
    while i < len(out):
        a = out[i]
        if a in field_flags and i + 1 < len(out) and out[i + 1].startswith("body="):
            out[i + 1] = f"body={new_body}"
            changed = True
            i += 2
            continue
        for flag in field_flags:
            prefix = f"{flag}body="
            # gh allows -fbody=value without space
            if a.startswith(prefix) or a.startswith(f"{flag} body="):
                out[i] = f"{flag}body={new_body}" if not a.startswith(f"{flag} ") else a
                if a.startswith(prefix):
                    out[i] = f"{prefix}{new_body}"
                    changed = True
            elif a.startswith("-f") and a[2:].startswith("body="):
                out[i] = f"-fbody={new_body}"
                changed = True
            elif a.startswith("-F") and a[2:].startswith("body="):
                out[i] = f"-Fbody={new_body}"
                changed = True
        i += 1
    return out, changed


def inject_attribution_argv(
    argv: list[str],
    *,
    prefix: str,
    run_dir: Path | None = None,
) -> tuple[list[str], bool]:
    """Rewrite gh argv so comment/review bodies include attribution.

    Supports ``--body`` / ``-b``, ``--body-file``, and ``-f/-F body=``.
    Returns (new_argv, injected).
    """
    # --body / -b
    body_flags = ("--body", "-b")
    for i, a in enumerate(argv):
        for flag in body_flags:
            if a == flag and i + 1 < len(argv):
                new_body = apply_attribution_to_body(argv[i + 1], prefix)
                if new_body == argv[i + 1]:
                    return list(argv), False
                out, _ = _rewrite_flag_value(argv, flags=body_flags, new_value=new_body)
                return out, True
            if a.startswith(f"{flag}="):
                raw = a.split("=", 1)[1]
                new_body = apply_attribution_to_body(raw, prefix)
                if new_body == raw:
                    return list(argv), False
                out, _ = _rewrite_flag_value(argv, flags=body_flags, new_value=new_body)
                return out, True

    # --body-file
    for i, a in enumerate(argv):
        path_s: str | None = None
        flag_eq = False
        if a in ("--body-file",) and i + 1 < len(argv):
            path_s = argv[i + 1]
        elif a.startswith("--body-file="):
            path_s = a.split("=", 1)[1]
            flag_eq = True
        if path_s is None:
            continue
        try:
            original = Path(path_s).read_text(encoding="utf-8")
        except OSError:
            return list(argv), False
        new_body = apply_attribution_to_body(original, prefix)
        if new_body == original:
            return list(argv), False
        dest_dir = (run_dir / ".gate") if run_dir else Path(path_s).parent
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"attributed-body-{hashlib.sha256(new_body.encode()).hexdigest()[:10]}.md"
        dest.write_text(new_body, encoding="utf-8")
        if flag_eq:
            out = list(argv)
            out[i] = f"--body-file={dest}"
            return out, True
        out, _ = _rewrite_flag_value(argv, flags=("--body-file",), new_value=str(dest))
        return out, True

    # -f / -F body=
    for i, a in enumerate(argv):
        field_flags = ("-f", "-F", "--field", "--raw-field")
        if a in field_flags and i + 1 < len(argv) and argv[i + 1].startswith("body="):
            raw = argv[i + 1].split("=", 1)[1]
            new_body = apply_attribution_to_body(raw, prefix)
            if new_body == raw:
                return list(argv), False
            return _rewrite_field_body(argv, new_body)
        for flag in ("-f", "-F"):
            prefix_f = f"{flag}body="
            if a.startswith(prefix_f):
                raw = a[len(prefix_f) :]
                new_body = apply_attribution_to_body(raw, prefix)
                if new_body == raw:
                    return list(argv), False
                return _rewrite_field_body(argv, new_body)

    return list(argv), False


def install_gh_shim(
    run_dir: Path,
    *,
    tier: str,
    allowlist: list[str],
    deny: list[str],
    verifier: str = "",
    gate_script: Path | None = None,
    real_gh: str | None = None,
    attribution_enabled: bool = True,
    loop_name: str = "",
    github_login: str = "",
    attribution_template: str = "",
) -> dict[str, str]:
    """Create a PATH-first `gh` shim and return env vars for the runner."""
    real = real_gh or shutil_which_gh()
    if not real:
        raise RuntimeError("real `gh` binary not found on PATH")

    gate_script = gate_script or Path(__file__).resolve()
    shim_dir = run_dir / ".gate" / "bin"
    shim_dir.mkdir(parents=True, exist_ok=True)
    receipts_dir(run_dir)

    shim = shim_dir / "gh"
    shim.write_text(
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        f'exec "{sys.executable}" "{gate_script}" -- "$@"\n',
        encoding="utf-8",
    )
    shim.chmod(0o755)

    login = github_login or resolve_github_login(real)

    env = os.environ.copy()
    env["PATH"] = f"{shim_dir}{os.pathsep}{env.get('PATH', '')}"
    env["LOOP_GATE_REAL_GH"] = real
    env["LOOP_GATE_RUN_DIR"] = str(run_dir)
    env["LOOP_GATE_TIER"] = tier
    env["LOOP_GATE_ALLOWLIST"] = ",".join(allowlist)
    env["LOOP_GATE_DENY"] = ",".join(deny)
    env["LOOP_GATE_VERIFIER"] = verifier
    env["LOOP_GATE_ATTRIBUTION"] = "1" if attribution_enabled else "0"
    if loop_name:
        env["LOOP_GATE_LOOP_NAME"] = loop_name
    if login:
        env["LOOP_GATE_GITHUB_LOGIN"] = login
    if attribution_template:
        env["LOOP_GATE_ATTRIBUTION_TEMPLATE"] = attribution_template
    # Preserve receipt secret from the parent environment when present.
    if os.environ.get("LOOP_GATE_RECEIPT_SECRET"):
        env["LOOP_GATE_RECEIPT_SECRET"] = os.environ["LOOP_GATE_RECEIPT_SECRET"]
    env.pop("LOOP_GATE_DISABLED", None)
    return env


def shutil_which_gh() -> str | None:
    import shutil

    # Prefer a real gh that is NOT our shim (avoid recursion if already gated).
    path = os.environ.get("PATH", "")
    for directory in path.split(os.pathsep):
        candidate = Path(directory) / "gh"
        if candidate.is_file() and os.access(candidate, os.X_OK):
            # Skip if it is our shim (calls loop-gh-gate).
            try:
                text = candidate.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                text = ""
            if "loop-gh-gate" in text or "loop_gh_gate" in text:
                continue
            return str(candidate)
    found = shutil.which("gh")
    return found


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)

    if argv and argv[0] == "--classify":
        action, meta = classify_gh_argv(argv[1:])
        print(json.dumps({"action": action, "meta": meta}))
        return 0

    if argv and argv[0] == "--check":
        ok, reason, action, meta = check_command(argv[1:])
        print(json.dumps({"ok": ok, "reason": reason, "action": action, "meta": meta}))
        return 0 if ok else 2

    # Default: act as gh shim. Expect `--` then gh args, or raw gh args.
    if argv and argv[0] == "--":
        gh_args = argv[1:]
    else:
        gh_args = argv

    cfg = gate_config_from_env()
    ok, reason, action, meta = check_command(gh_args, cfg)
    if not ok:
        write_denial(
            cfg.get("run_dir"),
            {
                "kind": "denied",
                "action": action,
                "reason": reason,
                "argv": gh_args,
                "meta": meta,
                "tier": cfg.get("tier"),
                "allowlist": cfg.get("allowlist"),
                "deny": cfg.get("deny"),
            },
        )
        print(f"[loop-gh-gate] DENIED {action or 'unknown'}: {reason}", file=sys.stderr)
        return 78  # EX_CONFIG — distinctive for gate denial

    real = cfg.get("real_gh") or shutil_which_gh()
    if not real:
        print("[loop-gh-gate] real gh not found (LOOP_GATE_REAL_GH unset)", file=sys.stderr)
        return 127

    attribution_injected = False
    if (
        action in ATTRIBUTION_ACTIONS
        and cfg.get("attribution_enabled", True)
        and not cfg.get("disabled")
    ):
        login = str(cfg.get("github_login") or "") or resolve_github_login(str(real))
        prefix = format_attribution_prefix(
            login=login,
            loop_name=str(cfg.get("loop_name") or ""),
            template=str(cfg.get("attribution_template") or ""),
        )
        run_dir = cfg.get("run_dir")
        gh_args, attribution_injected = inject_attribution_argv(
            gh_args,
            prefix=prefix,
            run_dir=Path(run_dir) if run_dir else None,
        )

    if action:
        # Audit allowed mutations.
        run_dir = cfg.get("run_dir")
        if run_dir:
            audit = Path(run_dir) / "gate-allow.jsonl"
            with audit.open("a", encoding="utf-8") as fh:
                fh.write(
                    json.dumps(
                        {
                            "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                            "kind": "allowed",
                            "action": action,
                            "reason": reason,
                            "argv": redact_argv(gh_args),
                            "meta": {k: v for k, v in meta.items() if k != "raw"},
                            "attribution_injected": attribution_injected,
                        }
                    )
                    + "\n"
                )

    result = subprocess.run([real, *gh_args])
    return int(result.returncode)


if __name__ == "__main__":
    sys.exit(main())
