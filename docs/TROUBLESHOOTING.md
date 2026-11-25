# Troubleshooting — Doctor & CLI error recipes

Actionable fixes for the top failure modes reported by `agent-toolkit doctor` and `install`.

## 1. Missing toolkit data

**Symptom:** `doctor` reports `data missing` or `skills: 0`.

**Cause:** installed from source tarball without bundled data.

**Fix:**

```bash
uv tool install --force agent-toolkit-cli   # wheel with data
# or, from source checkout:
scripts/prepare-package-data.vsh
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

## 6. Existing Swarm v1 records

New Swarm v1 `start` and `init` requests are disabled in current Toolkit builds.
Use Veasel Code for new orchestration. Existing Swarm records and worktrees
remain user-owned; do not run cleanup or prune unless you have reviewed and
backed up the exact paths. For supported inspection and recovery commands, see
[the Swarm v1 disposition](SWARM_V1_DISPOSITION.md).

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
