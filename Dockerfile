FROM python:3.11-slim

LABEL org.opencontainers.image.title="agent-toolkit"
LABEL org.opencontainers.image.description="Composable AI agent toolkit — loops, skills, profiles for AI coding tools"
LABEL org.opencontainers.image.source="https://github.com/ulises-jeremias/agent-toolkit"
LABEL org.opencontainers.image.licenses="MIT"

# Install gh CLI for loop execution + uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /agent-toolkit
COPY . .

RUN uv sync --frozen --all-extras || uv sync --all-extras

# Default: show help
ENTRYPOINT ["uv", "run", "agent-toolkit"]
CMD ["help"]
