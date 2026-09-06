# Desktop Engine truth ledger

Status: S7 audit baseline, 2026-09-06, `origin/main cf4a4eb8`. This ledger classifies
every Desktop Engine value by authority and records the replacement source for
each contaminated API. It is the contract for S7 slices: **if Agent Toolkit
cannot prove a fact, it must not manufacture it.** Unknown, unavailable, empty
and unverified are valid states.

## Authority classes

| Class | Meaning | Canonical sources |
|---|---|---|
| PRODUCT / CATALOG TRUTH | What Agent Toolkit bundles/supports | `skills/`, `agents/`, `mcp/templates/`, `loops/`, `packs/`, `distributions/products.yaml`, `capabilities/targets/registry.yaml`, `catalogs/` — read only through tier-aware `data_*` helpers |
| CONFIGURATION / INSTALLATION TRUTH | What this user/workspace configured | `StateRepository` snapshot keys; core install receipts at `XDG_CONFIG_HOME/agent-toolkit/receipts`; absence means absent, never a convenient default |
| RUNTIME TRUTH | What is happening now | Process supervisor, PTYs, job/loop/swarm state transitions, event bus; `Engine.runtime_path` for mutable artifacts |
| EVIDENCE / RECEIPT / PROVENANCE TRUTH | Claims about artifacts | `agent_toolkit_core.receipt.v` (typed InstallReceipt, real digests), `plugins/*/.provenance.json` manifests (ADR-022); verification = recomputed SHA-256 of real bytes matches the recorded digest |

## Path authorities

| Authority | Root | Access |
|---|---|---|
| Bundled catalog data | `resolve_env().toolkit_root` (may be abstract `embedded`) | `data_file_exists` / `data_file_read` / `data_dir_exists` / `data_list_dir` only |
| User application config | `XDG_CONFIG_HOME/agent-toolkit` (receipts under `receipts/`) | core `FsService`; direct `os` is acceptable (real user paths) |
| Desktop derived state | `EngineConfig.persist_path` (XDG cache) | `StateRepository` |
| Runtime artifacts | `Engine.runtime_path` (derived from persist_path) | `os` (mutable scratch) |
| Active workspace | harness root / `recent_workspace` — never `toolkit_root` | `os` with validated paths |

## Contamination inventory and replacements

Severity: B = blocker, H = high, M = medium. Status: pending slices S7A–S7F.

| File | Finding | Sev | Replacement source | Slice |
|---|---|---|---|---|
| `git_service.v` | Entire API fabricated: fake authors, synthetic hashes/timestamps/messages, hardcoded diffs; real `.git` probe is dead code | B | Typed Git read backend over the active workspace; explicit empty/unavailable until it exists | S7C |
| `git_service.v` | Raw `os.join_path(toolkit_root, '.git')` | M | Workspace-rooted probe via workspace authority | S7C |
| `targets_service.v` | State-only `install()` writes fake receipts (`1.27.0`, `sha256:${len*13}`), no profile files written | B | `capabilities/targets/registry.yaml` roster + `agent_toolkit_core.run_install` real install + real `load_install_receipt` | S7B |
| `targets_service.v` | Default-enabled `claude-code`/`cli` with no configuration | M | Enabled only from explicit config state | S7B |
| `targets_service.v` | Duplicated 7-target roster; hardcoded version/digest in `install_receipt_json` | H | Registry.yaml; real receipt fields or none | S7B |
| `targets_service.v` | `doctor_fix_stamp` fabricates receipt evidence instead of repairing | H | Fix only what is actually repaired; missing receipt stays missing | S7B |
| `update_service.v` | Entire feed hardcoded (`1.27.1`, `abc123sha256`); `verify()` ignores content; `apply()` state-only | B | Verified release feed or explicit unavailable; no apply until a real updater exists | S7E |
| `skills_service.v` | `install_skill` writes `sha256:${id.len + set.len}` digests as receipts | B | Selection is config truth only; no receipt keys without real receipts | S7A |
| `skills_service.v` | `skill_provenance` fabricates `sha256:${id.len * 11}` with `verified: true`; `sha256:abc` fallback | H | Real provenance from `plugins/*/.provenance.json` artifact records; none otherwise | S7A |
| `skills_service.v` | `build_check` only fires on magic `broken_skill` state key / `broken` substrings | H | Real check: installed skills must resolve in catalog; beta stability from catalog | S7A |
| `skills_service.v` | `build_preview` "plugins-digest" is a sum of string lengths | H | Real SHA-256 of canonical catalog material | S7A |
| `agents_service.v` | `install_agent` state-only receipt (`1.0.0`, constructed path) | B | Selection config truth; real receipt evidence from plugin install artifacts | S7A |
| `agents_service.v` | Hardcoded tier lists, invented triggers, default `architect` owner | H/M | AGENT.md frontmatter / agent catalog | S7D |
| `agents_service.v` | `agent_provenance_detail` emits `verified: 'true'` unconditionally | H | Real provenance scan; false/none otherwise | S7A |
| `loops_service.v` | Fabricated 10-loop fallback catalog with fake spend and future `next_run` | B | Bundled loops via data_* (already S1); empty when absent | S7D |
| `loops_service.v` | Synthetic history rows, "treat synthetic history as completed", invented cost tiers | H | Real state history only; measured or unknown | S7D |
| `receipts_service.v` | `sha256:abc`/`sha256:def`/`sha256:123` placeholders, unconditional `verified: true` | H | `agent_toolkit_core.list_install_receipts` + recomputed artifact digests | S7A |
| `receipts_service.v` | Receipt dir read at `toolkit_root/.config` (wrong authority; raw os on embedded) | H | Core `default_receipt_dir()` (user config authority) | S7A |
| `receipts_service.v` | `.provenance.json` scan uses raw os + file-length "digests"; fabricated embedded fallback | H | Tier-aware `data_*` reads + real SHA-256 of artifact bytes | S7A |
| `memory_service.v` | Raw os on `toolkit_root` (embedded → cwd); 8 demo palace entries | H | Workspace-rooted knowledge via data_*; empty when empty | S7E |
| `workspace_service.v` | `active_workspace_root` falls back to `toolkit_root` | H | Empty/unavailable without a configured workspace | S7E |
| `workspace_service.v` | `git_status_for` filename-pattern "modified" badges | H | No git status without a git backend | S7C |
| `workspace_service.v` | Placeholder tree node, fabricated "init memory" entry, `saved_at '0'` | M | Empty state | S7E |
| `jobs_service.v` | `job_complete` writes three length-derived digests | H | Runtime state only; no receipt/provenance keys | S7A |
| `jobs_service.v` | Missing exit code defaults to 0; supervisor spawn failure swallowed as success | M/H | Unknown stays unknown; failures recorded as failed | S7E |
| `swarm_service.v` | State-only `running`, invented budget, fabricated log lines | H | Real backend launch or `requested`; logs only from records | S7E |
| `mcp_service.v` | Enabled providers are `healthy` without probing; `broken_mcp` fixture-keyed validation; toggle installs invented npx config; fabricated registry path | H | Packaged template content via data_*; honest `configured` state; real template schema parse validation | S7A |
| `products_service.v` | `1.27.0` on every product; invented membership fallback; fake membership digest; fabricated `installed_at` | H | products.yaml; membership from config only; real provenance sidecar evidence | S7A |
| `engine.v` | Doctor "sha verified" pass without verification; unconditional passes; hardcoded target roster; magic `116` | H | Real checks or honest warns; registry-derived roster | S7E |
| `di.v` | Undocumented `cwd` tier fallback | M | Document the ladder; embedded tier must not silently become cwd | S7E |
| `onboarding_service.v` | State-only target enabling; hardcoded persona templates | H/M | Config truth + canonical agent/persona sources | S7B/D |

## Evidence semantics (adopted in S7A)

An Engine action that only records configuration state is **configuration**, not
installation. States are distinguished as:

- `selected/configured` — state key recorded (e.g. `installed_skills`);
- `receipt recorded` — a real receipt file exists under the user config receipts
  dir (written only by an operation that actually deployed artifacts);
- `provenance recorded` — a real `.provenance.json` manifest exists with source
  digests;
- `provenance verified` — recomputed SHA-256 of the referenced bytes matches the
  recorded digest;
- `unavailable/none` — no evidence exists; never substituted.

A receipt or provenance entry that cannot be verified reports `verified: false`
with the reason; it is never dropped or silently marked true.

## Regression gates

- A fresh Engine yields zero receipts and zero provenance entries.
- No production digest is derived from string lengths or placeholders
  (`sha256:abc`-style values are forbidden in production output).
- `verified` is true only after a real verification operation.
- Receipt lookups never synthesize timestamps/versions.
- Typed tests in `modules/desktop_engine/evidence_truth_test.v` enforce these;
  grep-style gates are avoided.
