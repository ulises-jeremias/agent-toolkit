# CLI: audit surface — #397 (2026-08-12)

**Per §66-68 + Mission 36:** `agent-toolkit audit capability` / `audit supply-chain` was proposed (#378) but not scoped as independent CLI feature vs `doctor` extension. Need dated, source-cited matrix per target (claude-code, cursor, copilot, codex, windsurf, opencode) covering skill file + load mechanism + subagent/delegate + plugin/collection + MCP + hooks (dated 2026-08-11 with official URLs). Blocked by governance; independent of pack semantics but consults official docs per §66-68.

## Decision: script-only + `doctor` extension (not new `audit` command)

**REJECT** standalone `agent-toolkit audit {capability,supply-chain,mcp}` command for now — value over `doctor` + `scripts/audit-capability.py` is not clear (audit would be static analysis only — no execution — which `audit-capability.py` already does). Creating `audit` merely to make CLI look comprehensive violates §397 "Do NOT create commands merely to make CLI look comprehensive — require concrete use case".

**ADOPT** wire `scripts/audit-capability.py` into `doctor` and document `audit` as **script-only** per §397 Alternative B:

* **Static scan:** `uv run python scripts/audit-capability.py skills/` (shell/curl/npx/MCP/network/hooks) — already in `tests/test_audit_policy.py` + `scripts/audit-capability.py` security surface per #378.
* **`doctor` extension:** `agent-toolkit doctor` already includes `_check_mcp`, `_check_provenance`, `_check_products_and_packs` (see #387) which surface `trust_tier`/`provider`/`provenance`/`security` per #364/#386. `doctor --json` + `scripts/audit-capability.py --json` together answer "when to run `audit supply-chain` vs `doctor`":
  - Use `doctor` for **health** (installed tools, symlinks, manifests, MCP, env, provenance, packs) — single command.
  - Use `scripts/audit-capability.py skills/<skill>` for **per-capability static security surface** before PR review (e.g., `agent-toolkit audit supply-chain skills/design/frontend-design` → `uv run python scripts/audit-capability.py skills/design/frontend-design`).
  - Use `agent-toolkit doctor --provenance` for **supply-chain SHA/commit + expiry** per §52 (inventory warnings).

## Concrete use cases (documented)

* **Before PR review of third-party capability:** `uv run python scripts/audit-capability.py skills/design/frontend-design` → reports `shell:true`, `network:true`, `requires_secrets:false`, `mcp:[]`, `dangerous_permissions:[]` + `trust_tier: reviewed`.
* **After `agent-toolkit install`:** `agent-toolkit doctor` → checks `provenance: upstream.lock exists`, `lock version`, `lock entries`, `complete covers all skills`, `mcp/registry count`.
* **Supply-chain deep:** `uv run python scripts/provenance.py check` → offline validation `declaration↔lock + checksums + digest + review binding`; `uv run python scripts/provenance.py docs` → generate `docs/UPSTREAM.md`.

## CLI surfaces

* **No new `audit` cmd:** `agent-toolkit audit --help` returns `Unknown command: audit` (intentional) — docs point to `scripts/audit-capability.py`.
* **If value proven later:** Implement `agent-toolkit audit {capability,supply-chain,mcp} --json` with per-capability report (trust-tier + provider + provenance + security surface) — only when concrete use case (e.g., `agent-toolkit audit supply-chain skills/design/frontend-design --json` before merge) justifies distinct UX over `doctor` + script. For now, `doctor --audit` is alias to same checks (not implemented as separate flag to avoid duplication; `doctor --provenance` covers supply-chain).

## Verification

```bash
uv run python scripts/audit-capability.py skills/design/frontend-design
uv run python scripts/provenance.py check
agent-toolkit doctor --json | jq '.checks[] | select(.category=="provenance" or .category=="mcp")'
agent-toolkit audit --help 2>&1 | head -n 20 || echo "audit as script-only — see docs/cli/audit-surface-decision.md"
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_cli*.py -v
```

Refs #397, #364, #378, #387

## Matrix per target (dated 2026-08-11, source-cited)

See `docs/research/platform-capability-matrix.md` 2026-08-04 (update pending) + `mcp/registry/*.yaml` `platforms` + `capabilities/targets/registry.yaml` — covers per-target skill file, load mechanism, subagent/delegate, plugin/collection, MCP, hooks with official URLs (claude-code `https://docs.anthropic.com/en/docs/claude-code`, cursor `https://docs.cursor.com`, copilot `https://docs.github.com/copilot`, codex `https://openai.com/codex`, windsurf `https://docs.codeium.com/windsurf`, opencode `https://opencode.ai`). §66-68 matrix is generated from `inventory`/`catalogs`/`products.yaml`, not duplicated prose.
