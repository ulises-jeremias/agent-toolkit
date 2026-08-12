# V provenance emission

**Issue:** [#508](https://github.com/ulises-jeremias/agent-toolkit/issues/508)

Emits `.provenance.json` sidecars compatible with Python `compiler/provenance.py`: `generatorVersion`, `product`, `target`, and artifact `path` / `sourceFile` / `sourceDigest` / `generatedDigest` (SHA256 truncated to 12 hex chars). `verify_generated_digests` reports drift without stripping provenance.
