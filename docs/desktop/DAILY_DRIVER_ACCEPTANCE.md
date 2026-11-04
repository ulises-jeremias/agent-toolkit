# Daily Driver Acceptance — installed product evidence

> **Status: UNVERIFIED BASELINE as of 2026-11-04.** This document is a new human/product acceptance contract, not a declaration that the current Desktop passes. Mission [#1667](https://github.com/ulises-jeremias/agent-toolkit/issues/1667); baseline [#1668](https://github.com/ulises-jeremias/agent-toolkit/issues/1668).

The existing `workflows.yaml` component ledger may be 18/18 `ok`, but it **does not certify** daily-driver usability or subscription-backed live provider functionality. Do not automatically copy those statuses here.

## Evidence levels

| Level | Meaning | Can sign off a real-provider task? |
| --- | --- | --- |
| **P — Packaged, real provider** | Installed binary, live authenticated local coding agent, observed real files/events | **Yes**, with reproducible trace |
| **S — Source build, real provider** | Dev build and real local agent | Partial; packaging remains unverified |
| **R — Deterministic replay** | Real captured provider trace replayed against current code | Supports regression only |
| **M — Mock/skeleton** | No genuine provider process or task | **No** |
| **U — Unverified** | Not executed, unavailable host, or insufficient evidence | **No** |

A screenshot of an NPC, green CI, a test fixture or a successfully started PTY does **not** upgrade M/R to P.

## Controlled project and safe task

Create a fresh throwaway Git repo separate from confidential user projects with a minimal failing test and a clear desired patch. Node's built-in test runner is acceptable (no network dependency):

```sh
mkdir -p /tmp/atk-daily-driver/src /tmp/atk-daily-driver/test
cd /tmp/atk-daily-driver && git init
printf 'export const sum = (a, b) => a - b;\n' > src/sum.mjs
printf "import test from 'node:test';\nimport assert from 'node:assert/strict';\nimport { sum } from '../src/sum.mjs';\ntest('sum', () => assert.equal(sum(2, 3), 5));\n" > test/sum.test.mjs
git add . && git commit -m 'test: establish failing fixture'
node --test
```

Task prompt: **"Fix the failing sum test without modifying the test, explain the change and execute `node --test`. Show me what changed."** This is a deterministic control, not a substitute for a real multi-file feature on an existing project.

## Product journeys (every one has its own evidence row)

| ID | Journey | Required outcome |
| --- | --- | --- |
| D01 | First run | Clean installed Desktop opens, user selects repo without terminal or manual config |
| D02 | Provider detection | Installed/authenticated Claude, Codex, OpenCode are shown accurately; unavailable reasons explicit |
| D03 | Start | Send task with explicit provider/model/permission; native session created, real process/event identity visible |
| D04 | Observe | Real streamed messages/tool actions/commands/history and latency; errors not hidden |
| D05 | Intervene | Answer a provider-native approval/question, cancel task and observe authoritative terminal state |
| D06 | Terminal & changes | Type into actual PTY where supported; inspect exact modified file diff and test result |
| D07 | Recover | Close and relaunch Desktop; inspect existing history; resume if supported, else clear not-resumable reason |
| D08 | Semantic world | Active session is one accurately associated character; hover shows last real action; click opens the same Focus run |
| D09 | Multi-provider | Delegate code review to another authenticated provider through real runtime tool/MCP; inspect artifacts and lineage |
| D10 | Toolkit capabilities | Use skill/persona/context pack/memory and schedule a loop in the same project-scoped session |

### Run form — copy for each execution

```yaml
mission: 1667
journey_id: D03
outcome: fail # pass|fail|blocked|unverified
evidence_level: U # P|S|R|M|U
toolkit_sha: "<exact commit>"
package_version: "<installer/release + checksum>"
platform: "<OS/build/window manager/architecture>"
provider: "<provider + executable version + auth type; never paste tokens>"
model: "<verified model or unknown>"
workspace: "<sanitized throwaway path>"
test_task: "<fixture or real task id>"
timestamp_utc: "<ISO-8601>"
steps_to_reproduce: "<exact UI actions>"
observed: "<actual result>"
expected: "<required outcome>"
logs: ["<redacted path or CI artifact URL>"]
screenshots: ["<redacted screenshot artifact>"]
related_issues: []
tested_by: "<tester>"
```

Do not commit auth headers, raw private provider conversations, account names, secret-containing terminal output or proprietary code.

## Gate 0 field trial

- Run D01→D07 in one uninterrupted session on an **installed** Desktop at least once; record failed/blocked stages, do not skip inconvenient steps.
- Repeat D02→D07 separately for Claude, Codex and OpenCode when authenticated. Unavailable provider is recorded as blocked, **not** silently mocked.
- Exercise failure conditions: absent provider binary, expired authentication, denied permission, provider crash, renderer crash, backend restart, lost PTY, concurrent sessions, dirty git worktree.
- Run D08→D10 after the prerequisite implementation exists; their current status remains **U** until personally verified.
- Collect uncut recording or timestamped screenshots (with redactions), provider and Toolkit versions, resource usage and actual task result.
- Use one screen size ~1024x640, one ~1440x900, one ~1920x1080, plus keyboard-only navigation.
- Document top-five blockers with reproducible defects; fix and **repeat** journey before setting pass.

## Cross-provider / cross-platform gates

D09 must run a real delegated child in a **different provider instance**, not two roles in one provider's internal subagent system. The parent must not claim completion while child work remains active, and permission escalation must fail closed. Git provenance must survive a worktree switch.

Linux (including Wayland/Hyprland where available), Windows and macOS should use their actual installers, not only Playwright renderer preview. Signing or a missing host can be recorded as blocked, never passed.

## Release decision

Daily-driver release is blocked if D01–D07 have no P-level proof on the target platform, or if D03–D06 have a known critical usability/security failure. D08–D10 are later release gates, not prerequisites for the first functional MVP. Every gate status and host limitation belongs in the PR/release notes.

**Quality target:** An independent developer completes an actual fix and reviews its test/diff/permissions using only the installed Toolkit application. No shell workaround, feature-demo fiction or maintainer intervention.
