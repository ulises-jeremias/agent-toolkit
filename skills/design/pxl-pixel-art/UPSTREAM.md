# Upstream Provenance — pxl-pixel-art

- **Repository:** crsolver/claude-pxl
- **Path:** . (repository root — SKILL.md, engine and examples live at root)
- **Ref (pinned SHA):** 21fee41f7ecce00bc868d7567f24ffd0f3acc8fa
- **License:** MIT (`LICENSE` preserved verbatim)
- **Trust tier:** experimental — vendored bytes have NOT yet received the human
  review binding (`trust.reviewed_provenance`); a named human must audit the
  engine and only then set `tier: reviewed`. Do not fabricate that binding.
- **Distribution:** Agent Toolkit Complete only (opt-in design capability; not core/craft/forge)
- **Fidelity:** Upstream SKILL.md body, `reference.md`, `lighting.md`, `examples/`,
  `bin/`, `src/`, `types/`, `test/` and `package.json` are preserved verbatim.
  Toolkit overlay lives only in SKILL.md frontmatter.
- **Safety:** `.px.js` art files are **trusted executable code**, not passive
  data. Upstream `src/node/load.ts` evaluates them with host-realm access
  (verified escape: `pal.constructor('return process')()` reaches the host
  process) and no timeout. Only build/serve art files from reviewed, in-repo
  sources. Never run remote or untrusted art automatically. `pxl serve`
  binds 127.0.0.1 only but re-executes the art file on every save.
- **Runtime:** Node >= 22.18 (type-stripped TS checkout, zero runtime deps).
  `node <skill-dir>/bin/pxl.js build|ascii|list|serve ...`
- **Update strategy:** `python3 scripts/provenance.py updates --apply` → draft PR (weekly GHA)

See `capabilities/upstream.lock` and generated `docs/UPSTREAM.md`.
