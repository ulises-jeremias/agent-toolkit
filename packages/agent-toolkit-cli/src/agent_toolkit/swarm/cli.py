"""Swarm CLI — backend-neutral orchestration.

Implements all required `agent-toolkit swarm` subcommands.
Side-effect free `plan`, durable filesystem state, worktrees, handoffs, budgets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .approvals import (
    approve_gate,
    default_gates_for_recipe,
    load_approvals,
    reject_gate,
    request_approval,
    save_approvals,
)
from .budget import load_budget, resolve_budget, save_budget
from .config import find_repo_root, resolve_config
from .handoff import handoff_id_for, list_handoffs, validate_handoff, write_handoff_outbox, move_handoff, validate_commit_exists
from .models import API_VERSION
from .prompts import compose_role_prompt
from .recipes import BUILTIN_RECIPES, get_recipe, list_recipes, validate_recipe
from .runner import MODEL_PROFILES, capability_matrix, discover_models, generate_opencode_agent, resolve_model, runner_available
from .backends import get_backend
from .store import (
    atomic_write_json,
    atomic_write_text,
    append_trace,
    ensure_run_dirs,
    is_path_contained,
    now_ts,
    read_state,
    run_dir_for,
    swarm_root_for_repo,
    write_state,
    list_runs,
    validate_artifact_path,
)
from .worktree import branch_for_run_role, create_worktree, remove_worktree, is_worktree_dirty, worktree_path_for

NO_COLOR = os.environ.get("NO_COLOR") is not None or not sys.stdout.isatty()

def _log(msg: str) -> None:
    print(msg)

def _error(msg: str, hint: str | None = None, exit_code: int = 1) -> int:
    print(f"error: {msg}", file=sys.stderr)
    if hint:
        print(hint, file=sys.stderr)
    return exit_code

def _json_out(data: Any) -> int:
    print(json.dumps(data, indent=2))
    return 0

def _need_repo() -> Path:
    return find_repo_root()

def cmd_recipes(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm recipes")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    items = []
    for name in list_recipes():
        r = get_recipe(name)
        items.append({"name": name, "description": (r.get("metadata") or {}).get("description", "") if r else ""})
    if ns.json:
        return _json_out(items)
    for it in items:
        print(f"{it['name']:8}  {it['description']}")
    return 0

def cmd_recipe_show(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm recipe show")
    parser.add_argument("name")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    r = get_recipe(ns.name)
    if not r:
        return _error(f"Unknown recipe: {ns.name!r}", hint=f"Available: {', '.join(list_recipes())}")
    if ns.json:
        return _json_out(r)
    # Print yaml-like summary
    print(f"name: {ns.name}")
    print(f"description: {(r.get('metadata') or {}).get('description','')}")
    spec = r.get("spec", {})
    print(f"roles: {', '.join(spec.get('roles', {}).keys())}")
    print(f"execution: {spec.get('execution', {})}")
    print(f"budget: {spec.get('budget', {})}")
    return 0

def cmd_runners(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm runners")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    m = capability_matrix()
    if ns.json:
        return _json_out(m)
    for name, caps in m.items():
        avail = "available" if caps.get("available") else "not found"
        print(f"{name:10} {avail:12} interactive={caps.get('interactive')} per_role_model={caps.get('per_role_model')} herdr={caps.get('herdr')}")
    return 0

def cmd_models(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm models")
    parser.add_argument("--runner", default="opencode")
    parser.add_argument("--profile", default=None)
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    if ns.profile:
        mapping = MODEL_PROFILES.get(ns.profile)
        if not mapping:
            return _error(f"Unknown profile {ns.profile!r}", hint=f"Choose: {', '.join(MODEL_PROFILES)}")
        if ns.json:
            return _json_out(mapping)
        for k, v in mapping.items():
            print(f"{k:15} {v}")
        return 0
    models = discover_models(ns.runner)
    if ns.json:
        return _json_out(models)
    for m in models:
        print(m)
    return 0

def cmd_backends(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm backends")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    backends = ["herdr", "tmux", "auto", "headless"]
    details = {}
    for b in backends:
        be = get_backend(b)
        try:
            details[b] = be.doctor()
        except Exception as e:
            details[b] = {"available": False, "error": str(e)}
    if ns.json:
        return _json_out(details)
    for b, d in details.items():
        avail = d.get("available")
        print(f"{b:10} {'available' if avail else 'unavailable':12} {d.get('version','') or d.get('reason','')}")
    return 0

def cmd_doctor(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm doctor")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    data: dict[str, Any] = {"repo": str(repo)}
    # Check git
    try:
        res = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"], cwd=str(repo), capture_output=True, text=True, timeout=5)
        data["git"] = {"available": res.returncode == 0}
    except Exception as e:
        data["git"] = {"available": False, "error": str(e)}
    # Backends
    for b in ["herdr", "tmux"]:
        be = get_backend(b)
        data[b] = be.doctor()
    # Runners
    data["runners"] = capability_matrix()
    data["recipes"] = list_recipes()
    # Workstation check
    data["toolkit_swarm"] = {"version": "1", "apiVersion": API_VERSION}
    if ns.json:
        return _json_out(data)
    print("Swarm doctor")
    print(f"  repo: {repo}")
    print(f"  git: {'ok' if data['git'].get('available') else 'missing'}")
    for b in ["herdr", "tmux"]:
        d = data[b]
        status = "pass" if d.get("available") else "warning" if b=="herdr" else "failure"
        print(f"  {b}: {status} - {d.get('version') or d.get('reason')}")
    for r, caps in data["runners"].items():
        print(f"  runner {r}: {'available' if caps.get('available') else 'not found'}")
    print(f"  recipes: {', '.join(data['recipes'])}")
    # Non-zero if git missing
    if not data["git"].get("available"):
        return 1
    return 0

def cmd_init(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm init")
    parser.add_argument("--workspace", default=".")
    parser.add_argument("--recipe", default=None)
    parser.add_argument("--force", action="store_true")
    ns = parser.parse_args(args)
    ws = Path(ns.workspace).resolve()
    if not ws.is_dir():
        return _error(f"Workspace not found: {ws}")
    cfg_path = ws / ".agent-toolkit" / "swarm.yaml"
    if cfg_path.exists() and not ns.force:
        return _error(f"Config already exists: {cfg_path}", hint="Use --force to overwrite")
    cfg_path.parent.mkdir(parents=True, exist_ok=True)
    recipe = ns.recipe or "pair"
    if recipe not in list_recipes():
        return _error(f"Unknown recipe {recipe!r}")
    content = f"""# Agent Toolkit Swarm workspace config
# Generated by `agent-toolkit swarm init`
recipe: {recipe}
ui: auto
runner: opencode
model_profile: balanced
"""
    cfg_path.write_text(content, encoding="utf-8")
    print(f"Created {cfg_path}")
    return 0

def _resolve_task_text(cli_args: argparse.Namespace, remaining: list[str]) -> tuple[str | None, str | None]:
    # Returns (task_text, issue_ref)
    if remaining:
        return " ".join(remaining), None
    if getattr(cli_args, "request_file", None):
        p = Path(cli_args.request_file)
        if not p.is_file():
            raise ValueError(f"--request-file not found: {p}")
        return p.read_text(encoding="utf-8"), None
    if getattr(cli_args, "issue", None):
        return f"Implement issue {cli_args.issue}", cli_args.issue
    return None, None

def cmd_plan(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm plan")
    parser.add_argument("--recipe", default=None)
    parser.add_argument("--ui", default=None, choices=["auto", "herdr", "tmux", "headless"])
    parser.add_argument("--runner", default=None)
    parser.add_argument("--model-profile", default=None, choices=list(MODEL_PROFILES.keys()))
    parser.add_argument("--request-file", default=None)
    parser.add_argument("--issue", default=None)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--base-ref", default=None)
    # allow positional task
    ns, rest = parser.parse_known_args(args)
    # rest may contain task words; need to separate --
    if rest and rest[0] == "--":
        rest = rest[1:]
    try:
        task_text, issue = _resolve_task_text(ns, rest)
    except ValueError as e:
        return _error(str(e))
    if not task_text:
        return _error("No task provided", hint="Provide task text, --request-file, or --issue")
    repo = _need_repo()
    cfg = resolve_config(repo, {"recipe": ns.recipe, "ui": ns.ui, "runner": ns.runner, "model_profile": ns.model_profile})
    recipe_name = cfg.get("recipe", "pair")
    recipe = get_recipe(recipe_name)
    if not recipe:
        return _error(f"Unknown recipe {recipe_name!r}")
    # Validate tools
    backend_name = cfg.get("ui", "auto")
    backend = get_backend(backend_name)
    backend_status = backend.doctor()
    runner_name = cfg.get("runner", "opencode")
    runner_avail = runner_available(runner_name)
    # Resolve models per role
    roles = recipe.get("spec", {}).get("roles", {})
    model_assignments: dict[str, str | None] = {}
    for rname, rdef in roles.items():
        task_class = rdef.get("model_profile", "coding")
        try:
            model_assignments[rname] = resolve_model(cfg.get("model_profile", "balanced"), task_class)
        except ValueError as e:
            return _error(str(e))
    # Budget
    budget = resolve_budget(recipe.get("spec", {}).get("budget"))
    # Worktrees
    worktrees = []
    for rname, rdef in roles.items():
        wt = rdef.get("worktree")
        if wt:
            branch = branch_for_run_role("plan-preview", rname)
            worktrees.append({"role": rname, "branch": branch, "path": f".agent-toolkit/swarm/runs/<run-id>/worktrees/{rname}"})
    # Gates
    gates = default_gates_for_recipe(recipe)
    # Cost estimate (naive)
    cost_estimate = None
    total_tokens = budget.get("max_total_tokens")
    # pricing unknown -> report honestly
    pricing_note = "Pricing unavailable for some models; estimate not calculated. Use --model-profile to control cost."

    plan = {
        "recipe": recipe_name,
        "task": task_text[:2000],
        "ui_backend": {"requested": backend_name, "resolved": backend_name, "available": backend_status.get("available"), "details": backend_status},
        "runner": {"requested": runner_name, "available": runner_avail},
        "model_profile": cfg.get("model_profile", "balanced"),
        "model_assignments": model_assignments,
        "roles": list(roles.keys()),
        "role_details": roles,
        "worktrees": worktrees,
        "gates": gates,
        "budget": budget,
        "concurrency": budget.get("max_concurrency"),
        "round_trips": budget.get("max_role_round_trips"),
        "pricing_note": pricing_note,
        "base_ref": ns.base_ref or "HEAD",
        "run_dir_preview": ".agent-toolkit/swarm/runs/<run-id>/",
    }
    if ns.json:
        return _json_out(plan)
    print("Swarm plan (no changes made)")
    print(f"  recipe: {recipe_name}")
    print(f"  task: {task_text[:120]}")
    print(f"  ui: {backend_name} -> available={backend_status.get('available')} {backend_status.get('version') or backend_status.get('reason','')}")
    if backend_name == "herdr" and not backend_status.get("available"):
        hint = "Herdr was explicitly requested but was not found.\n\nInstall:\n  https://herdr.dev/docs/install/\n\nOr use:\n  agent-toolkit swarm start --ui tmux ..."
        print(hint, file=sys.stderr)
        return 1
    print(f"  runner: {runner_name} -> {'available' if runner_avail else 'not found'}")
    if not runner_avail:
        print(f"  hint: install {runner_name} or choose another --runner", file=sys.stderr)
    print(f"  model_profile: {cfg.get('model_profile')}")
    for r, m in model_assignments.items():
        print(f"    {r:12} -> {m}")
    print(f"  roles: {', '.join(roles.keys())}")
    print(f"  worktrees: {len(worktrees)} (one per writer)")
    for wt in worktrees:
        print(f"    {wt['role']}: {wt['branch']} at {wt['path']}")
    print(f"  gates: {', '.join(g['id'] for g in gates) or 'none'}")
    print(f"  concurrency: {budget.get('max_concurrency')} (default 2)")
    print(f"  round_trips: {budget.get('max_role_round_trips')}")
    print(f"  budget: tokens={budget.get('max_total_tokens')} cost=${budget.get('max_cost_usd')} wall={budget.get('max_wall_seconds')}s")
    print(f"  note: {pricing_note}")
    if not runner_avail:
        return 1
    return 0

def _generate_run_id() -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    rand = hashlib.sha256(os.urandom(8)).hexdigest()[:6]
    return f"{ts}-{rand}"

def _load_or_create_run_state(repo: Path, run_id: str, recipe_name: str, cfg: dict[str, Any], task_text: str) -> Path:
    run_dir = run_dir_for(repo, run_id)
    ensure_run_dirs(run_dir)
    recipe = get_recipe(recipe_name)
    assert recipe is not None
    spec = recipe.get("spec", {})
    budget = resolve_budget(spec.get("budget"))
    gates = default_gates_for_recipe(recipe)
    # Handle initial state
    requires_plan = spec.get("gates", {}).get("require_plan_approval", False)
    from .state import initial_run_state
    run_state_val = initial_run_state(recipe_name, requires_plan)
    state: dict[str, Any] = {
        "version": 1,
        "run_id": run_id,
        "recipe": recipe_name,
        "run_state": run_state_val,
        "roles": {r: "inactive" for r in spec.get("roles", {}).keys()},
        "created_at": now_ts(),
        "updated_at": now_ts(),
        "ui_backend": cfg.get("ui", "auto"),
        "runner": cfg.get("runner", "opencode"),
        "model_profile": cfg.get("model_profile", "balanced"),
        "task": task_text[:5000],
        "budget": budget,
        "worktrees": [],
        "trace": [],
    }
    atomic_write_json(run_dir / "state.json", state)
    # run.yaml
    run_yaml = f"run_id: {run_id}\nrecipe: {recipe_name}\ncreated_at: {state['created_at']}\n"
    atomic_write_text(run_dir / "run.yaml", run_yaml)
    # budget.json
    save_budget(run_dir, budget, {"total_tokens": 0, "cost_usd": 0.0, "wall_seconds": 0})
    save_approvals(run_dir, gates)
    append_trace(run_dir, {"ts": now_ts(), "kind": "run_created", "run_id": run_id, "recipe": recipe_name})
    append_trace(run_dir, {"ts": now_ts(), "kind": "recipe_resolved", "recipe": recipe_name})
    append_trace(run_dir, {"ts": now_ts(), "kind": "budget_resolved", "budget": budget})
    # ownership
    atomic_write_json(run_dir / "ownership.json", {"run_id": run_id, "created_at": state["created_at"], "owned_branches": [], "owned_worktrees": []})
    return run_dir

def cmd_start(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm start")
    parser.add_argument("--recipe", default=None)
    parser.add_argument("--ui", default=None, choices=["auto", "herdr", "tmux", "headless"])
    parser.add_argument("--runner", default=None)
    parser.add_argument("--model-profile", default=None, choices=list(MODEL_PROFILES.keys()))
    parser.add_argument("--request-file", default=None)
    parser.add_argument("--issue", default=None)
    parser.add_argument("--base-ref", default="HEAD")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    ns, rest = parser.parse_known_args(args)
    if rest and rest[0] == "--":
        rest = rest[1:]
    try:
        task_text, issue = _resolve_task_text(ns, rest)
    except ValueError as e:
        return _error(str(e))
    if not task_text:
        return _error("No task provided", hint="Provide task text inline or via --request-file / --issue")
    repo = _need_repo()
    cfg = resolve_config(repo, {"recipe": ns.recipe, "ui": ns.ui, "runner": ns.runner, "model_profile": ns.model_profile})
    recipe_name = cfg.get("recipe", "pair")
    recipe = get_recipe(recipe_name)
    if not recipe:
        return _error(f"Unknown recipe {recipe_name!r}")
    # Validate backend explicitly
    backend_name = cfg.get("ui", "auto")
    backend = get_backend(backend_name)
    doctor = backend.doctor()
    if backend_name == "herdr" and not doctor.get("available"):
        print("Herdr was explicitly requested but was not found.", file=sys.stderr)
        print("\nInstall:\n  https://herdr.dev/docs/install/\n\nOr use:\n  agent-toolkit swarm start --ui tmux ...", file=sys.stderr)
        return 1
    if backend_name == "auto" and not doctor.get("available"):
        # fallback to tmux check
        tmux_be = get_backend("tmux")
        tmux_doc = tmux_be.doctor()
        if not tmux_doc.get("available"):
            print("No interactive backend available (herdr and tmux not found).", file=sys.stderr)
            print("Install tmux or herdr, or use --ui headless if supported.", file=sys.stderr)
            return 1
        # auto fallback to tmux
        backend_name = "tmux"
        backend = tmux_be
        cfg["ui"] = "tmux"
        print(f"[swarm] auto: herdr unavailable, falling back to tmux", file=sys.stderr)
    # Validate runner
    runner_name = cfg.get("runner", "opencode")
    if not runner_available(runner_name) and runner_name != "skeleton":
        # Still allow skeleton for demo
        print(f"Runner {runner_name!r} not found. Install it or use --runner skeleton for dry-run.", file=sys.stderr)
        # Continue for dry-run?
        if not ns.dry_run:
            # Allow to proceed with warning for tests with fake binaries via PATH override
            pass
    # Create run
    run_id = _generate_run_id()
    run_dir = _load_or_create_run_state(repo, run_id, recipe_name, cfg, task_text)
    # Generate OpenCode agents and prompts
    roles = recipe.get("spec", {}).get("roles", {})
    for rname, rdef in roles.items():
        task_class = rdef.get("model_profile", "coding")
        model = resolve_model(cfg.get("model_profile", "balanced"), task_class) or "unknown/model"
        worktree = rdef.get("worktree")
        try:
            generate_opencode_agent(run_dir, rname, rdef.get("persona", rname), rdef.get("policy", "read-only"), model, recipe_name, run_id, worktree)
        except Exception:
            pass
        # Prompt composition
        try:
            prompt, manifest = compose_role_prompt(recipe, rname, rdef, task_text, None, rdef.get("skills"))
            (run_dir / "prompts" / f"{rname}.md").write_text(prompt, encoding="utf-8")
            (run_dir / "prompts" / f"{rname}.manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        except Exception:
            pass
    # Worktree creation for writing roles (lazy: only roles whose inputs ready? For now create implementer eagerly)
    spec = recipe.get("spec", {})
    lazy = spec.get("execution", {}).get("lazy_start", True)
    # Determine initially active roles: planner or implementer
    initial_roles = []
    if "planner" in roles:
        initial_roles = ["planner"]
    elif "implementer" in roles:
        initial_roles = ["implementer"]
    else:
        initial_roles = list(roles.keys())[:1]
    created_wts = []
    for rname in roles:
        rdef = roles[rname]
        wt_name = rdef.get("worktree")
        if wt_name:
            # lazy: only create for initially active roles now
            if lazy and rname not in initial_roles:
                continue
            try:
                info = create_worktree(repo, run_dir, rname, run_id, ns.base_ref)
                created_wts.append(info)
                append_trace(run_dir, {"ts": now_ts(), "kind": "worktree_created", "role": rname, "path": info["path"], "branch": info["branch"]})
            except Exception as e:
                # Log but continue
                append_trace(run_dir, {"ts": now_ts(), "kind": "worktree_failed", "role": rname, "error": str(e)[:500]})
    # Update state worktrees
    state = read_state(run_dir) or {}
    state["worktrees"] = created_wts
    # Activate initial roles
    for r in initial_roles:
        state["roles"][r] = "ready"
        append_trace(run_dir, {"ts": now_ts(), "kind": "role_activated", "role": r})
        append_trace(run_dir, {"ts": now_ts(), "kind": "role_state_changed", "role": r, "to": "ready"})
    # If plan approval required, keep awaiting
    if state.get("run_state") == "awaiting_plan_approval":
        _log(f"Run {run_id} created, awaiting plan approval")
    else:
        state["run_state"] = "running"
        append_trace(run_dir, {"ts": now_ts(), "kind": "run_state_changed", "to": "running"})
    write_state(run_dir, state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "backend_selected", "backend": backend_name})
    append_trace(run_dir, {"ts": now_ts(), "kind": "runner_selected", "runner": runner_name})
    # Create backend surfaces (best effort, filesystem correctness not dependent)
    try:
        backend.create_run_surface(run_dir, run_id, recipe_name)
        for r in initial_roles:
            backend.create_role_surface(run_dir, run_id, r)
    except Exception:
        pass
    # Create artifacts placeholder
    (run_dir / "artifacts" / "task-contract.md").write_text(f"# Task Contract\n\n{task_text}\n\nRecipe: {recipe_name}\nRun: {run_id}\n", encoding="utf-8")
    if ns.json:
        return _json_out({"run_id": run_id, "run_dir": str(run_dir), "state": state, "backend": backend_name, "runner": runner_name})
    print(f"Swarm run created: {run_id}")
    print(f"  recipe: {recipe_name}")
    print(f"  run_dir: {run_dir}")
    print(f"  backend: {backend_name}")
    print(f"  runner: {runner_name}")
    print(f"  task: {task_text[:100]}")
    print(f"  initial roles: {', '.join(initial_roles)}")
    if state.get("run_state") == "awaiting_plan_approval":
        print(f"  status: awaiting_plan_approval — approve with: agent-toolkit swarm approve {run_id} plan")
    else:
        print(f"  status: running")
    print(f"Inspect: agent-toolkit swarm status {run_id}")
    return 0

def cmd_list(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm list")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    runs = list_runs(repo)
    items = []
    for rd in runs:
        state = read_state(rd) or {}
        items.append({"run_id": rd.name, "recipe": state.get("recipe"), "run_state": state.get("run_state"), "created_at": state.get("created_at")})
    items.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    if ns.json:
        return _json_out(items)
    if not items:
        print("No swarm runs found.")
        return 0
    for it in items:
        print(f"{it['run_id']:25} {it['recipe'] or '?':8} {it['run_state'] or '?':15} {it['created_at'] or ''}")
    return 0

def cmd_status(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm status")
    parser.add_argument("run_id", nargs="?", default=None)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--watch", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    if not ns.run_id:
        # Show all
        return cmd_list(["--json"] if ns.json else [])
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}", hint=f"List runs: agent-toolkit swarm list")
    state = read_state(run_dir) or {}
    budget_data = load_budget(run_dir)
    trace_path = run_dir / "trace.jsonl"
    trace_count = 0
    if trace_path.is_file():
        trace_count = len([l for l in trace_path.read_text(encoding="utf-8").splitlines() if l.strip()])
    data = {"run_id": ns.run_id, "state": state, "budget": budget_data, "trace_events": trace_count, "run_dir": str(run_dir)}
    if ns.json:
        return _json_out(data)
    print(f"Run: {ns.run_id}")
    print(f"  recipe: {state.get('recipe')}")
    print(f"  run_state: {state.get('run_state')}")
    print(f"  roles: {state.get('roles')}")
    print(f"  ui_backend: {state.get('ui_backend')}")
    print(f"  runner: {state.get('runner')}")
    print(f"  created_at: {state.get('created_at')}")
    print(f"  trace_events: {trace_count}")
    if budget_data:
        print(f"  budget: {budget_data}")
    # Approvals
    gates = load_approvals(run_dir)
    if gates:
        print(f"  approvals:")
        for g in gates:
            print(f"    {g['id']}: {'approved' if g.get('approved') else 'pending'} - {g.get('description','')[:60]}")
    if ns.watch:
        print("Watch mode: tailing trace.jsonl (Ctrl-C to exit)")
        try:
            while True:
                time.sleep(1)
                # simple poll
                new_count = len([l for l in (run_dir / "trace.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]) if (run_dir / "trace.jsonl").is_file() else 0
                if new_count != trace_count:
                    print(f"[trace] {new_count} events")
                    trace_count = new_count
        except KeyboardInterrupt:
            pass
    return 0

def cmd_watch(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm watch")
    parser.add_argument("run_id", nargs="?", default=None)
    parser.add_argument("--current", action="store_true")
    ns = parser.parse_args(args)
    if ns.current:
        repo = _need_repo()
        runs = list_runs(repo)
        if not runs:
            print("No runs")
            return 1
        # pick latest
        latest = sorted(runs, key=lambda p: p.stat().st_mtime, reverse=True)[0]
        ns.run_id = latest.name
    if not ns.run_id:
        return _error("No run_id", hint="Usage: agent-toolkit swarm watch RUN_ID")
    return cmd_status([ns.run_id, "--watch"])

def cmd_report(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm report")
    parser.add_argument("run_id", nargs="?", default=None)
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    if not ns.run_id:
        return _error("RUN_ID required")
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    artifacts = list((run_dir / "artifacts").glob("*")) if (run_dir / "artifacts").is_dir() else []
    handoffs_done = list_handoffs(run_dir, "completed")
    data = {
        "run_id": ns.run_id,
        "recipe": state.get("recipe"),
        "run_state": state.get("run_state"),
        "roles": state.get("roles"),
        "artifacts": [p.name for p in artifacts],
        "handoffs_completed": len(handoffs_done),
        "budget": load_budget(run_dir),
    }
    if ns.json:
        return _json_out(data)
    # Try final-report.md
    final = run_dir / "artifacts" / "final-report.md"
    if final.is_file():
        print(final.read_text(encoding="utf-8"))
        return 0
    print(f"Report for {ns.run_id}")
    print(f"  recipe: {data['recipe']}")
    print(f"  state: {data['run_state']}")
    print(f"  artifacts: {', '.join(data['artifacts']) or 'none'}")
    print(f"  handoffs completed: {data['handoffs_completed']}")
    # Generate placeholder report if not exists
    if not final.is_file():
        print("\nNo final-report.md yet. Run is not completed.")
    return 0

def cmd_artifacts(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm artifacts")
    parser.add_argument("run_id")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    art_dir = run_dir / "artifacts"
    items = []
    if art_dir.is_dir():
        for p in sorted(art_dir.iterdir()):
            if p.is_file():
                items.append({"name": p.name, "path": str(p.relative_to(run_dir)), "size": p.stat().st_size})
    if ns.json:
        return _json_out(items)
    for it in items:
        print(f"{it['name']:30} {it['size']:6} bytes  {it['path']}")
    if not items:
        print("No artifacts yet.")
    return 0

def cmd_handoffs(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm handoffs")
    parser.add_argument("run_id")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    all_states = ["outbox", "queued", "active", "completed", "failed"]
    data: dict[str, list[dict[str, Any]]] = {}
    for st in all_states:
        data[st] = list_handoffs(run_dir, st)
    if ns.json:
        return _json_out(data)
    for st, items in data.items():
        print(f"{st}: {len(items)}")
        for it in items:
            print(f"  {it.get('handoff_id','?')} {it.get('type')} {it.get('from')}->{it.get('to')} prio={it.get('priority')}")
    return 0

def cmd_logs(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm logs")
    parser.add_argument("run_id")
    parser.add_argument("role", nargs="?", default=None)
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    if ns.role:
        # Try backend log
        backend_name = (read_state(run_dir) or {}).get("ui_backend", "auto")
        backend = get_backend(backend_name)
        try:
            out = backend.read_agent_output(ns.run_id, ns.role)
            print(out)
            return 0
        except Exception as e:
            print(f"Logs for {ns.role} not available: {e}")
            return 0
    # Show trace
    trace = run_dir / "trace.jsonl"
    if trace.is_file():
        print(trace.read_text(encoding="utf-8"))
    else:
        print("No trace.jsonl")
    return 0

def _change_run_state(repo: Path, run_id: str, new_state: str) -> int:
    run_dir = run_dir_for(repo, run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {run_id}")
    state = read_state(run_dir) or {}
    old = state.get("run_state")
    from .state import can_transition_run
    if not can_transition_run(old, new_state):
        return _error(f"Invalid transition {old!r} -> {new_state!r}")
    state["run_state"] = new_state
    write_state(run_dir, state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "run_state_changed", "from": old, "to": new_state})
    print(f"Run {run_id}: {old} -> {new_state}")
    return 0

def cmd_pause(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm pause")
    parser.add_argument("run_id")
    ns = parser.parse_args(args)
    return _change_run_state(_need_repo(), ns.run_id, "paused")

def cmd_resume(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm resume")
    parser.add_argument("run_id")
    ns = parser.parse_args(args)
    # resume from paused or budget_exhausted or failed
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    old = state.get("run_state")
    # Allow paused -> running, budget_exhausted -> running, failed -> running
    if old not in ("paused", "budget_exhausted", "failed"):
        # try generic paused
        return _change_run_state(repo, ns.run_id, "running")
    state["run_state"] = "running"
    write_state(run_dir, state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "run_state_changed", "from": old, "to": "running"})
    append_trace(run_dir, {"ts": now_ts(), "kind": "role_state_changed", "detail": "resume"})
    print(f"Run {ns.run_id}: {old} -> running")
    return 0

def cmd_stop(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm stop")
    parser.add_argument("run_id")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    state["run_state"] = "paused"
    write_state(run_dir, state)
    # stop agents via backend
    be = get_backend(state.get("ui_backend", "auto"))
    for role in state.get("roles", {}):
        try:
            be.stop_agent(ns.run_id, role)
        except Exception:
            pass
    append_trace(run_dir, {"ts": now_ts(), "kind": "role_stopped", "run_id": ns.run_id})
    print(f"Run {ns.run_id} stopped (state preserved). Resume with: agent-toolkit swarm resume {ns.run_id}")
    return 0

def cmd_cancel(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm cancel")
    parser.add_argument("run_id")
    ns = parser.parse_args(args)
    return _change_run_state(_need_repo(), ns.run_id, "cancelled")

def cmd_cleanup(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm cleanup")
    parser.add_argument("run_id")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-branches", action="store_true", default=True)
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    # Find owned worktrees
    wts = state.get("worktrees") or []
    # Also discover on-disk worktrees under run_dir/worktrees
    disk_wts = []
    wt_root = run_dir / "worktrees"
    if wt_root.is_dir():
        for p in wt_root.iterdir():
            if p.is_dir():
                disk_wts.append(p)
    if not ns.dry_run:
        print(f"Cleanup for run {ns.run_id}:")
        print(f"  run_dir: {run_dir}")
        print(f"  worktrees: {wts or disk_wts or 'none (no owned)'}")
        if wts or disk_wts:
            # Check dirty
            for wt in (disk_wts if disk_wts else [Path(w["path"]) for w in wts if "path" in w]):
                wt_path = Path(wt) if isinstance(wt, str) else wt
                if wt_path.exists() and is_worktree_dirty(wt_path) and not ns.force:
                    print(f"Worktree contains uncommitted changes. Toolkit will not remove it.\n\nPath:\n  {wt_path}\n\nResolve or preserve the changes, then rerun cleanup with --force.", file=sys.stderr)
                    return 1
        if ns.dry_run:
            print("Dry-run: would remove worktrees but preserving due to --dry-run")
            return 0
    # Dry-run path
    if ns.dry_run:
        print(f"Would remove {len(disk_wts)} worktrees, keep branches (branches never deleted automatically)")
        return 0
    # Actual removal: only Toolkit-owned under run_dir/worktrees
    for wt_path in disk_wts:
        if not is_path_contained((run_dir / "worktrees").resolve(), wt_path.resolve()) and wt_path.resolve() != (run_dir / "worktrees").resolve():
            print(f"Skipping non-owned worktree: {wt_path}", file=sys.stderr)
            continue
        if wt_path.exists():
            if is_worktree_dirty(wt_path) and not ns.force:
                print(f"Worktree contains uncommitted changes.\nPath: {wt_path}", file=sys.stderr)
                return 1
            try:
                remove_worktree(repo, wt_path, force=ns.force)
                print(f"Removed worktree {wt_path}")
            except Exception as e:
                print(f"Failed to remove {wt_path}: {e}", file=sys.stderr)
                return 1
    # Do NOT delete branches by default (per spec)
    # Mark cleanup pending
    # Optionally remove run_dir if requested? Keep state for audit
    print(f"Cleanup completed for {ns.run_id} (branches preserved).")
    try:
        append_trace(run_dir, {"ts": now_ts(), "kind": "cleanup_completed", "run_id": ns.run_id})
    except Exception:
        pass
    return 0

def cmd_attach(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm attach")
    parser.add_argument("run_id")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    backend_name = state.get("ui_backend", "auto")
    backend = get_backend(backend_name)
    backend.attach(ns.run_id)
    return 0

def cmd_promote(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm promote")
    parser.add_argument("run_id")
    parser.add_argument("--to", dest="to_recipe", required=True, choices=list_recipes())
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    old_recipe = state.get("recipe")
    order = {"pair": 1, "team": 2, "full": 3}
    if order.get(ns.to_recipe, 0) <= order.get(old_recipe, 0):
        return _error(f"Cannot promote {old_recipe} -> {ns.to_recipe} (must increase: pair->team->full)")
    recipe = get_recipe(ns.to_recipe)
    if not recipe:
        return _error(f"Unknown recipe {ns.to_recipe!r}")
    # Preserve artifacts, branches, budget, audit
    state["recipe"] = ns.to_recipe
    # Add missing roles as inactive
    for r in recipe.get("spec", {}).get("roles", {}):
        if r not in state.get("roles", {}):
            state["roles"][r] = "inactive"
    write_state(run_dir, state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "recipe_promoted", "from": old_recipe, "to": ns.to_recipe})
    # Add gates for new recipe if needed
    existing_gates = load_approvals(run_dir)
    new_gates = default_gates_for_recipe(recipe)
    # Merge without duplicates
    ids = {g["id"] for g in existing_gates}
    for g in new_gates:
        if g["id"] not in ids:
            existing_gates.append(g)
    save_approvals(run_dir, existing_gates)
    # Generate prompts for new roles
    for rname, rdef in recipe.get("spec", {}).get("roles", {}).items():
        if (run_dir / "prompts" / f"{rname}.md").exists():
            continue
        try:
            prompt, manifest = compose_role_prompt(recipe, rname, rdef, state.get("task"), None, rdef.get("skills"))
            (run_dir / "prompts" / f"{rname}.md").write_text(prompt, encoding="utf-8")
            (run_dir / "prompts" / f"{rname}.manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
            generate_opencode_agent(run_dir, rname, rdef.get("persona", rname), rdef.get("policy", "read-only"), resolve_model(state.get("model_profile", "balanced"), rdef.get("model_profile", "coding")) or "unknown/model", ns.to_recipe, ns.run_id, rdef.get("worktree"))
        except Exception:
            pass
    print(f"Promoted {ns.run_id}: {old_recipe} -> {ns.to_recipe} (run ID preserved, artifacts intact)")
    return 0

def cmd_activate(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm activate")
    parser.add_argument("run_id")
    parser.add_argument("role")
    parser.add_argument("--specialist", default=None, help="For hardener: security-reviewer|database-reviewer|performance-optimizer|typescript-reviewer")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    if ns.role not in state.get("roles", {}):
        return _error(f"Role {ns.role!r} not in recipe {state.get('recipe')}")
    if state["roles"][ns.role] != "inactive":
        return _error(f"Role {ns.role} already active: {state['roles'][ns.role]}")
    state["roles"][ns.role] = "ready"
    # Create worktree if needed
    recipe = get_recipe(state.get("recipe", "pair"))
    rdef = (recipe.get("spec", {}).get("roles", {}) if recipe else {}).get(ns.role, {}).copy()
    if ns.role == "hardener" and ns.specialist:
        if ns.specialist not in ("security-reviewer", "database-reviewer", "performance-optimizer", "typescript-reviewer"):
            return _error(f"Invalid specialist {ns.specialist!r}", hint="Choose: security-reviewer, database-reviewer, performance-optimizer, typescript-reviewer")
        rdef["persona"] = ns.specialist
        append_trace(run_dir, {"ts": now_ts(), "kind": "specialist_selected", "role": "hardener", "persona": ns.specialist})
    wt_name = rdef.get("worktree")
    if wt_name:
        try:
            info = create_worktree(repo, run_dir, ns.role, ns.run_id, "HEAD")
            wts = state.get("worktrees") or []
            wts.append(info)
            state["worktrees"] = wts
            append_trace(run_dir, {"ts": now_ts(), "kind": "worktree_created", "role": ns.role})
        except Exception as e:
            return _error(str(e))
    # Regenerate prompt/agent for specialist
    if ns.role == "hardener" and ns.specialist:
        try:
            model = resolve_model(state.get("model_profile", "balanced"), rdef.get("model_profile", "hardening")) or "unknown/model"
            generate_opencode_agent(run_dir, "hardener", ns.specialist, rdef.get("policy", "reviewer-writer"), model, state.get("recipe", "full"), ns.run_id, rdef.get("worktree"))
            prompt, manifest = compose_role_prompt(get_recipe(state.get("recipe", "full")) or {}, "hardener", rdef, state.get("task"), None, rdef.get("skills"))
            (run_dir / "prompts" / "hardener.md").write_text(prompt, encoding="utf-8")
            (run_dir / "prompts" / "hardener.manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        except Exception:
            pass
    write_state(run_dir, state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "role_activated", "role": ns.role})
    print(f"Activated {ns.role} in {ns.run_id}" + (f" specialist={ns.specialist}" if ns.specialist else ""))
    return 0

def cmd_deactivate(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm deactivate")
    parser.add_argument("run_id")
    parser.add_argument("role")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    state = read_state(run_dir) or {}
    if ns.role not in state.get("roles", {}):
        return _error(f"Role {ns.role!r} not in recipe")
    state["roles"][ns.role] = "inactive"
    write_state(run_dir, state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "role_deactivated", "role": ns.role})
    print(f"Deactivated {ns.role} in {ns.run_id}")
    return 0

def cmd_approvals(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm approvals")
    parser.add_argument("run_id")
    parser.add_argument("--json", action="store_true")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    gates = load_approvals(run_dir)
    if ns.json:
        return _json_out(gates)
    if not gates:
        print("No approval gates.")
        return 0
    for g in gates:
        status = "approved" if g.get("approved") else ("rejected" if g.get("rejected") else "pending")
        print(f"{g['id']:15} {status:10} {g.get('description','')[:80]}")
    return 0

def cmd_approve(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm approve")
    parser.add_argument("run_id")
    parser.add_argument("gate_id")
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    g = approve_gate(run_dir, ns.gate_id)
    if not g:
        return _error(f"Gate not found: {ns.gate_id}", hint=f"Available: {', '.join(x['id'] for x in load_approvals(run_dir))}")
    # If plan gate approved, transition to running
    if ns.gate_id == "plan":
        state = read_state(run_dir) or {}
        if state.get("run_state") == "awaiting_plan_approval":
            state["run_state"] = "running"
            write_state(run_dir, state)
            append_trace(run_dir, {"ts": now_ts(), "kind": "approval_granted", "gate": "plan"})
    print(f"Approved {ns.gate_id} for {ns.run_id}")
    return 0

def cmd_reject(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm reject")
    parser.add_argument("run_id")
    parser.add_argument("gate_id")
    parser.add_argument("--reason", required=True)
    ns = parser.parse_args(args)
    repo = _need_repo()
    run_dir = run_dir_for(repo, ns.run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {ns.run_id}")
    g = reject_gate(run_dir, ns.gate_id, ns.reason)
    if not g:
        return _error(f"Gate not found: {ns.gate_id}")
    print(f"Rejected {ns.gate_id} for {ns.run_id}: {ns.reason}")
    return 0

def cmd_handoff_create(args: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="agent-toolkit swarm handoff create")
    parser.add_argument("--type", dest="htype", required=True, choices=["artifact", "commit", "feedback", "decision_request"])
    parser.add_argument("--from", dest="from_role", required=True)
    parser.add_argument("--to", dest="to_role", required=True)
    parser.add_argument("--priority", type=int, default=10)
    parser.add_argument("--artifact", default=None)
    parser.add_argument("--commit", default=None)
    parser.add_argument("--branch", default=None)
    parser.add_argument("--blocking", action="store_true")
    parser.add_argument("--run-id", default=None)
    ns = parser.parse_args(args)
    repo = _need_repo()
    # Resolve run_dir: from --run-id or latest run or env
    run_id = ns.run_id or os.environ.get("AGENT_TOOLKIT_SWARM_RUN_ID")
    if not run_id:
        # Pick latest run
        runs = list_runs(repo)
        if not runs:
            return _error("No run found; specify --run-id")
        run_id = sorted(runs, key=lambda p: p.stat().st_mtime, reverse=True)[0].name
    run_dir = run_dir_for(repo, run_id)
    if not run_dir.is_dir():
        return _error(f"Run not found: {run_id}")
    state = read_state(run_dir) or {}
    roles = set(state.get("roles", {}).keys()) | {"human"}
    data: dict[str, Any] = {"version": 1, "type": ns.htype, "from": ns.from_role, "to": ns.to_role, "priority": ns.priority}
    if ns.artifact:
        # Enforce size limit 1MB
        art_path = run_dir / ns.artifact if not Path(ns.artifact).is_absolute() else Path(ns.artifact)
        # Validate contained
        try:
            validate_artifact_path(run_dir, ns.artifact)
        except ValueError as e:
            return _error(str(e))
        if art_path.is_file() and art_path.stat().st_size > 1_000_000:
            return _error(f"Artifact too large ({art_path.stat().st_size} bytes), max 1MB")
        data["artifact"] = ns.artifact
    if ns.htype == "commit":
        if not ns.commit or not ns.branch:
            return _error("commit handoff requires --commit and --branch")
        # Resolve sha
        sha = ns.commit.strip().lower()
        if not re.match(r"^[0-9a-f]{40}$", sha):
            # Try resolve abbrev
            from .handoff import resolve_sha
            resolved = resolve_sha(repo, sha)
            if not resolved:
                return _error(f"Invalid or ambiguous commit SHA: {ns.commit!r}")
            sha = resolved
        if not validate_commit_exists(repo, sha):
            return _error(f"Commit not found: {sha}")
        data["commit"] = sha
        data["branch"] = ns.branch
    if ns.htype == "feedback":
        data["blocking"] = bool(ns.blocking)
        if data["blocking"]:
            # Enforce max_role_round_trips (default 2)
            try:
                budget = (read_state(run_dir) or {}).get("budget", {}) or {}
                limit = int(budget.get("max_role_round_trips", 2))
                # Count existing blocking feedback reviewer->implementer
                all_states = ["queued", "active", "completed"]
                count = 0
                for st in all_states:
                    for h in list_handoffs(run_dir, st):
                        if h.get("type") == "feedback" and h.get("blocking") and h.get("from") == ns.from_role and h.get("to") == ns.to_role:
                            count += 1
                if count >= limit:
                    return _error(
                        f"The reviewer returned blocking feedback {count} times. The configured round-trip limit ({limit}) has been reached.\n\nInspect:\n  agent-toolkit swarm artifacts {run_id}\n\nChoose:\n  resume with a higher limit\n  escalate to team\n  request human intervention",
                    )
            except Exception:
                pass
    # Validate
    errs = validate_handoff(data, run_dir, roles)
    if errs:
        return _error("Handoff validation failed: " + "; ".join(errs))
    dest = write_handoff_outbox(run_dir, data)
    append_trace(run_dir, {"ts": now_ts(), "kind": "handoff_created", "type": ns.htype, "from": ns.from_role, "to": ns.to_role, "handoff_id": data.get("handoff_id")})
    # Move to queued (simulate daemon)
    hid = dest.stem
    move_handoff(run_dir, hid, "outbox", "queued")
    append_trace(run_dir, {"ts": now_ts(), "kind": "handoff_queued", "handoff_id": hid})
    print(f"Handoff {hid} created: {ns.from_role} -> {ns.to_role} ({ns.htype})")
    return 0

def cmd_task(args: list[str]) -> int:
    if not args:
        print("Usage: agent-toolkit swarm task <next|complete> [options]", file=sys.stderr)
        return 2
    sub = args[0]
    rest = args[1:]
    if sub == "next":
        parser = argparse.ArgumentParser(prog="agent-toolkit swarm task next")
        parser.add_argument("--role", required=True)
        parser.add_argument("--run-id", default=None)
        parser.add_argument("--json", action="store_true")
        ns = parser.parse_args(rest)
        repo = _need_repo()
        run_id = ns.run_id or os.environ.get("AGENT_TOOLKIT_SWARM_RUN_ID")
        if not run_id:
            runs = list_runs(repo)
            if not runs:
                return _error("No run found")
            run_id = sorted(runs, key=lambda p: p.stat().st_mtime, reverse=True)[0].name
        run_dir = run_dir_for(repo, run_id)
        # Find tasks for role in queued
        items = list_handoffs(run_dir, "queued")
        # Filter to_role == role
        candidates = [x for x in items if x.get("to") == ns.role]
        # Sort by priority (lower first? spec says 00 is high)
        candidates.sort(key=lambda x: x.get("priority", 10))
        # Enforce at most one active per task-mode
        active = list_handoffs(run_dir, "active")
        task_mode_active = [x for x in active if x.get("to") == ns.role]
        if task_mode_active:
            # Check receive_mode
            recipe_name = (read_state(run_dir) or {}).get("recipe", "pair")
            recipe = get_recipe(recipe_name) or {}
            rdef = recipe.get("spec", {}).get("roles", {}).get(ns.role, {})
            if rdef.get("receive_mode") != "batch":
                return _error(f"Role {ns.role} already has active task (at most one active task per task-mode role)")
        if not candidates:
            if ns.json:
                return _json_out({"task": None, "message": "No queued tasks"})
            print("No queued tasks")
            return 0
        task = candidates[0]
        hid = task.get("handoff_id")
        if hid:
            move_handoff(run_dir, hid, "queued", "active")
            append_trace(run_dir, {"ts": now_ts(), "kind": "handoff_accepted", "handoff_id": hid, "role": ns.role})
        if ns.json:
            return _json_out(task)
        print(json.dumps(task, indent=2))
        return 0
    elif sub == "complete":
        parser = argparse.ArgumentParser(prog="agent-toolkit swarm task complete")
        parser.add_argument("--handoff", required=True)
        parser.add_argument("--run-id", default=None)
        ns = parser.parse_args(rest)
        repo = _need_repo()
        run_id = ns.run_id or os.environ.get("AGENT_TOOLKIT_SWARM_RUN_ID")
        if not run_id:
            runs = list_runs(repo)
            if not runs:
                return _error("No run found")
            run_id = sorted(runs, key=lambda p: p.stat().st_mtime, reverse=True)[0].name
        run_dir = run_dir_for(repo, run_id)
        hid = ns.handoff
        # Move active -> completed
        src = run_dir / "handoffs" / "active" / f"{hid}.json"
        if not src.is_file():
            # Also check queued
            src2 = run_dir / "handoffs" / "queued" / f"{hid}.json"
            if src2.is_file():
                move_handoff(run_dir, hid, "queued", "completed")
            else:
                return _error(f"Handoff not active: {hid}")
        else:
            move_handoff(run_dir, hid, "active", "completed")
        append_trace(run_dir, {"ts": now_ts(), "kind": "handoff_completed", "handoff_id": hid})
        print(f"Completed handoff {hid}")
        return 0
    else:
        return _error(f"Unknown task subcommand: {sub}")

def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    # Top-level swarm help
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(_SWARM_HELP)
        return 0
    cmd = argv[0]
    rest = argv[1:]
    # Support recipes subcommand alias: `swarm recipes` and `swarm recipe show`
    if cmd == "recipes":
        return cmd_recipes(rest)
    if cmd == "recipe":
        if not rest or rest[0] not in ("show", "list"):
            # if `swarm recipe pair` treat as show
            if rest and rest[0] in list_recipes():
                return cmd_recipe_show(rest)
            print("Usage: agent-toolkit swarm recipe show <name>", file=sys.stderr)
            return 2
        if rest[0] == "show":
            return cmd_recipe_show(rest[1:])
        if rest[0] == "list":
            return cmd_recipes(rest[1:])
    if cmd == "runners":
        return cmd_runners(rest)
    if cmd == "models":
        return cmd_models(rest)
    if cmd == "backends":
        return cmd_backends(rest)
    if cmd == "doctor":
        return cmd_doctor(rest)
    if cmd == "init":
        return cmd_init(rest)
    if cmd == "plan":
        return cmd_plan(rest)
    if cmd == "start":
        return cmd_start(rest)
    if cmd in ("list", "ls"):
        return cmd_list(rest)
    if cmd == "status":
        return cmd_status(rest)
    if cmd == "watch":
        return cmd_watch(rest)
    if cmd == "report":
        return cmd_report(rest)
    if cmd == "artifacts":
        return cmd_artifacts(rest)
    if cmd == "handoffs":
        return cmd_handoffs(rest)
    if cmd == "logs":
        return cmd_logs(rest)
    if cmd == "pause":
        return cmd_pause(rest)
    if cmd == "resume":
        return cmd_resume(rest)
    if cmd == "stop":
        return cmd_stop(rest)
    if cmd == "cancel":
        return cmd_cancel(rest)
    if cmd == "cleanup":
        return cmd_cleanup(rest)
    if cmd == "attach":
        return cmd_attach(rest)
    if cmd == "promote":
        return cmd_promote(rest)
    if cmd == "activate":
        return cmd_activate(rest)
    if cmd == "deactivate":
        return cmd_deactivate(rest)
    if cmd == "approvals":
        return cmd_approvals(rest)
    if cmd == "approve":
        return cmd_approve(rest)
    if cmd == "reject":
        return cmd_reject(rest)
    if cmd == "handoff":
        # expect subcommand create
        if rest and rest[0] == "create":
            return cmd_handoff_create(rest[1:])
        return _error(f"Unknown handoff subcommand: {rest[0] if rest else ''}", hint="Usage: agent-toolkit swarm handoff create ...")
    if cmd == "task":
        return cmd_task(rest)
    print(f"Unknown swarm command: {cmd}", file=sys.stderr)
    print("Run 'agent-toolkit swarm --help' for usage.", file=sys.stderr)
    return 1

_SWARM_HELP = """agent-toolkit swarm — Backend-neutral local multi-agent swarm orchestration

Usage:
  agent-toolkit swarm <command> [args...]

Discovery:
  recipes                 List available recipes (pair, team, full)
  recipe show <name>      Show recipe details
  runners                 List runner capability matrix
  models [--runner NAME]  List models / profiles
  backends                List UI backends and availability
  doctor [--json]         Check swarm prerequisites

Init & Plan:
  init [--workspace PATH] [--recipe NAME] [--force]
  plan [--recipe NAME] [--ui auto|herdr|tmux] [--runner NAME] [--model-profile balanced|economy|quality|private] [--request-file PATH] [--issue OWNER/REPO#NUM] [--json] "task..."

Run:
  start [same options as plan] [--base-ref REF] [--json] "task..."
  list [--json]            List all runs
  status [RUN_ID] [--json] Show run status
  watch [RUN_ID]           Tail run trace
  report RUN_ID [--json]   Show final report
  artifacts RUN_ID [--json]
  handoffs RUN_ID [--json]
  logs RUN_ID [ROLE] [--json]

Lifecycle:
  pause RUN_ID
  resume RUN_ID
  stop RUN_ID
  cancel RUN_ID
  cleanup RUN_ID [--force] [--dry-run]
  attach RUN_ID

Elastic:
  promote RUN_ID --to team|full
  activate RUN_ID ROLE
  deactivate RUN_ID ROLE

Human decisions:
  approvals RUN_ID [--json]
  approve RUN_ID GATE_ID
  reject RUN_ID GATE_ID --reason "..."

Handoffs:
  handoff create --type artifact|commit|feedback|decision_request --from ROLE --to ROLE [--priority N] [--artifact PATH] [--commit SHA --branch BRANCH] [--blocking]
  task next --role ROLE [--run-id ID] [--json]
  task complete --handoff ID [--run-id ID]

Examples:
  agent-toolkit swarm plan --recipe pair --ui auto --runner opencode --model-profile balanced "Implement issue #123"
  agent-toolkit swarm start --recipe pair --ui herdr --runner opencode --model-profile balanced "Implement issue #123"
  agent-toolkit swarm start --recipe pair --ui tmux --runner opencode "Fix bug in auth cache"

Docs: docs/SWARMS.md, docs/SWARM_ARCHITECTURE.md
"""
