# Showcase — Real Usage of agent-toolkit

> **Community gallery** — how teams use agent-toolkit skills, packs, and loops in the wild.
> Submit yours via **GitHub Discussions → Show and tell**.

## Internal examples (curated)

| Example | Pack | What it shows |
|---------|------|---------------|
| [oss-maintenance](examples/oss-maintenance/) | `packs/oss-maintenance` | Dependabot triage, semver releases, community health |
| [project-onboarding](examples/project-onboarding/) | `packs/engineering-workflow` | Onboarding checklist with loops |
| [delivery-discipline](packs/delivery-discipline/) | `packs/delivery-discipline` | Plan → implement → review → PR loop |

Each example is a runnable `pack.yaml` + `README.md` bundle. Copy it, `agent-toolkit build`, and `agent-toolkit install`.

## Packs

- [oss-maintenance](packs/oss-maintenance/) — OSS triage + release
- [engineering-workflow](packs/engineering-workflow/) — team delivery loop
- [delivery-discipline](packs/delivery-discipline/) — plan/implement/review

See [docs/CONCEPTS.md](docs/CONCEPTS.md) and [packs/README.md](packs/README.md) (packs are docs-only, ADR-006).

## Submit your showcase

1. Open **GitHub Discussions → Show and tell** (enable via #241 when active; otherwise open an issue with label `showcase`).
2. Title: `Showcase: <team or project>`
3. Include:
   - Which **skills/packs** you used and why
   - **Before / after** (what changed in your workflow)
   - **Repo or snippet** (no secrets, license OK — MIT/Apache-2.0 preferred)
   - **Screenshot or GIF** if helpful

We will curate accepted showcases into this file and link them from [README.md](README.md#community).

## Guidelines

- No secrets, tokens, or private data.
- Ensure you have rights to share the code/config.
- Keep it to one outcome per submission; link, don’t paste, large configs.
