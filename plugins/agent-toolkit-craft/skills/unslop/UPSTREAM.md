# Upstream Provenance — unslop

- **Repository:** cursor/plugins
- **Path:** pstack/skills/unslop
- **Ref (pinned SHA):** 2f87c854fe3e2fcda44ca86b46ede35aad3c46b7
- **License:** MIT (pstack/LICENSE preserved)
- **Trust tier:** experimental
- **Distribution:** vendored
- **Fidelity:** SKILL.md body is byte-identical to upstream; only Toolkit frontmatter overlay differs.
- **Product note:** Ships in **agent-toolkit-complete** only (not core — upstream "Must always apply" semantics).
- **Update strategy:** `python3 scripts/provenance.py updates --apply` → draft PR (weekly GHA)

See `capabilities/upstream.lock` and generated `docs/UPSTREAM.md`.
