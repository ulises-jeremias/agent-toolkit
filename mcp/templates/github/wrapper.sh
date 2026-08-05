#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_PERSONAL_ACCESS_TOKEN:?Set GITHUB_PERSONAL_ACCESS_TOKEN}"
exec docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN \
  ghcr.io/github/github-mcp-server
