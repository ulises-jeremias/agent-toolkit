# Blinded real-task evaluations

`scripts/run-blinded-eval.py` runs matched A/B comparisons between `agent-toolkit` and external baselines such as `pstack`, or across models and providers, without leaking candidate identities to a judge or trusting unverified model self-reports.

## Guarantees

1. **Leak-word sanitization.** `prepare` scans `task_prompt` and every judge-visible candidate field for tool, harness, model, vendor, branch, and system-prompt markers before writing the judge package. Any match fails closed.
2. **Separated blind mapping.** Candidates are sorted canonically, shuffled with a SHA-256 derived seed, and assigned `Candidate A`, `Candidate B`, and so on. The reveal map lives in a separate file bound to the judge package SHA-256 digest.
3. **Cross-vendor judge enforcement.** `prepare` compares the judge model and vendor against every candidate model and vendor and fails closed if any overlap exists. Pass `--allow-same-vendor` only for local dry runs.
4. **Transcript tool-call auditing.** `audit-transcript` parses JSONL or JSON agent transcripts to extract executed commands, exit codes, and test runs, then flags self-reported pass claims that lack a matching passing execution or contradict a non-zero exit code.
5. **Candidate-bound receipts.** `emit-receipt` produces JSON validated against `schemas/goal-evidence-v1.schema.json`, bound to `candidate_sha`, and tagged with `evidence_mode` (`fixture`, `hermetic`, or `real`). It never upgrades `fixture` evidence to `hermetic` or `real`, and never emits `pass` when a linked transcript audit contains unverified claims or failures.

## Manifest format

Create a JSON or YAML manifest describing the task, judge, and candidates:

```json
{
  "eval_id": "eval-gap4-001",
  "task_id": "fix-boundary-check",
  "task_prompt": "Fix the boundary check in parser.py and add unit tests.",
  "evidence_mode": "hermetic",
  "judge": {
    "model": "gemini-2.5-pro",
    "vendor": "google"
  },
  "candidates": [
    {
      "candidate_id": "run-alpha",
      "tool": "agent-toolkit",
      "model": "claude-sonnet-4-5",
      "vendor": "anthropic",
      "branch": "feat/alpha-fix",
      "candidate_sha": "1111111111111111111111111111111111111111",
      "summary": "Fixed upper bound check and added regression tests.",
      "diff": "..."
    },
    {
      "candidate_id": "run-beta",
      "tool": "pstack",
      "model": "gpt-5",
      "vendor": "openai",
      "branch": "feat/beta-fix",
      "candidate_sha": "2222222222222222222222222222222222222222",
      "summary": "Clamped index before slice evaluation.",
      "diff": "..."
    }
  ]
}
```

Do not include `tool`, `model`, `vendor`, `branch`, or `candidate_id` strings inside `task_prompt`, `summary`, `diff`, `notes`, or `artifacts`. `prepare` extracts those metadata values from each candidate automatically and rejects any leak into judge-visible text.

## Workflow

Run each subcommand non-interactively via `uv run` or `python3`:

```sh
# 1. Prepare a blinded judge package and separate reveal map
uv run --project packages/pypi/agent-toolkit-cli --directory . \
  python scripts/run-blinded-eval.py prepare \
  --manifest eval.json \
  --seed 42 \
  --judge-out out/judge.json \
  --reveal-out out/reveal.json

# 2. Audit candidate execution transcripts for verified test runs
uv run --project packages/pypi/agent-toolkit-cli --directory . \
  python scripts/run-blinded-eval.py audit-transcript \
  --transcript runs/alpha.jsonl \
  --output out/alpha-audit.json

# 3. Emit a Goal v1 evidence receipt bound to candidate_sha
uv run --project packages/pypi/agent-toolkit-cli --directory . \
  python scripts/run-blinded-eval.py emit-receipt \
  --task-id fix-boundary-check \
  --repository ulises-jeremias/agent-toolkit \
  --base-sha 0000000000000000000000000000000000000000 \
  --candidate-sha 1111111111111111111111111111111111111111 \
  --mode hermetic \
  --environment local-pytest-sandbox \
  --audit out/alpha-audit.json \
  --judge-package out/judge.json \
  --reveal-map out/reveal.json \
  --output out/alpha-receipt.json

# 4. Verify the receipt before accepting results
uv run --project packages/pypi/agent-toolkit-cli --directory . \
  python scripts/run-blinded-eval.py verify-receipt \
  --receipt out/alpha-receipt.json \
  --expected-candidate-sha 1111111111111111111111111111111111111111 \
  --disallow-fixture \
  --artifact out/alpha-audit.json \
  --artifact out/judge.json
```

## Evidence modes

Keep synthetic fixtures separate from real evaluations, following `docs/GOALS.md`:

- `fixture`: synthetic dry-run payloads or canned transcripts. Use `--disallow-fixture` in `verify-receipt` when gating release or merge checks.
- `hermetic`: isolated local test or build runs executed in a clean worktree without external provider side effects.
- `real`: live runs against target models, providers, and repositories. State the observed environment in `--environment`.

Passing `--source-mode fixture` (or linking a `fixture` manifest) blocks `--mode hermetic` and `--mode real` in both `emit-receipt` and `verify-receipt`.
