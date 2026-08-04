# agent-toolkit — Current State Audit

**Date:** 2026-08-04  
**Auditor:** automated programmatic audit  
**Branch:** main

---

## Executive Summary

agent-toolkit has strong operational infrastructure but 4 confirmed defects
requiring immediate action before next release. All CI validation passes;
the issues are in configuration files committed to the public repo.

---

## Inventory (programmatic counts)

| Asset | Count | Location |
|-------|-------|----------|
| Skills (SKILL.md) | 52 | `skills/{core,delivery,design,forge,integrations,data,tooling,ops,loops}` |
| Agents (AGENT.md) | 16 | `agents/` |
| Loop templates | 10 | `loops/` |
| Python CLI modules | 12 | `src/agent_toolkit/cli/` |
| Template files | 15 | `src/agent_toolkit/templates/` |
| Profile files | 67 | `profiles/{claude-code,cursor,opencode,copilot,windsurf,pi}` |
| Plugin bundles | 3 | `plugins/{core,agents,forge}` |
| Plugin bundle files | 52 | copied agents + skills |
| Test files | 3 | `tests/` |
| Schema files | 3 | `schemas/` |
| MCP templates | 6 | `mcp/templates/{github,slack,notion,linear,figma,clickup}` |
| Catalog files | 3 | `catalogs/{skill,agent,loop}-catalog.yaml` |

---

## Confirmed Defects

### DEFECT-001: Dangerous Permission Bypass
**Severity:** HIGH  
**File:** `profiles/claude-code/settings.json`  
**Evidence:**
```json
"skipDangerousModePermissionPrompt": true
```
**Impact:** Distributed to all users installing the Claude Code profile. Bypasses
all permission prompts for file write, delete, shell execution. Never safe to
ship as a default in a public distribution.  
**Fix:** Remove this field entirely.

### DEFECT-002: Private/Internal Provider URLs in OpenCode Config
**Severity:** HIGH  
**File:** `profiles/opencode/opencode.json`  
**Evidence:** Contains `http://colibri.skypiea.local:8000/v1` (internal LAN URL)
and other machine-specific provider configuration.  
**Impact:** Non-functional on any machine other than the author's. Leaks internal
infrastructure names. Violates the "no private hostnames" requirement.  
**Fix:** Replace with a portable template using only standard public providers or
`${ENV_VAR}` placeholders. Move personal config to local override.

### DEFECT-003: Cursor README Contains Wrong Content
**Severity:** MEDIUM  
**File:** `profiles/cursor/README.md`  
**Evidence:** File content is a shell heredoc script for creating `profiles/copilot/README.md`
— clearly copy-paste residue from a different profile's creation.  
**Fix:** Replace with accurate Cursor profile installation instructions.

### DEFECT-004: Stale Schema References to Deprecated Project
**Severity:** LOW  
**Files:** `schemas/skill-md-frontmatter.schema.json`  
**Evidence:**
```json
"$id": "https://raw.githubusercontent.com/ulises-jeremias/agentic-workstation/main/lib/schemas/..."
"title": "agentic-workstation SKILL.md Frontmatter"
```
**Fix:** Update `$id` and `title` to reference `ulises-jeremias/agent-toolkit`.

---

## Architecture Gaps

1. **Plugin composition is hard-coded** — `gen-surfaces.py` SURFACES dict and `plugin.py`
   list must be manually updated to add products. Not data-driven.
2. **No canonical IR** — skills/agents go directly from SKILL.md/AGENT.md to copied files
   with no intermediate validation or target-aware compilation step.
3. **Install is copy-only** — no backup, no receipt, no rollback, no merge.
4. **MCP is template-only** — `mcp.py` saves metadata but does not render, install, or
   health-check native MCP server configurations.
5. **Minimal tests** — 3 smoke tests. No integration, schema, or compiler tests.
6. **No provenance** — generated plugin bundles have no content hashes or source tracking.
7. **profile/ ≠ plugin** — profiles are profile directories copied to home dirs;
   Claude Code and Cursor plugin bundles exist separately but the two systems overlap.

---

## CI Coverage Assessment

**Passing:**
- SKILL.md/AGENT.md frontmatter validation
- Marketplace and plugin.json structure
- Plugin bundle drift (gen-surfaces --check)
- loop.yaml schema validation
- Secret scan (Gitleaks)
- Package build + smoke test

**Missing:**
- Native load tests (does Claude Code actually load agent-toolkit-core?)
- Clean-home install tests
- Rollback tests
- MCP protocol-level health checks
- Provenance/checksum verification
- Security tests (path traversal, injection)
