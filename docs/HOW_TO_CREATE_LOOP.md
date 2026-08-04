# How to Create a Loop Template

Loops are recurring agentic workflows. Each loop runs on a cadence, observes or acts on repositories, and stops when its goal is met, its budget is exhausted, or a human escalation is required. This guide walks you through creating a new loop template from scratch.

Read `docs/LOOPS.md` first for the conceptual overview. This document is the practical creation guide.

---

## 1. Choose the Right Tier

Every loop has a tier that declares its risk level and required oversight.

### L1 — Observe and Report

L1 loops are **read-only or proposal-only**. They gather information, analyze it, and write a report. They never mutate repository state and are safe to run frequently.

Typical actions: read issues, read PRs, read CI status, write `report.md`, propose labels without applying them.

**Start here.** All new loops should begin at L1. Run it clean for at least 3 days before considering an upgrade.

Token budgets: 20,000 – 150,000 per run.

### L2 — Controlled Mutations

L2 loops can make changes within a tightly scoped `allowlist`. Common L2 actions: merge Dependabot PRs with passing CI, apply labels, post comments, close merged branches, open draft PRs.

Every L2 loop must have an explicit `deny` list that prevents high-risk actions (`force-push`, `approve`, `push` to main).

Prerequisite: the equivalent L1 loop has run reliably for at least 3 clean runs.

Token budgets: 50,000 – 300,000 per run.

### L3 — High-Autonomy

L3 is reserved for loops that have been running stably as L2 for an extended period. The permission set is the same as L2 — L3 is an operational maturity designation, not a different code path.

In practice, most teams run all loops at L1 or L2. Start with L1.

---

## 2. Create the Loop Directory

```bash
mkdir -p loops/<loop-name>
```

Loop names must be kebab-case and must match the `name` field in `loop.yaml`:

```bash
# Good
mkdir -p loops/stale-issue-closer
mkdir -p loops/dep-audit-weekly

# Bad
mkdir -p loops/StaleIssueCloser
mkdir -p loops/dep_audit
```

The directory will hold:

```
loops/<loop-name>/
├── loop.yaml     # Required: loop definition (you write this)
├── STATE.md      # Runtime: checkpoint state (written by the loop runner)
└── report.md     # Runtime: output report (written by the AI)
```

Do not commit `STATE.md` or `report.md` — they are runtime artifacts generated on each run.

---

## 3. Required YAML Fields

Create `loops/<loop-name>/loop.yaml`. Every loop manifest must have at minimum:

```yaml
name: <loop-name>         # Required: kebab-case, matches directory name
goal: |                   # Required: declarative success condition
  What does success look like for this loop?
request: |                # Required: the full prompt passed to the agent
  Step-by-step instructions for the agent...
```

### Full field reference

```yaml
name: stale-issue-closer
description: "Daily L1 read-only report on stale issues (no mutations)"
tier: L1
cadence: 1d

goal: |
  Produce a daily report identifying issues that have been open for more
  than 30 days with no activity. No mutations. Read-only.

allowlist: []             # Empty = read-only (L1 typical)
deny:
  - comment
  - label
  - assign
  - merge
  - close
  - push
  - approve
  - force-push

exit_conditions:
  - goal_met
  - budget_exhausted
  - human_escalation

budget:
  max_tokens: 30000
  max_runs_per_day: 1
  max_wall_seconds: 600

verifier: null            # null = no post-run verification agent
resumable: true

request: |
  [Full prompt here — see section 4]
```

---

## 4. Write the Request Prompt

The `request` field is the full set of instructions passed to the agent on every run. Write it as if you are briefing a capable but context-free engineer at the start of every shift. Include:

1. **What this loop does** — one sentence framing
2. **Resumability instructions** — if `resumable: true`, tell the agent how to read and update `STATE.md`
3. **Step-by-step procedure** — numbered, specific, unambiguous
4. **Output format** — exactly what to write and where
5. **Safety constraints** — re-state the `deny` list in plain language

### Resumability pattern

If your loop processes a list of items (repos, issues, PRs), use this pattern:

```yaml
request: |
  You are running the Stale Issue Closer loop (L1 — read-only).

  **Resumability:**
  Read loops/stale-issue-closer/STATE.md.
  If `last_processed_repo` is set, resume from that repo.
  After processing each repo, write:
    last_processed_repo: <owner>/<repo>
    last_run: <ISO-8601 timestamp>
  On completion, clear `last_processed_repo` and set:
    last_run_status: success
    last_run: <ISO-8601 timestamp>

  **Step 1 — Identify stale issues (read-only)**
  For each repo in the configured list:
    gh issue list --repo <owner>/<repo> --state open --json number,title,createdAt,updatedAt,labels

  A stale issue is one where:
  - Created more than 30 days ago
  - No update (comment, label change, assignee change) in the last 14 days
  - Not pinned and not labeled "help-wanted" or "good first issue"

  **Step 2 — Write report**
  Write to loops/stale-issue-closer/report.md:

  ## Stale Issue Report — <date>

  | Repo | # | Title | Age | Last activity |
  |------|---|-------|-----|---------------|
  ...

  ### Recommended actions (proposals only — do not apply)
  ...

  **Safety: Do not comment, label, close, or modify any issue.**
```

---

## 5. Set a Conservative Budget

Estimate your token budget before writing it. The formula:

```
max_tokens = (tokens_per_repo × repo_count) × 1.3 safety_margin
```

Typical token costs per repo:

| Operation | Tokens (approximate) |
|-----------|---------------------|
| List open PRs (20 PRs) | ~800 |
| List open issues (50 issues) | ~2,000 |
| Read CI check-suite status | ~300 |
| Write one report entry | ~150 |
| Model reasoning overhead per repo | ~500 |

**Starter budgets:**

| Ecosystem size | L1 daily briefing | L1 issue scan | L2 PR monitor |
|----------------|------------------|---------------|---------------|
| 5 repos | 15,000 | 25,000 | 50,000 |
| 10 repos | 25,000 | 40,000 | 80,000 |
| 20 repos | 50,000 | 80,000 | 160,000 |
| 40 repos | 80,000 | 150,000 | 300,000 |

When in doubt, start lower. `budget_exhausted` is a normal exit condition — the agent checkpoints its state and the next run picks up where it left off.

---

## 6. Add Resumability for Multi-Repo Loops

Set `resumable: true` if your loop processes a list (repos, issues, PRs) and could hit the budget ceiling mid-run. Resumable loops write a `STATE.md` checkpoint after each item.

**When to use:**
- Processing 5+ repos in a single run
- Processing 20+ issues or PRs in a single run
- Any loop where partial work is better than restarting from zero

**STATE.md format (written by the agent):**

```markdown
last_processed_repo: owner/repo-name
last_run: 2026-08-04T09:15:00Z
last_run_status: partial (budget_exhausted)
```

On the next run, the agent reads this file and skips already-processed items.

---

## 7. Run Validation

```bash
# Install dependencies if needed
pip install pyyaml jsonschema

# Validate your loop
python3 -c "
import json, yaml, sys
from pathlib import Path
from jsonschema import validate, ValidationError
schema = json.loads(Path('schemas/loop.schema.json').read_text())
f = Path('loops/<loop-name>/loop.yaml')
d = yaml.safe_load(f.read_text())
try:
    validate(d, schema)
    print('Valid:', f)
except ValidationError as e:
    print('FAIL:', e.message)
    sys.exit(1)
"
```

Or run the full CI validation suite:

```bash
# All loops at once
python3 -c "
import json, yaml, sys
from pathlib import Path
from jsonschema import validate, ValidationError
schema = json.loads(Path('schemas/loop.schema.json').read_text())
errors = []
for f in sorted(Path('loops').rglob('loop.yaml')):
    d = yaml.safe_load(f.read_text())
    try: validate(d, schema)
    except ValidationError as e: errors.append(f'{f}: {e.message}')
if errors:
    [print(e) for e in errors]; sys.exit(1)
print(f'All {len(list(Path(\"loops\").rglob(\"loop.yaml\")))} loop(s) valid.')
"
```

---

## 8. Graduated Testing: L1 First

Never deploy a new loop at L2 or L3. Follow this sequence:

### Step 1: Create at L1

Set `tier: L1`, `allowlist: []`, and full `deny` list. Run the loop manually and read the output report.

### Step 2: Run at L1 for 3+ clean days

A "clean run" means:
- The agent stayed within budget
- The report is accurate and useful
- No unexpected API calls or mutations attempted

If any run exits with `error` or `human_escalation`, investigate and fix before continuing.

### Step 3: Evaluate for upgrade to L2

After 3 clean L1 runs, ask:
- Do the proposed actions in the report look correct?
- Is the report stable (not noisy, not missing things)?
- Do you trust the loop to act without your per-action approval?

If yes to all three, proceed to L2.

### Step 4: Upgrade to L2

Change `tier: L2`, populate `allowlist` with only the specific actions needed, and update the request prompt to actually apply those actions (not just propose them). Re-run validation.

---

## 9. PR Checklist

```markdown
## Loop Checklist
- [ ] `loops/<loop-name>/loop.yaml` created
- [ ] `name`, `goal`, and `request` fields present
- [ ] `tier` set (L1 for all new loops)
- [ ] `budget.max_tokens` set to a conservative estimate
- [ ] `exit_conditions` includes `budget_exhausted` and `goal_met`
- [ ] `deny` list is comprehensive for the tier (L1: deny all mutations)
- [ ] `resumable: true` for any loop processing 5+ items
- [ ] Validation passes: `python3 scripts/validate-loops.py` (or manual schema check)
- [ ] `STATE.md` and `report.md` are in `.gitignore` (or the loop's own .gitignore)
- [ ] No secrets or hardcoded tokens in `loop.yaml`
- [ ] Request prompt includes explicit safety constraint statements
```

---

## Complete Example: stale-issue-closer

A read-only L1 loop that identifies stale issues in a GitHub repo daily.

### loops/stale-issue-closer/loop.yaml

```yaml
name: stale-issue-closer
description: "Daily L1 read-only report of stale issues — no mutations"
tier: L1
cadence: 1d
resumable: true

goal: |
  Produce a daily report identifying open issues with no activity in 14+ days,
  open for 30+ days. Propose actions without applying them. Read-only.

allowlist: []
deny:
  - comment
  - label
  - assign
  - merge
  - close
  - push
  - approve
  - force-push

exit_conditions:
  - goal_met
  - budget_exhausted
  - human_escalation

budget:
  max_tokens: 30000
  max_runs_per_day: 1
  max_wall_seconds: 600

verifier: null

request: |
  You are running the Stale Issue Closer loop (L1 — read-only daily report).

  **Resumability:**
  Read loops/stale-issue-closer/STATE.md if it exists.
  If `last_processed_repo` is set, skip repos before that entry in the list.
  After each repo, write to STATE.md:
    last_processed_repo: <owner>/<repo>
    last_run: <ISO-8601 timestamp>
    last_run_status: in_progress
  On completion, write:
    last_processed_repo: ""
    last_run: <ISO-8601 timestamp>
    last_run_status: success

  **Step 1 — Configure repo list**
  Read the repo list from packs/ or from the REPOS environment variable.
  If neither is set, default to the repos returned by:
    gh repo list --limit 20 --json nameWithOwner

  **Step 2 — For each repo, find stale issues**
  gh issue list \
    --repo <owner>/<repo> \
    --state open \
    --limit 100 \
    --json number,title,createdAt,updatedAt,labels,assignees

  A stale issue matches ALL of these:
  - createdAt is more than 30 days ago
  - updatedAt is more than 14 days ago
  - None of the labels are: "pinned", "help-wanted", "good first issue", "security"

  **Step 3 — Write report**
  Write the report to loops/stale-issue-closer/report.md:

  ## Stale Issue Report — <YYYY-MM-DD>

  Generated: <ISO-8601 timestamp>
  Repos scanned: <N>
  Stale issues found: <N>

  ### Issues

  | Repo | # | Title | Age | Last activity |
  |------|---|-------|-----|---------------|
  | owner/repo | 123 | Fix the thing | 45d | 18d ago |

  ### Proposed actions (not applied — review before acting)

  For issues stale 60+ days: recommend close with comment
  For issues stale 30–59 days: recommend "needs-info" label and comment

  **SAFETY: Do not comment, label, close, or modify any issue.
  This loop is read-only. Report only.**
```
