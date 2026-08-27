# Troubleshooting — Doctor & CLI error recipes

Actionable fixes for the top failure modes reported by `agent-toolkit doctor` and `install`.

## 1. Missing toolkit data

**Symptom:** `doctor` reports `data missing` or `skills: 0`.

**Cause:** installed from source tarball without bundled data.

**Fix:**

```bash
uv tool install --force agent-toolkit-cli   # wheel with data
# or, from source checkout:
scripts/prepare-package-data.sh
agent-toolkit install
```

See `docs/INSTALLATION.md` and `docs/GETTING_STARTED.md`.

## 2. Wrong tool path

**Symptom:** `install --target <tool>` copies to unexpected directory.

**Fix:**

```bash
agent-toolkit doctor          # shows detected paths per tool
agent-toolkit install --target muse-code --dry-run   # preview
```

Per-tool paths are tabled in `docs/INSTALLATION.md`.

## 3. Partial install (skills without agents/loops)

**Symptom:** `doctor` shows `skills: 80, agents: 0` or similar.

**Fix:**

```bash
agent-toolkit build
agent-toolkit install --force
```

See `docs/CONCEPTS.md` layer hierarchy.

## 4. Stale catalog

**Symptom:** CI `generate-catalogs` check fails.

**Fix:**

```bash
./scripts/generate-catalogs.vsh
git add catalogs/
```

See `CONTRIBUTING.md` Validation Commands.

## 5. Surface drift

**Symptom:** `agent-toolkit build --check` or `agent-toolkit plugin check` fails.

**Fix:**

```bash
./make.vsh build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
# Plugin surface copy/compare (core/agents/forge):
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit plugin check
# To sync plugin bundles from canonical sources:
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit plugin sync
```

See `docs/CONCEPTS.md` and `docs/ARCHITECTURE.md` ADR-003/004.

## 6. Swarm: Herdr not found

**Symptom:** `agent-toolkit swarm start --ui herdr` fails with "Herdr was explicitly requested but was not found."

**Fix:**

```bash
herdr --version                # check presence
# Install per https://herdr.dev/docs/install/
brew install herdr              # macOS
curl -fsSL https://herdr.dev/install.sh | sh   # Linux
# Or use portable fallback:
agent-toolkit swarm start --ui tmux ...
```

## 7. Swarm: Runner not found

**Symptom:** `runner opencode not found` or model unavailable.

**Fix:**

```bash
agent-toolkit swarm runners    # capability matrix
agent-toolkit swarm models --runner opencode
opencode models
# Use skeleton for dry-run:
agent-toolkit swarm start --runner skeleton "task"
```

## 8. Swarm: Worktree dirty

**Symptom:** `Worktree contains uncommitted changes. Toolkit will not remove it.`

**Fix:** commit or stash inside worktree, then `agent-toolkit swarm cleanup RUN_ID` or with `--force` if intentional.

## 9. Swarm: Blocking feedback loop

**Symptom:** `The reviewer returned blocking feedback twice. The configured round-trip limit has been reached.`

**Fix:**

```bash
agent-toolkit swarm artifacts RUN_ID
agent-toolkit swarm handoffs RUN_ID
# Then choose: resume with higher limit, promote to team, or human intervention
```

See [SWARMS.md](SWARMS.md) and [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (handoffs, worktrees, budgets). Cross-links: [SWARM_HERDR.md](SWARM_HERDR.md) (Herdr plugin), [SWARM_TMUX.md](SWARM_TMUX.md) (tmux fallback), [SWARM_SECURITY.md](SWARM_SECURITY.md) (privacy), [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) (offline/skeleton).

## 10. Swarm: Privacy / Secrets in logs

**Symptom:** worried about credentials in `state.json` / `trace.jsonl`.

**Fix:** secrets are redacted by `sanitize_args()` (`token`/`secret`/`key`/`password` → `[REDACTED]`), credentials never serialized, env scoped per process, generic UI wake-ups only. No cloud upload or transcript storage by default (opt-in with warning). See [SWARM_SECURITY.md](SWARM_SECURITY.md).

## 11. Swarm: Cleanup safety

**Symptom:** unsure if `cleanup` will delete user branches/worktrees.

**Fix:** `cleanup` removes only Toolkit-owned worktrees under `.agent-toolkit/swarm/runs/<run-id>/worktrees/`; refuses dirty (`git status --porcelain`) without `--force`; never deletes branches or user worktrees; fail-closed on unclear ownership. `stop` preserves state. See [SWARM_TMUX.md](SWARM_TMUX.md) and [SWARM_SECURITY.md](SWARM_SECURITY.md).

## 12. Swarm: Offline / Fake demo

**Symptom:** want to explore swarms without Herdr or LLM (air-gapped, CI).

**Fix:**

```bash
agent-toolkit swarm plan --recipe pair --ui tmux --runner skeleton "demo" --json   # side-effect free
agent-toolkit swarm start --runner skeleton --ui tmux "offline demo"
agent-toolkit swarm models --runner skeleton --profile balanced
```

`--runner skeleton` (always available) + `--ui tmux` works fully offline. `plan` never creates worktrees. See [SWARMS.md](SWARMS.md) and [SWARM_TMUX.md](SWARM_TMUX.md).

---

If none of these match, run `agent-toolkit doctor --verbose` and open an issue with the output (redact paths if needed).

## 13. Provenance: upstream.lock missing or mutable ref

**Symptom:** `agent-toolkit doctor` → `provenance: upstream.lock exists` `✗ Missing` or `provenance:<id> immutable` `ref without commit — mutable` or `lock version` `⚠ version=2 expected 1` (legacy) or `commit ... not SHA40`.

**Cause:** `SKILL.md` `sources[].ref` is a tag/branch without `commit` pin, or lock not generated.

**Fix:**

```bash
# Ensure SKILL.md has immutable pin
#   sources:
#     - id: upstream
#       repository: org/repo
#       ref: v1.2.3        # requested tag
#       commit: abc123...  # 40-char SHA (resolved)

python3 scripts/provenance.py lock      # resolve declarations → capabilities/upstream.lock
python3 scripts/provenance.py check     # offline validation declaration↔lock + checksums + digest + review binding
python3 scripts/provenance.py docs      # regenerate docs/UPSTREAM.md
```

See `docs/adrs/0001-capability-declaration-and-external-provenance-lock.md` (declaration → lock → vendored → sources) and `scripts/provenance.py {lock,check,docs,updates}`.

## 14. Provenance: staleness >90d

**Symptom:** `provenance:<id> freshness` `⚠ 95d ago (>90d) — consider update`

**Fix:**

```bash
python3 scripts/provenance.py updates   # compare locked commits to remote HEAD
# open update PR with new commit/digest
```

Provenance `reviewed_provenance` binds human review to old bytes — lock update invalidates prior review.

## 15. Packs: complete covers all skills

**Symptom:** `packs: complete covers all skills` `✗ missing ['architecture/c4-model', ...]`

**Fix:**

```bash
# Add skill to distributions/products.yaml agent-toolkit-complete includes.skills
# Then regenerate matrix:
./scripts/generate-skill-matrix.vsh
./scripts/generate-skill-matrix.vsh --check  # CI gate
```

See `docs/compatibility/matrix-generation.md` (matrix generated from `distributions/products.yaml` + `skills-layout.json`).

## 16. MCP registry: transport/implementation

**Symptom:** `mcp:<name> id` `✗ missing id` or `mcp:<name> transport` `⚠ no transport/implementation`

**Fix:** check `mcp/registry/*.yaml` frontmatter (`id`, `transport`/`implementation`, `platforms`). See `docs/MCP.md`.

## 17. Ask skill: post-archive Confluence JIRA

**Symptom:** `ask` skill at repo root references Confluence JIRA stack after archive.

**Fix:** `ask` is evaluated as `UNKNOWN` then `REJECT` per vendor evaluation — not a `doctor` gate. Use `jira-*` / `confluence-*` skills via `mcp/registry` + `providers/providers.yaml` (Atlassian Rovo official) instead.

