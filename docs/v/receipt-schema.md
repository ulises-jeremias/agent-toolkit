# Install receipt compatibility schema

**Issue:** [#511](https://github.com/ulises-jeremias/agent-toolkit/issues/511)

Formal JSON Schema for installer receipts:

- File: [`schemas/install-receipt.schema.json`](../../schemas/install-receipt.schema.json)
- Contract: `schemaVersion` **1**, camelCase keys, `secrets: []`, ownership `created|merged`, no `..` in artifact paths
- Verified by: Python `tests/test_install_receipt_schema.py` + V `parse_install_receipt` / `save_install_receipt` (#512/#513)

See [TRUST.md](../TRUST.md) (Installation receipts) and ADR-014 (typed V validators + published schema for cross-language parity).
