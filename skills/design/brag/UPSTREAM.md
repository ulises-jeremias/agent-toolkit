# Upstream Provenance — brag

- **Repository:** latent-spaces/brag
- **Path:** skills/brag
- **Ref (pinned SHA):** c893c5ed52aed84e3e2ee56787de869fccdae6b0
- **License:** MIT (repo-root LICENSE preserved). Bundled ende.app music and Kenney SFX under `assets/` are **not** vendored: music redistribution terms are unverified (upstream `assets/music/README.md`) and the binary pack is ~17MB.
- **Trust tier:** experimental
- **Reviewed provenance:** sha256:73e297c0d8ebeb43d95e669b65efde9560e1d80654026e1307841fbcbd47d7f1
- **Distribution:** vendored (instruction + `references/` + `scripts/` + `slim.md`)
- **Fidelity:** SKILL.md body is byte-identical to upstream; only Toolkit frontmatter overlay differs.
- **Product note:** Ships in **agent-toolkit-complete** only (not core).
- **Update strategy:** `python3 scripts/provenance.py updates --apply` → draft PR (weekly GHA)

See `capabilities/upstream.lock` and generated `docs/UPSTREAM.md`.
