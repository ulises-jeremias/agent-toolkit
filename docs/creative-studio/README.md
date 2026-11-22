# Creative Studio

Portable, local-first creative production for AI agents: real applications
(Kdenlive, Blender, GIMP, Krita, Inkscape, OBS, REAPER, FFmpeg), editable
native projects, evidence-backed verification. HorneroOS Studio is the
flagship environment; nothing here depends on it.

- Architecture: [ADR-046](../adrs/ADR-046-creative-studio-ecosystem.md)
- Upstream evaluation: [UPSTREAM_EVALUATION.md](UPSTREAM_EVALUATION.md)
- Compatibility: [COMPATIBILITY.md](COMPATIBILITY.md)
- Skills: `skills/creative/` · Agents: `agents/creative-director` (+5 specialists)
- MCP: `mcp/registry/{kdenlive,blender,gimp,krita,inkscape,obs,reaper,comfyui}.yaml`
- Product: `agent-toolkit-creative-studio` (opt-in) · Pack: `packs/creative-studio/`
- Acceptance: `tests/creative-studio/` + `skills/creative/creative-studio/scripts/creative_project.py doctor`

## Quick start

```bash
# 1. System tools (example: Arch/HorneroOS)
sudo pacman -S kdenlive mlt ffmpeg blender
# 2. Kdenlive MCP (PyPI name is mcp-kdenlive)
pipx install mcp-kdenlive && kdenlive-mcp diagnose
# 3. New project
python3 skills/creative/creative-studio/scripts/creative_project.py init ~/Videos/my-trailer
python3 skills/creative/creative-studio/scripts/creative_project.py add-source ~/Videos/my-trailer /path/clip.mp4
# 4. Point your MCP client at mcp/templates/kdenlive/ with
#    KDENLIVE_MCP_ALLOWED_ROOTS=~/Videos/my-trailer and ask for an edit.
```

## Contributor map

| Change | Where |
|--------|-------|
| New creative skill | `skills/creative/<name>/SKILL.md` + product + catalogs (checklist: `docs/SKILL_INTEGRATION_CHECKLIST.md`) |
| New MCP integration | `mcp/registry/<id>.yaml` + `mcp/templates/<id>/` + evaluation row in `UPSTREAM_EVALUATION.md` |
| New application dependency | Product `requires.executables` here; OS packages belong to HorneroOS/workstation, not this repo |
| HorneroOS Studio behaviour | `HorneroOS/hornero` (catalogue + `horneroctl studio`) — never duplicated here |
| Veasel marketplace entry | `veasel-labs/agent-toolkit` registry, by reference after review |

## Disable / uninstall

Remove the product with the normal Agent Toolkit uninstall flow, delete MCP
client entries, and `pipx uninstall mcp-kdenlive`. Creative projects,
native editor files and backups are user data and are never deleted by
uninstall.
