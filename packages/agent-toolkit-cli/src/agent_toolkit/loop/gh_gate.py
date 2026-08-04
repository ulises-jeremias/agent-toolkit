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

Environment (set by bin/loop):
  LOOP_GATE_REAL_GH       Absolute path to the real `gh` binary
  LOOP_GATE_RUN_DIR       Active run artifacts directory
  LOOP_GATE_TIER          L1 | L2 | L3
  LOOP_GATE_ALLOWLIST     Comma-separated allowlisted actions
  LOOP_GATE_DENY          Comma-separated denied actions
  LOOP_GATE_VERIFIER      Verifier skill/agent name (optional)
  LOOP_GATE_RECEIPT_SECRET  If set, verifier receipts must carry a matching HMAC
  LOOP_GATE_DISABLED      If "1", pass through without checks (tests only)

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
MUTATING_ACTIONS = frozenset({
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
})

# Merge/close always need a verifier receipt at L2+ (and are denied at L1).
RECEIPT_REQUIRED = frozenset({"merge", "close"})

# Max age for a verifier receipt (seconds).
RECEIPT_MAX_AGE_SEC = 3600


def _split_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return [p.strip() for p in value.split(",") if p.strip()]


def gate_config_from_env() -> dict[str, Any]:
    return {
        "real_gh": os.environ.get("LOOP_GATE_REAL_GH", ""),
        "run_dir": Path(os.environ["LOOP_GATE_RUN_DIR"]) if os.environ.get("LOOP_GATE_RUN_DIR") else None,
        "tier": (os.environ.get("LOOP_GATE_TIER") or "L1").upper(),
        "allowlist": _split_csv(os.environ.get("LOOP_GATE_ALLOWLIST")),
        "deny": _split_csv(os.environ.get("LOOP_GATE_DENY")),
        "verifier": os.environ.get("LOOP_GATE_VERIFIER") or "",
        "receipt_secret": os.environ.get("LOOP_GATE_RECEIPT_SECRET") or "",
        "disabled": os.environ.get("LOOP_GATE_DISABLED") == "1",
    }


_SENSITIVE_FLAGS = frozenset({
    "-H", "--header", "-b", "--body", "--body-file", "-F", "-f",
    "--raw-field", "--field", "--input", "-i", "--jq",
})


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
    if (t.startswith("L2") or t == "2") and action in ("merge", "close", "approve", "push", "commit", "force-push", "delete"):
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
        return False, f"merge/close require --repo and PR/issue number for receipt binding"
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


def install_gh_shim(
    run_dir: Path,
    *,
    tier: str,
    allowlist: list[str],
    deny: list[str],
    verifier: str = "",
    gate_script: Path | None = None,
    real_gh: str | None = None,
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

    env = os.environ.copy()
    env["PATH"] = f"{shim_dir}{os.pathsep}{env.get('PATH', '')}"
    env["LOOP_GATE_REAL_GH"] = real
    env["LOOP_GATE_RUN_DIR"] = str(run_dir)
    env["LOOP_GATE_TIER"] = tier
    env["LOOP_GATE_ALLOWLIST"] = ",".join(allowlist)
    env["LOOP_GATE_DENY"] = ",".join(deny)
    env["LOOP_GATE_VERIFIER"] = verifier
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

    if action:
        # Audit allowed mutations.
        run_dir = cfg.get("run_dir")
        if run_dir:
            audit = Path(run_dir) / "gate-allow.jsonl"
            with audit.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps({
                    "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "kind": "allowed",
                    "action": action,
                    "reason": reason,
                    "argv": redact_argv(gh_args),
                    "meta": {k: v for k, v in meta.items() if k != "raw"},
                }) + "\n")

    result = subprocess.run([real, *gh_args])
    return int(result.returncode)


if __name__ == "__main__":
    sys.exit(main())
