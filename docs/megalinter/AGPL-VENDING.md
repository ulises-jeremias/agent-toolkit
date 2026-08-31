# MegaLinter AGPL Vendoring Policy

**Upstream:** `oxsecurity/megalinter` — GNU Affero General Public License v3.0 (AGPL-3.0).

## Decision (2026-08-14)

Agent Toolkit **vendors** the four MegaLinter coding-agent skills (`quality/megalinter`,
`quality/megalinter-setup`, `quality/megalinter-check`, `quality/megalinter-fix`) as
literal copies of the upstream skill trees at an immutable pin, with Toolkit provenance
frontmatter overlaid on each `SKILL.md`.

This supersedes the earlier `distribution.mode: external` adapter approach. Literal-copy
fidelity is required so `scripts/provenance.py` can automate update detection via
`resolved.body_checksum` (body after `---` must match upstream byte-for-byte).

## Aggregation, not a combined derivative

- Each skill directory ships the upstream `LICENSE` (AGPL-3.0) alongside vendored files.
- Toolkit-authored code/docs remain MIT; AGPL applies to the MegaLinter skill files themselves.
- Docker images and `mega-linter-runner` are still **runtime** dependencies fetched by the
  consumer — not redistributed as Toolkit release artifacts beyond the skill markdown/tree.

## Obligations when redistributing these files

1. Preserve copyright notices and the AGPL license text (`LICENSE` in each skill dir).
2. Do not remove provenance frontmatter that documents the upstream pin.
3. Updates must go through `provenance.py updates --apply` + human review PR (never silent).

See also historical notes in `docs/megalinter/megalinter-license.md` (pre-vendoring analysis).
