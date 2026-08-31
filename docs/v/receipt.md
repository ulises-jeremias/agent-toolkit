# V install receipt parser

**Issue:** [#512](https://github.com/ulises-jeremias/agent-toolkit/issues/512)

Read-only parser for installer receipts (`~/.config/agent-toolkit/receipts/<target>-<product>.json`) compatible with Python `installer/receipt.py`:

- camelCase SCHEMA (`schemaVersion`, `installedAt`, `sourceDigest`, artifacts, empty `secrets`)
- ownership `created` | `merged`
- refuses non-empty secrets and `..` path segments (path-escape)
- preserves `configPatches` as raw JSON for round-trip by later install/uninstall slices

See also #511 (formal schema doc) and TRUST.md.
