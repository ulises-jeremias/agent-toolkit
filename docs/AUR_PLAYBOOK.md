# AUR Playbook

Manual re-dispatch for `aur-packages` when the AUR leaves maintenance or a publish is missed.

## When to use

* README advertises `yay -S agent-toolkit` but `https://aur.archlinux.org/rpc/v5/info?arg[]=agent-toolkit` returns `resultcount: 0`
* A new tag `vX.Y.Z` was pushed and downstream `aur-packages` did not publish (retry window exhausted)
* Maintainer intentionally wants to replay a release to AUR without re-tagging

## Prerequisites

* `gh` CLI authenticated (`gh auth status`)
* Maintainer access to `ulises-jeremias/aur-packages` (repo admin or dispatch permission)
* Version matches a published tag and PyPI `agent-toolkit-cli` version

## Re-dispatch (one command)

```bash
VERSION=v1.3.0  # or latest tag, without leading spaces
gh api repos/ulises-jeremias/aur-packages/dispatches \
  -f event_type=new-release \
  -f 'client_payload[package_name]=agent-toolkit' \
  -f "client_payload[version]=$VERSION"
```

Expected: `gh api` returns `204 No Content`. Check workflow run:

```bash
gh run list --repo ulises-jeremias/aur-packages --limit 5
```

## Verify publish

```bash
# AUR RPC should show pkgver matching latest release
curl -sS 'https://aur.archlinux.org/rpc/v5/info?arg[]=agent-toolkit' | python3 -m json.tool

# Update README AUR section to full install instructions only after RPC shows pkgver
```

## Interim consumer path (always works)

Until AUR RPC shows package:

```bash
uv tool install agent-toolkit-cli
agent-toolkit install
# or one-shot
uvx --from agent-toolkit-cli agent-toolkit install
```

Do not advertise `yay -S agent-toolkit` as working until verified per above.
