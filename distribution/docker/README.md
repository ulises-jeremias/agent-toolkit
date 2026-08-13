# Docker adapter

**Issue:** [#537](https://github.com/ulises-jeremias/agent-toolkit/issues/537)

Workflow: `.github/workflows/docker.yml` (this repo).

Contract: image is an adapter around the **canonical GitHub Release binary** (or, until promotion, the current Python image). Base image and extra CLI tools (`git`, `gh`) are decided in #537. Do not bake experimental V names into the stable tag without the #531 promotion gate.
