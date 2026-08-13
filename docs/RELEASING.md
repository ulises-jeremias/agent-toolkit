# Releasing agent-toolkit

Runbook for cutting a versioned release.

## Bump → validate → tag → watch → verify

```bash
# 1. Bump all version sources atomically
python3 scripts/bump-version.py 1.3.0
git diff --stat  # VERSION, packages/agent-toolkit-cli/src/agent_toolkit/__init__.py, package.json, packages/npm/*/package.json, .claude-plugin/marketplace.json, .cursor-plugin/marketplace.json

# 2. Validate (CI parity)
uv sync --all-extras
AGENT_TOOLKIT_ROOT="$PWD" uv run pytest tests/ -v
python3 scripts/validate-skills.py
python3 scripts/validate-agents.py
python3 scripts/generate-catalogs.py
python3 scripts/gen-surfaces.py --check

# 3. Commit + tag
git add -A && git commit -m "chore(release): bump to v1.3.0"
git tag -a v1.3.0 -m "v1.3.0"
git push origin main --follow-tags

# 4. Watch Release + downstream
gh run list --repo ulises-jeremias/agent-toolkit --limit 5  # Release v1.3.0 should be completed success
gh release view v1.3.0 --repo ulises-jeremias/agent-toolkit
# Homebrew/AUR notifies run after Release create-release; check their repos
gh run list --repo ulises-jeremias/homebrew-tap --limit 3
gh run list --repo ulises-jeremias/aur-packages --limit 3

# 5. Verify PyPI / npm / AUR / formula
curl -sS https://pypi.org/pypi/agent-toolkit-cli/json | python3 -c "import json,urllib.request; print(json.load(urllib.request.urlopen('https://pypi.org/pypi/agent-toolkit-cli/json'))['info']['version'])"
npm view agent-toolkit-cli version
curl -sS 'https://aur.archlinux.org/rpc/v5/info?arg[]=agent-toolkit' | python3 -m json.tool  # resultcount 0 until published
# Homebrew formula version matches tag
```

## Bump script

`scripts/bump-version.py` updates atomically:

* `VERSION`
* `packages/agent-toolkit-cli/src/agent_toolkit/__init__.py` (`__version__`)
* `package.json` (`version`) — skills marketplace metadata, not the CLI
* `packages/npm/*/package.json` (`version` + `optionalDependencies` pins)
* `.claude-plugin/marketplace.json` (`metadata.version` + `plugins[].version`)
* `.cursor-plugin/marketplace.json` (same)
* Plugin manifests `plugins/*/plugin.json` if present

Usage:

```bash
python3 scripts/bump-version.py --check 1.3.0  # dry-run, exits 1 if would change
python3 scripts/bump-version.py 1.3.0         # writes files
```

## Rollback / republish

* **PyPI:** Trusted Publishing only via `release.yml` on tag `v*`. Manual republish: workflow `Publish (manual)` (`.github/workflows/publish.yml`) with `TestPyPI`/`PyPI` env.
* **npm:** OIDC trusted publishing via `publish-npm.yml` on tag `v*` (npm CLI ≥ 11.5.1, `id-token: write`, no `NPM_TOKEN`). First publish of a new package name is local (`npm login` then `npm publish`). Then pin GitHub:
  ```bash
  npm trust github agent-toolkit-cli --file publish-npm.yml --repository ulises-jeremias/agent-toolkit --allow-publish -y
  ```
* **GitHub Release:** delete tag locally + remote + release, fix, re-tag. Prefer `gh release delete v1.3.0 --yes && git tag -d v1.3.0 && git push origin :v1.3.0`.
* **Homebrew/AUR:** downstream repos are notified via `repository_dispatch` from `release.yml` `create-release`. If they missed, replay per `docs/AUR_PLAYBOOK.md`:
  ```bash
  gh api repos/ulises-jeremias/aur-packages/dispatches -f event_type=new-release -f 'client_payload[package_name]=agent-toolkit' -f 'client_payload[version]=v1.3.0'
  ```

## Asset naming

Stable GitHub Release assets are **native V binaries** (not PyInstaller). Names follow [ADR-018](adrs/ADR-018-release-artifacts.md):

* `agent-toolkit-linux-x86_64` / `agent-toolkit-linux-arm64` (glibc, [ADR-019](adrs/ADR-019-linux-libc.md))
* `agent-toolkit-macos-arm64` / `agent-toolkit-macos-x86_64`
* `agent-toolkit-windows-x86_64.exe`
* Versioned archives `agent-toolkit-<semver>-<os>-<arch>.tar.gz` (Windows `.zip`) containing `agent-toolkit` + `LICENSE`
* `SHA256SUMS` and `manifest.json` ([ADR-022](adrs/ADR-022-release-manifest.md))

**Checksums are MUST.** Verify:

```bash
curl -fsSL -O "https://github.com/ulises-jeremias/agent-toolkit/releases/download/v1.10.0/SHA256SUMS"
curl -fsSL -O "https://github.com/ulises-jeremias/agent-toolkit/releases/download/v1.10.0/agent-toolkit-linux-x86_64"
sha256sum -c SHA256SUMS --ignore-missing
```

**SBOM (SHOULD):** `sbom.cyclonedx.json` lists ingredients; it is not a vulnerability scan. **Artifact attestations (FUTURE / SHOULD when enabled):** they record which workflow produced an asset; they do not prove the software is secure. **Code signing / notarization:** [#543](https://github.com/ulises-jeremias/agent-toolkit/issues/543).

**Experimental V** CI artifacts use `agent-toolkit-v-experimental-<os>-<arch>` and must not overwrite stable names. Optional musl extra uses `agent-toolkit-linux-x86_64-musl`.

Packaging **adapter contracts** (this repo, no Formula/PKGBUILD copies): [`distribution/README.md`](../distribution/README.md) ([#534](https://github.com/ulises-jeremias/agent-toolkit/issues/534)).

## Downstream publish verification (notify success ≠ publish success)

`notify-homebrew` / `notify-aur` only confirm that a `repository_dispatch` reached the downstream repo (see `.github/workflows/notify-*.yml`). A green `Notify` run does **not** guarantee the Homebrew formula or AUR PKGBUILD was actually published.

After tagging, verify downstream **workflow conclusion**, not just dispatch:

```bash
# Homebrew tap: last 3 runs should be success; a failure means formula did not update
gh run list --repo ulises-jeremias/homebrew-tap --limit 3
gh run view <run-id> --repo ulises-jeremias/homebrew-tap --log | grep -i "error\|fail" || echo "no errors"

# AUR packages: same check, but distinguish maintenance vs real failure
gh run list --repo ulises-jeremias/aur-packages --limit 3
# AUR maintenance windows return exit 0 with message "AUR is in maintenance"; check logs:
gh run view <run-id> --repo ulises-jeremias/aur-packages --log | grep -i "maintenance" && echo "maintenance — retry later" || echo "real failure"
```

Failure visibility on the releasing repo:

* The `Release` workflow itself does not fail on downstream errors — check the two downstream repos' **Actions → workflow runs** as above.
* If downstream is red, re-dispatch per playbook (see below) and re-check; do not close the release as done until both downstream runs are green or explicitly deferred for maintenance.
* For AUR, a maintenance failure is expected — document it in the release comment and retry when AUR leaves maintenance; do not auto-open issues on every window.


## Downstream install source (PyPI wheel preferred)

Homebrew (`homebrew-tap`) and AUR (`aur-packages`) should install from the PyPI wheel/sdist (which bundles `skills/` data via `prepare-package-data.sh`) rather than building from the GitHub source tarball without that step. This avoids silent incomplete installs (see #257, #258).

- **Homebrew:** Formula `agent-toolkit.rb` should `url` the PyPI wheel (`https://files.pythonhosted.org/.../agent-toolkit_cli-*.whl`) or run `scripts/prepare-package-data.sh` before `pip install` from tarball. Verify via `brew install --build-from-source` then `agent-toolkit doctor`.
- **AUR:** `PKGBUILD` should `source` the PyPI sdist/wheel and run `prepare-package-data.sh` if building from source. Verify via `makepkg -si` then `agent-toolkit doctor`.

See `docs/AUR_PLAYBOOK.md` for re-dispatch; downstream repos are the source of truth for their formulas.

## AUR retry playbook

See `docs/AUR_PLAYBOOK.md` for re-dispatch when AUR leaves maintenance.

Re-dispatch example:

```bash
gh api repos/ulises-jeremias/aur-packages/dispatches -f event_type=new-release -f 'client_payload[package_name]=agent-toolkit' -f 'client_payload[version]=v1.3.0'
gh api repos/ulises-jeremias/homebrew-tap/dispatches -f event_type=new-release -f 'client_payload[formula_name]=agent-toolkit' -f 'client_payload[version]=1.3.0'
```
