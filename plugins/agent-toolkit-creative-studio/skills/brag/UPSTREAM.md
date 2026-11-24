# Upstream Provenance — brag

- **Repository:** latent-spaces/brag
- **Path:** skills/brag
- **Ref (pinned SHA):** 7c98a0830fd2810c93b1f9da7d9edef98ed6ef8a
- **License:** MIT (repo-root LICENSE preserved). Bundled ende.app music and Kenney SFX under `assets/` are **not** vendored: music redistribution terms are unverified (upstream `assets/music/README.md`) and the binary pack is ~17MB.
- **Trust tier:** experimental
- **Distribution:** vendored (instruction + `references/` + `scripts/` + `slim.md`)
- **Fidelity:** Source SKILL.md body is byte-identical to the pinned upstream body; the compiler may append a distribution note when unredistributed binary assets are omitted.
- **Product note:** Ships in **agent-toolkit-complete** only (not core).
- **Update strategy:** `python3 scripts/provenance.py updates --apply` → draft PR (weekly GHA)

See `capabilities/upstream.lock` and generated `docs/UPSTREAM.md`.
