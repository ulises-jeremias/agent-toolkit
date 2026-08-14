---
name: web-design-guidelines
description: Review UI code for Web Interface Guidelines compliance — accessibility, focus, forms, animation, typography, performance, and anti-patterns. Use when asked to "review my UI", "check accessibility", "audit design", or "review UX".
origin:
  type: upstream
sources:
  - id: wrapper
    role: wrapper
    repository: vercel-labs/agent-skills
    path: skills/web-design-guidelines
    ref: 7c180d9044c9ae2b442b567aad4e42a28dd5ed62
    license: NOASSERTION
  - id: rules
    role: rules
    repository: vercel-labs/web-interface-guidelines
    path: command.md
    ref: 4e799d45c17aec1498c269287a83b9dba22b966b
    license: MIT
trust:
  tier: reviewed
  reviewed_at: '2026-08-11'
  reviewed_by: ulises-jeremias
  reviewed_provenance: sha256:7c23f915c756d4322d1b8ca17ed1d57a98cc6accd11a11ae765e288a181ff870
maintenance:
  status: active
  last_activity: '2026-07-24'
distribution:
  mode: vendored
  redistribution_allowed: false
security:
  scripts: false
  shell: false
  network: false
  mcp: []
  hooks: []
  dangerous_permissions: []
  cve_policy: not-applicable
---

# Web Design Guidelines

Review UI code for compliance with Vercel Web Interface Guidelines (frozen vendored snapshot).

This skill is a **frozen, dual-source vendored** adaptation of:

- **Wrapper:** `vercel-labs/agent-skills` `skills/web-design-guidelines` at `7c180d9` (NOASSERTION — no LICENSE file, README declares MIT but not machine-verifiable)
- **Rules:** `vercel-labs/web-interface-guidelines` `command.md` at `4e799d4` (MIT)

The original upstream `SKILL.md` fetched the guidelines from the `web-interface-guidelines` repository `main` branch at runtime via `WebFetch` — a mutable fetch that violated supply-chain reproducibility. This Toolkit skill **freezes** that content into `references/web-interface-guidelines.md` and removes the network fetch.

## How it works (frozen)

1. Read the **frozen guidelines** from `references/web-interface-guidelines.md` (do not fetch from the network)
2. Read the specified files (or ask user for files/pattern)
3. Check against all rules in the frozen guidelines
4. Output findings in the terse `file:line` format specified in the guidelines

## Usage

When a user provides a file or pattern argument:

1. Read `references/web-interface-guidelines.md` from this skill directory (not the network)
2. Read the specified source files
3. Apply all rules from the frozen guidelines
4. Output findings using the format in the guidelines (grouped by file, `file:line` entries, `✓ pass` if clean)

If no files specified, ask which files to review. Never fetch from the network — use the vendored `references/` copy.

## Source mapping

- `references/web-interface-guidelines.md` — frozen `command.md` at `4e799d4` (MIT), `sha256:eea73cb6dd46fee9faec9973e8e7fe198b5f07ec326f14d276a56e50287e1cab`
- This `SKILL.md` wrapper body adapted from `vercel-labs/agent-skills` `7c180d9` (NOASSERTION), original `SKILL.md` `sha256:f4647ca866a3accf763777f83e7682954f0187cd6bea7eea0399796652414e8f`; frozen wrapper checksum below is vendored artifact `sha256:...` (Toolkit frontmatter + adapted body)

## Provenance

See `capabilities/upstream.lock` `design/web-design-guidelines` (dual-source, `provenance_digest`), `docs/UPSTREAM.md`, and `docs/adr/0001...` for declaration→lock→vendored→surfaces.

Update strategy: `pull-request` per `capabilities/upstream.lock` `resolved_at`; never `main` fetch.
