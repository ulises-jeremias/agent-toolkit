# Kdenlive MCP Template

Community server: [`mhbxyz/kdenlive-mcp`](https://github.com/mhbxyz/kdenlive-mcp),
PyPI package **`mcp-kdenlive`** (the PyPI name `kdenlive-mcp` is an unrelated
project). Evaluated revision `9abcf9474a434f2e00a9c458f0ff70c92fbc16d8`;
see `docs/creative-studio/UPSTREAM_EVALUATION.md`.

## Prerequisites (Linux, distribution packages)

```bash
sudo pacman -S kdenlive mlt ffmpeg        # Arch / HorneroOS
sudo apt install kdenlive melt ffmpeg     # Ubuntu / Debian
pipx install mcp-kdenlive                 # or: uvx mcp-kdenlive
kdenlive-mcp diagnose                     # must print "ready"
```

## Required environment variables

- `KDENLIVE_MCP_ALLOWED_ROOTS` — colon-separated directories the server may
  touch. Point it at the creative project root only. The template uses the
  `${CREATIVE_PROJECT_ROOT}` placeholder; replace or export it per project.

## Usage

1. Copy `config.template.json` into your MCP client config, using the
   absolute path from `command -v kdenlive-mcp` if your client needs one.
2. Every edit writes a timestamped `.backup-*.kdenlive` next to the project;
   native `.kdenlive` files stay fully editable in Kdenlive itself.

## Uninstall

Remove the client config entry and `pipx uninstall mcp-kdenlive`. Projects
and backups are user files; delete them manually if wanted.
