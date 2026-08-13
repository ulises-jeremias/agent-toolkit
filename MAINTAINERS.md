# Maintainers

## Current maintainers

* **@ulises-jeremias** ([ulises-jeremias](https://github.com/ulises-jeremias)) — lead maintainer, review and release owner

## Review expectations

* PRs labeled `wave:*` are reviewed in wave order (Wave 0 → 5 per #240/#263)
* `good first issue` / `help wanted` are community-friendly; `maintainer-only` requires maintainer approval
* `CODEOWNERS` defines review routing for `skills/`, `loops/`, `distributions/`, and release paths
* See [CONTRIBUTING.md](CONTRIBUTING.md) for local validation (`uv sync --project packages/pypi/agent-toolkit-cli --all-extras`, `AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v`, `python3 scripts/validate-skills.py` etc.) and PR template checklist

## Governance

* Until multi-maintainer: single-maintainer model; no GOVERNANCE.md voting yet (see #252 out-of-scope)
* Code of Conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
* Support: [SUPPORT.md](SUPPORT.md)
