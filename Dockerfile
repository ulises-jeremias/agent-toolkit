# syntax=docker/dockerfile:1.7
# V-first image (ADR-018 / #537). Not a Python/uv workspace.
# GitHub Release linux ELF needs GLIBC_2.38 — bookworm (2.36) cannot run it.
FROM debian:trixie-slim

LABEL org.opencontainers.image.title="agent-toolkit"
LABEL org.opencontainers.image.description="Composable AI agent toolkit — native V CLI from GitHub Releases"
LABEL org.opencontainers.image.source="https://github.com/ulises-jeremias/agent-toolkit"
LABEL org.opencontainers.image.licenses="MIT"

# TARGETARCH must have no default. BuildKit injects amd64|arm64 per --platform.
# A default of amd64 installs the x86_64 ELF into the linux/arm64 image; exec
# then fails with "not found" (missing amd64 dynamic linker).
ARG TARGETARCH
ARG VERSION=1.51.1

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=secret,id=github_token,target=/run/secrets/github_token,required=false \
    --mount=type=bind,target=/mnt/context,readonly \
    set -eu; \
    case "${TARGETARCH}" in \
      amd64) asset=agent-toolkit-linux-x86_64 ;; \
      arm64) asset=agent-toolkit-linux-arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    if [ -s "/mnt/context/release-assets/${asset}" ] && [ -s /mnt/context/release-assets/SHA256SUMS ]; then \
      (cd /mnt/context/release-assets && sha256sum -c SHA256SUMS --ignore-missing); \
      cp "/mnt/context/release-assets/${asset}" "/tmp/${asset}"; \
      cp /mnt/context/release-assets/SHA256SUMS /tmp/SHA256SUMS; \
    elif [ -s /run/secrets/github_token ]; then \
      export GH_TOKEN="$(cat /run/secrets/github_token)"; \
      releases='repos/ulises-jeremias/agent-toolkit/releases'; \
      release_id=''; \
      for page in $(seq 1 100); do \
        release_id=$(gh api "${releases}?per_page=100&page=${page}" --jq ".[] | select(.tag_name == \"v${VERSION}\") | .id" | head -n 1); \
        [ -z "${release_id}" ] || break; \
      done; \
      test -n "${release_id}"; \
      release="${releases}/${release_id}"; \
      asset_id=$(gh api "${release}" --jq ".assets[] | select(.name == \"${asset}\") | .id" | head -n 1); \
      sums_id=$(gh api "${release}" --jq '.assets[] | select(.name == "SHA256SUMS") | .id' | head -n 1); \
      test -n "${asset_id}" && test -n "${sums_id}"; \
      gh api -H 'Accept: application/octet-stream' "repos/ulises-jeremias/agent-toolkit/releases/assets/${asset_id}" > "/tmp/${asset}"; \
      gh api -H 'Accept: application/octet-stream' "repos/ulises-jeremias/agent-toolkit/releases/assets/${sums_id}" > /tmp/SHA256SUMS; \
    else \
      base="https://github.com/ulises-jeremias/agent-toolkit/releases/download/v${VERSION}"; \
      curl -fsSL -o "/tmp/${asset}" "${base}/${asset}"; \
      curl -fsSL -o /tmp/SHA256SUMS "${base}/SHA256SUMS"; \
    fi; \
    (cd /tmp && sha256sum -c SHA256SUMS --ignore-missing); \
    install -m 0755 "/tmp/${asset}" /usr/local/bin/agent-toolkit; \
    rm -f "/tmp/${asset}" /tmp/SHA256SUMS; \
    test -x /usr/local/bin/agent-toolkit
    # Do not exec the ELF here: QEMU user-mode for the non-native
    # --platform often reports "not found" (missing foreign ld-linux).
    # Smoke `agent-toolkit version` in docker.yml after a native load.

ENTRYPOINT ["/usr/local/bin/agent-toolkit"]
CMD ["--help"]
