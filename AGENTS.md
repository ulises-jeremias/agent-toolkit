# AGENTS.md — AI Agent Contract

**Purpose:** the repository-wide operating contract for AI agents and automated contributors. Read this before modifying any file. More specific scoped instructions, when present, refine this contract for their subtree.

## What this repository is

`agent-toolkit` is the portable capability ecosystem and native CLI for reusable skills, agent definitions, MCP templates, workflow recipes, target profiles, and provenance. It is not a supported coding Desktop or a second coding-session runtime. **Veasel Code** is the associated coding product, designed around one TUI/Desktop backend and session store; packaged shared-session acceptance remains open in [Veasel #550](https://github.com/veasel-labs/veasel/issues/550). The official Veasel plugin catalog lives in [`veasel-labs/agent-toolkit`](https://github.com/veasel-labs/agent-toolkit).

Operate precisely: use canonical sources, preserve public/vendor-neutral boundaries, cite evidence, and validate before finalizing.

## Canonical document map

Use the narrowest current source of truth instead of old issue prose or historical comments.

| Concern | Canonical source |
|---|---|
| Public concept model / boundaries | [`docs/CONCEPTS.md`](docs/CONCEPTS.md) |
| Architecture decisions | [`docs/adrs/`](docs/adrs/) |
| Skill authoring/integration | [`docs/SKILL_INTEGRATION_CHECKLIST.md`](docs/SKILL_INTEGRATION_CHECKLIST.md), [`docs/UPSTREAM_VS_FIRST_PARTY.md`](docs/UPSTREAM_VS_FIRST_PARTY.md) |
| Agent personas | [`docs/HOW_TO_ADD_AGENT.md`](docs/HOW_TO_ADD_AGENT.md) |
| Loop templates | [`docs/HOW_TO_CREATE_LOOP.md`](docs/HOW_TO_CREATE_LOOP.md), [`schemas/loop.schema.json`](schemas/loop.schema.json) |
| V development | [`docs/HOW_TO_DEVELOP_V.md`](docs/HOW_TO_DEVELOP_V.md) |
| Veasel integration and legacy Toolkit Desktop data boundary | [`docs/VEASEL_COMPATIBILITY.md`](docs/VEASEL_COMPATIBILITY.md) |
| Historical Electron Desktop evidence | [`docs/desktop/README.md`](docs/desktop/README.md); archive only, not a current product contract |

Historical ADRs and GitHub issues are evidence, not automatic implementation authority. Reconcile them with current code and governing contracts before acting.

## Instruction precedence inside this project

Repository work should follow, in order:

1. explicit current task requirements;
2. this `AGENTS.md` and any scoped descendant instructions;
3. current ADRs and canonical domain contracts;
4. current product/UX/design contracts;
5. current verified code/tests/runtime behavior;
6. GitHub issue implementation details;
7. historical plans/comments.

This project ordering does not override system/developer/runtime instructions from the agent platform itself.

## Global invariants

### Always

- Use English for repository content, commits, issues, and PR descriptions.
- Keep secrets, credentials, tokens, private-company content, and private customer data out of this public repository.
- Prefer canonical catalogs/manifests/core operations over duplicated hardcoded rosters.
- Cite the file/contract behind repository conventions when making architectural claims.
- Inspect current code and generated sources before claiming compatibility or completion.
- Work in focused branches/PRs for implementation unless the maintainer explicitly requests another workflow.
- Preserve user-owned files and report partial failure honestly.

### Never

- Manufacture plausible production state, progress, health, receipts, provenance, compatibility, costs, activity, or Git history.
- Hand-edit generated catalogs/manifests when a generator owns them.
- Commit credentials or real secret values to MCP templates/examples.
- Claim tool compatibility without evidence from metadata, tests, or explicit supported behavior.
- Add private-organization-specific content to first-party public capabilities.
- Add third-party npm/GitHub/URL packs to `distributions/products.yaml` or generated plugin surfaces; follow the third-party boundary in `docs/CONCEPTS.md`.
- Bypass branch protection or weaken validation merely to land a change.

Unknown, unavailable, empty, and unverified are valid states. Fabricated-but-plausible is not.

## Repository ownership model

Key source areas:

- `skills/` — first-party reusable capability sources (`SKILL.md`)
- `agents/` — tool-agnostic personas (`AGENT.md`)
- `loops/` — loop templates (`loop.yaml`)
- `mcp/` — provider registry/templates
- `profiles/` — target-specific adapters/overlays
- `packs/` — solution/workflow packs
- `capabilities/` — declarative capability registries (targets, skills, hooks); canonical source for supported-target and capability truth
- `distributions/` — product compiler input
- `plugins/` — generated distribution surfaces; do not hand-edit unless the owning contract explicitly says otherwise
- `catalogs/` — generated discovery catalogs
- `schemas/` — validation schemas (skills, agents, loops, targets, products)
- `modules/agent_toolkit_core/` — shared core/domain implementation
- `modules/agent_toolkit_server/` — typed HTTP API over the canonical V domain
- `cmd/agent-toolkit/` — native V CLI entrypoint
- `packages/` — PyPI/npm launcher trampolines
- `tests/` — parity, security, and adapter test suites
- `docs/` — human-facing contracts, guides, ADRs
- `scripts/` — validation/generation automation

## Generated files

These are generated and must not be manually edited:

- `catalogs/skill-catalog.yaml`
- `catalogs/agent-catalog.yaml`
- `catalogs/loop-catalog.yaml`
- `catalogs/skills-layout.json`

Regenerate/check with:

```bash
./scripts/generate-catalogs.vsh
./scripts/generate-catalogs.vsh --check
```

If another file is generated, follow its owning ADR/script rather than editing around the generator.

## Skills

Before adding a skill:

1. search `catalogs/skill-catalog.yaml` and existing first-party skills;
2. read [`docs/UPSTREAM_VS_FIRST_PARTY.md`](docs/UPSTREAM_VS_FIRST_PARTY.md);
3. prefer enhancing an existing first-party capability over vendoring a duplicate;
4. follow [`docs/SKILL_INTEGRATION_CHECKLIST.md`](docs/SKILL_INTEGRATION_CHECKLIST.md).

A skill lives at `skills/<domain>/<skill>/SKILL.md`. Required and optional frontmatter (name, description, metadata, domain, tools, requires, triggers) is validated against [`schemas/skill-md-frontmatter.schema.json`](schemas/skill-md-frontmatter.schema.json). Every distributable `SKILL.md` must declare `origin: {type: first-party|upstream}`: `scripts/validate-upstream.py` enforces this for every `SKILL.md` (gate 2, see [`docs/TRUST.md`](docs/TRUST.md)), although the schema keeps `origin` optional for backwards compatibility.

Validate skill changes with at least:

```bash
./scripts/validate-skills.vsh
./scripts/generate-catalogs.vsh --check
AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check
```

Use additional checks required by the integration checklist.

## Agent personas

Personas live under `agents/<name>/AGENT.md`. Keep directory/name/frontmatter aligned and follow [`docs/HOW_TO_ADD_AGENT.md`](docs/HOW_TO_ADD_AGENT.md).

Validate with:

```bash
./scripts/validate-agents.vsh
./scripts/generate-catalogs.vsh --check
```

Do not confuse persona `AGENT.md` files with this repository-wide `AGENTS.md` contract.

## Loops

Loop definitions live in `loops/<name>/loop.yaml`. `STATE.md` and `report.md` are runtime artifacts and must not become committed template state unless a current contract explicitly says otherwise.

Follow [`docs/HOW_TO_CREATE_LOOP.md`](docs/HOW_TO_CREATE_LOOP.md) and validate with:

```bash
./scripts/validate-loops.vsh
./scripts/generate-catalogs.vsh --check
```

Never weaken L1/L2/L3 mutation boundaries, allow/deny semantics, budgets, or exit conditions casually.

## Profiles, MCP, products, and packs

Profiles adapt canonical Agent Toolkit capabilities to supported coding tools. Keep target-specific behavior in the appropriate profile/emitter layer rather than duplicating source capabilities. Profile layout and authoring follow [`docs/PROFILES.md`](docs/PROFILES.md).

MCP templates use placeholders only. Never commit real credentials. Separate provider/catalog support from user configuration and runtime health.

Products/packs must follow current compiler and concept contracts. Treat generated plugin manifests as outputs, not primary authoring surfaces.

## Former Electron Desktop (retired)

The former Electron application (`apps/desktop/`) has been retired and removed from `main` (preserved in Git history). New Toolkit releases do not publish Desktop installers, and graphical/session features belong in Veasel Code. Consult [`docs/VEASEL_COMPATIBILITY.md`](docs/VEASEL_COMPATIBILITY.md) for compatibility and user-data boundaries.

- Do not restore an Electron app, Electron CI/release channels, or advertise a Toolkit Desktop launcher.
- Never delete or rewrite a user's historical Electron `userData`, workspace journals, MCP credentials, skills, profiles, or other local state. Do not claim Veasel imports this state unless a tested importer exists.
- Put current graphical product changes in `veasel-labs/veasel`; keep portable capabilities here and marketplace governance in `veasel-labs/agent-toolkit`.
- Historical screenshots and workflow records under `docs/desktop/` are archive evidence only. They do not prove current Veasel behavior or packaged acceptance.

## Validation by change type

Use the smallest matrix that honestly covers the changed surface, plus any checks required by the touched contract/CI.

| Change | Minimum focused validation |
|---|---|
| Skill | `validate-skills`, catalog check, relevant build/integration |
| Agent persona | `validate-agents`, catalog check |
| Loop | `validate-loops`, catalog check |
| Catalog/compiler/profile | generator check, `build --check`, relevant target tests |
| V core/CLI | relevant V tests, `./make.vsh build-cli`, integration where affected |
| Packaging | platform/package-specific checks plus clean-launch evidence |
| Docs-only | formatting/link/repository validation affected by the docs; no unrelated expensive suite merely for ceremony |

Repository-wide primary validation currently includes:

```bash
./scripts/validate-skills.vsh
./scripts/validate-agents.vsh
./scripts/validate-loops.vsh
./scripts/generate-catalogs.vsh --check
./make.vsh test
./make.vsh build-cli
AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check
```

Check `.github/workflows/` before assuming this list exactly matches current CI.

Adapter-only validation when those launchers change:

```bash
AGENT_TOOLKIT_ROOT="$PWD" uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
npm test --prefix packages/npm/agent-toolkit-cli
```

Follow `.v-version` and [`docs/HOW_TO_DEVELOP_V.md`](docs/HOW_TO_DEVELOP_V.md) for V-specific constraints.

## Git and PR discipline

- Start focused implementation from fresh canonical `main` unless intentionally targeting another base.
- Keep PRs coherent and reviewable; do not recreate monolithic salvage branches.
- Do not push implementation directly to protected `main` unless the maintainer explicitly requests/directs that exception.
- Wait for actual required CI before declaring a PR complete.
- Investigate reproducible failures instead of labeling them infrastructure casually.
- Merge only when required CI and review obligations are satisfied.
- Do not publish releases/packages without explicit authorization.

For Veasel integration or distribution PRs, include user impact, ownership and data implications, validation evidence, and known limitations. Do not use screenshots from the former Toolkit Desktop as current product evidence.

## Ecosystem boundary

Agent Toolkit must remain usable on its own. `agentic-workstation`, `agentic-harness`, My AI Workspace, and related repositories may integrate through explicit contracts, but they are not mandatory runtime dependencies for the Agent Toolkit CLI or its portable capabilities.

Cross-repo references:

- [agentic-workstation AGENTS.md](https://github.com/ulises-jeremias/agentic-workstation/blob/main/AGENTS.md)
- [agentic-harness AGENTS.md](https://github.com/ulises-jeremias/agentic-harness/blob/main/AGENTS.md)

## Completion rule

Do not equate issue closure, generated output, passing tests, or green goldens with product completion.

Before reporting a change complete, verify the actual affected behavior, run the relevant validation, state what was not verified, and leave the repository's canonical documents/backlog consistent with reality.
