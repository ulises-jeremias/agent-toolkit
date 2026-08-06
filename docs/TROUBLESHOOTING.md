# Troubleshooting — Doctor & CLI error recipes

Actionable fixes for the top failure modes reported by `agent-toolkit doctor` and `install`.

## 1. Missing toolkit data

**Symptom:** `doctor` reports `data missing` or `skills: 0`.

**Cause:** installed from source tarball without bundled data.

**Fix:**

```bash
uv tool install --force agent-toolkit-cli   # wheel with data
# or, from source checkout:
scripts/prepare-package-data.sh
agent-toolkit install
```

See `docs/INSTALLATION.md` and `docs/GETTING_STARTED.md`.

## 2. Wrong tool path

**Symptom:** `install --target <tool>` copies to unexpected directory.

**Fix:**

```bash
agent-toolkit doctor          # shows detected paths per tool
agent-toolkit install --target muse-code --dry-run   # preview
```

Per-tool paths are tabled in `docs/INSTALLATION.md`.

## 3. Partial install (skills without agents/loops)

**Symptom:** `doctor` shows `skills: 52, agents: 0` or similar.

**Fix:**

```bash
agent-toolkit build
agent-toolkit install --force
```

See `docs/CONCEPTS.md` layer hierarchy.

## 4. Stale catalog

**Symptom:** CI `generate-catalogs` check fails.

**Fix:**

```bash
python3 scripts/generate-catalogs.py
git add catalogs/
```

See `CONTRIBUTING.md` Validation Commands.

## 5. Surface drift

**Symptom:** `python3 scripts/gen-surfaces.py --check` fails.

**Fix:**

```bash
python3 scripts/gen-surfaces.py
# or
agent-toolkit build --check
```

See `docs/CONCEPTS.md` and `docs/ARCHITECTURE.md` ADR-003/004.

---

If none of these match, run `agent-toolkit doctor --verbose` and open an issue with the output (redact paths if needed).
