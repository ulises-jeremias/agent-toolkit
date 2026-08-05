---
name: jupyter-notebook
description: Create, scaffold, or refactor Jupyter notebooks (.ipynb) for experiments and tutorials. Prefer the bundled templates and the helper script (`new_notebook.py`, also exposed as `newnotebook`) to generate a clean starting notebook instead of authoring raw notebook JSON.
---

# Jupyter Notebook

Create clean, reproducible Jupyter notebooks for two primary modes:

- **Experiments** — exploratory analysis, ablations, hypothesis testing.
- **Tutorials** — instructional walkthroughs, teaching-oriented notebooks.

Prefer the bundled templates and the helper script for consistent structure and
fewer JSON mistakes.

## When to use

- Create a new `.ipynb` notebook from scratch.
- Convert rough notes or scripts into a structured notebook.
- Refactor an existing notebook to be more reproducible and skimmable.
- Build experiments or tutorials that will be read or re-run by other people.

## Decision tree

- Exploratory / analytical / hypothesis-driven → `experiment`.
- Instructional / step-by-step / audience-specific → `tutorial`.
- Editing an existing notebook → treat as a refactor: preserve intent and
  improve structure.

## Prerequisites

- `python3` (provided by `bootstrap`).
- Optional: `uv` for local notebook execution and dependency isolation
  (also from `bootstrap`).

`skills check jupyter-notebook` validates `python3` is present.

## Helper script

The bundled scaffolder (`scripts/new_notebook.py`, stdlib only) loads a
template, updates the title cell, and writes a notebook to `--out`. Two ways
to invoke it:

### Option A — `newnotebook` wrapper (recommended)

`bootstrap` installs a tiny wrapper at `~/.local/bin/newnotebook` so
the script is available without remembering its full path:

```bash
newnotebook --kind experiment \
  --title "Compare prompt variants" \
  --out output/jupyter-notebook/compare-prompt-variants.ipynb

newnotebook --kind tutorial \
  --title "Intro to embeddings" \
  --out output/jupyter-notebook/intro-to-embeddings.ipynb
```

### Option B — call the script directly

```bash
python3 ~/.local/share/agent-toolkit/skills/jupyter-notebook/scripts/new_notebook.py \
  --kind experiment \
  --title "Compare prompt variants" \
  --out output/jupyter-notebook/compare-prompt-variants.ipynb
```

If you prefer `uv` for a pinned interpreter:

```bash
uv run --python 3.12 python ~/.local/share/agent-toolkit/skills/jupyter-notebook/scripts/new_notebook.py \
  --kind tutorial \
  --title "Intro to embeddings"
```

The script uses **only the Python standard library** — no extra deps required.

## Workflow

1. **Lock the intent.** Pick `experiment` or `tutorial`. Capture the objective,
   audience, and what "done" looks like.
2. **Scaffold from the template** (use `newnotebook` or option B above).
3. **Fill the notebook with small, runnable steps.** Keep each code cell
   focused on one step. Add short markdown cells that explain purpose and
   expected result. Avoid large, noisy outputs when a short summary works.
4. **Apply the right pattern.** For experiments, follow
   [`references/experiment-patterns.md`](references/experiment-patterns.md).
   For tutorials,
   [`references/tutorial-patterns.md`](references/tutorial-patterns.md).
5. **Edit safely when working with existing notebooks.** Preserve structure;
   avoid reordering cells unless it improves the top-to-bottom story. Prefer
   targeted edits over full rewrites. If you must edit raw JSON, review
   [`references/notebook-structure.md`](references/notebook-structure.md) first.
6. **Validate the result.** Run the notebook top-to-bottom when the environment
   allows. If execution is not possible, say so explicitly and call out how to
   validate locally. Use the final pass checklist in
   [`references/quality-checklist.md`](references/quality-checklist.md).

## Templates and helper script

- Templates live in `assets/experiment-template.ipynb` and
  `assets/tutorial-template.ipynb` (chezmoi-managed, read-only — do not edit
  in place; copy and modify).
- The helper script loads a template, updates the title cell, and writes a
  notebook.

## Temp and output conventions

- Use `tmp/jupyter-notebook/` for intermediate files; delete when done.
- Write final artifacts under `output/jupyter-notebook/` when working in a
  repository.
- Use stable, descriptive filenames (e.g. `ablation-temperature.ipynb`).

## Dependencies (install only when needed)

Prefer `uv` for dependency management.

Optional Python packages for local notebook execution:

```bash
uv pip install jupyterlab ipykernel
```

The bundled scaffold script needs no extra dependencies.

## Boundaries

- This skill **scaffolds and refactors** notebooks. It does not run them — for
  execution, use Jupyter / VS Code / the user's preferred runtime.
- Do not commit notebook outputs that contain secrets or large binary blobs;
  clear outputs before staging when in doubt.

## Reference map

- [`references/experiment-patterns.md`](references/experiment-patterns.md) —
  experiment structure and heuristics.
- [`references/tutorial-patterns.md`](references/tutorial-patterns.md) —
  tutorial structure and teaching flow.
- [`references/notebook-structure.md`](references/notebook-structure.md) —
  notebook JSON shape and safe editing rules.
- [`references/quality-checklist.md`](references/quality-checklist.md) —
  final validation checklist.
