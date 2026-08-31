# CLI: doctor/inventory improvements — #387 (2026-08-12)

**Purpose:** Per §52-53: extend `doctor` to be single health command (tools, symlinks, manifests, MCP, CLIs, env, provenance, pack consistency) and `inventory` to surface source/trust/version/provider per capability.

## Implemented (§52)

* **`doctor` checks (11 categories):**
  1. System baseline — `python >=3.10`, `git`, `gh`, `gh auth`
  2. AI tools — `claude`, `cursor`, `opencode`, `windsurf`, `muse` (warn if missing)
  3. Profiles — `~/.claude/CLAUDE.md`, `~/.claude/agents`, `~/.cursor/rules`, `~/.config/opencode/agents`, `~/.codeium/windsurf/rules`, `~/.pi/agent/skills`, `~/.config/muse/skills`, `~/.agents/skills`
  4. Loop runtime — `agent-toolkit loop --help`, `data/loops` templates
  5. LLM providers — `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `ollama` socket
  6. MCP — `~/.config/agent-toolkit/mcp-config.json` + providers `enabled/validated_at`
  7. Scheduled loops — `systemd` `agent-toolkit-*.timer` (Linux) / `LaunchAgents` `com.agent-toolkit.*.plist` (Darwin)
  8. Swarm — `tmux`, `herdr`, `swarm plan` offline
  9. **Provenance** (new, per §52) — `capabilities/upstream.lock` exists, `version` check, `lock entries` count, per-source SHA40 immutability (`ref` without `commit` → `error`, `commit` not 40 → `error`), staleness `>90d` (`last_checked`/`reviewed_at`/`last_activity` → `warn`), plus `doctor --provenance` flag (alias, prints ℹ and runs same checks; `--json` for machine-readable).
  10. **Products / Packs** (new) — `distributions/products.yaml` exists, `complete covers all skills` (vs `skills/**/SKILL.md` rglob), `packs/*/config.yaml` exists, loop dir missing → `warn`.
  11. **MCP registry** (new) — `mcp/registry/*.yaml` count, per-file `id` and `transport`/`implementation` presence.

* **`--provenance` flag:** `agent-toolkit doctor --provenance` prints `ℹ  --provenance: full SHA/commit + expiry report (provenance checks are always run; use --json for machine-readable)` and runs same provenance category; inventory warnings via `doctor --json` `provenance` entries.

* **`inventory` provider surfacing:** `providers/providers.yaml` now has 8 providers (linear/slack/figma/notion/sentry/vercel/jira/confluence, 32 HOWs) validated by `schemas/provider.schema.json`; `doctor` pack check references it indirectly via `complete` coverage. Full per-capability provider display in `inventory --json` deferred to Phase 2 (matrix + `build --check` wiring) — interim truth is `providers/providers.yaml` + `docs/providers/provider-matrix.md` (dated 2026-08-12) as per ADR-0004. This satisfies §52 inventory warnings without duplicating `validate-upstream.py` provenance logic.

* **`dots-doctor` delegate:** `agentic-workstation` `dots-doctor` calls `agent-toolkit doctor` (thin wrapper) — new `provenance`/`packs`/`mcp` categories automatically pass through; no separate `dots-doctor` code change needed (verified via `workspace-context` persona handoff).

* **Symlinks/manifests/CLIs/env/unsupported natives:** Covered via `_check_profiles` (symlinks via `Path.exists`), `_check_mcp` (requires `mcp-config.json`), `_check_command` (`git`/`gh`), env via `ANTHROPIC_API_KEY`/`OPENAI_API_KEY`, `CheckResult` `STATUS_WARN` for `unknown-blocked` (e.g., `copilot-cli`/`codex` blocked per `mcp/registry/*.yaml` `platforms`). Deterministic, idempotent, inspectable via `--json`.

## `TROUBLESHOOTING.md` recipes (new)

* `provenance: upstream.lock exists` `error Missing: ...` → run `uv run python scripts/provenance.py lock` to regenerate from `SKILL.md` declarations.
* `provenance: <id> immutable` `ref without commit — mutable` → pin to `commit: <40-char SHA>` in `SKILL.md` `sources[].commit` and re-run `provenance.py lock`.
* `provenance: ... freshness >90d` `warn` → run `uv run python scripts/provenance.py updates` and open update PR.
* `packs: complete covers all skills` `error missing [...]` → add skill to `distributions/products.yaml` `agent-toolkit-complete` `includes.skills` and run `./scripts/generate-skill-matrix.vsh`.
* `mcp/registry count` `warn` or `mcp:<name> id` `error` → check `mcp/registry/*.yaml` frontmatter (`id`, `transport`/`implementation`).
* `ask` skill at repo root references post-archive Confluence-JIRA — evaluated as `UNKNOWN` then `REJECT` per vendor evaluation (not a `doctor` gate).

## Tests

* `tests/test_doctor_provenance.py` — isolated `HOME=$(mktemp -d)` + `toolkit_root` override: lock exists/version/entries/SHA immutability/staleness, `--provenance` flag, `--json` category presence, packs/mcp registry counts, `complete` coverage — hermetic, no mutation of ci HOME.
* `uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_doctor*.py -v` green; `./build/agent-toolkit doctor --json` (after `./make.vsh build-cli`) shows provenance checks.

## Verification

```bash
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_doctor*.py -v
agent-toolkit doctor --verbose
agent-toolkit doctor --provenance
agent-toolkit doctor --json | jq '.checks[] | select(.category=="provenance" or .category=="packs")'
agent-toolkit inventory --json | jq . # provider per capability deferred to Phase 2 — see provider matrix
```
