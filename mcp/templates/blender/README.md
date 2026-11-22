# Blender MCP Template

Preferred server: the official
[Blender Lab MCP](https://projects.blender.org/lab/blender_mcp) add-on
(GPL-3.0), evaluated at revision `dbbf836ad4b1025f14a2b3b504c43903f39e0b04`.
Community alternative: `ahujasid/mcp-for-blender` (MIT). See
`docs/creative-studio/UPSTREAM_EVALUATION.md`.

> **High risk:** Blender MCP servers can execute model-generated Python
> inside Blender — arbitrary local code execution. Install only when you
> accept that risk, keep the connection on loopback, work on a copy of the
> `.blend`, and restrict output paths to your creative project directory.

## Deterministic alternative (no MCP)

For scripted, reviewable jobs prefer headless Blender:

```bash
blender -b --python assets/build_title.py   # saves edit/title.blend + render
blender -b edit/title.blend -o preview/title_ -a
```

## Usage

1. Install the add-on inside Blender per the upstream readme at the pinned
   revision, and start its MCP bridge from within Blender.
2. Copy `config.template.json` into your MCP client config, adjusting the
   command to the server entry point your installation provides.
3. Save a `.blend` copy before the session; Blender auto-saves are not a
   substitute for a versioned project file.

## Uninstall

Disable/remove the add-on in Blender preferences and delete the client
config entry. `.blend` files are untouched.
