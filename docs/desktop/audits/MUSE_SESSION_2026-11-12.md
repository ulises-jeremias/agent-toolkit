# Muse session forensic audit — Desktop rescue

Audited 2026-11-12. Target: `01a1c6ee-e6b9-7aa2-bcbd-07fb9e2b3822`. This is an evidence inventory, not product acceptance.

## Recovery and scope

The original retained log exists at `~/.local/share/muse/sessions/2026/11/10/01a1c6ee-e6b9-7aa2-bcbd-07fb9e2b3822/session.jsonl` (120,904,035 bytes). Supported redacted export succeeded in a private workspace directory after `/tmp` export failed with quota error. Raw/private export is intentionally not included here. Export reports 77,766 records, 20 turns, 22 accepted spawns and three workflows. I parsed all root records and all 36 locally retained child logs; children include workflow participants and reminder agents, so 36 is not contradictory to 22 accepted spawns. Root contains 1,554 tool effects and all have terminal records; eight were non-completed, including one cancellation. The 4,780 omitted-live-only markers are explicit capture gaps, not proof that durable session history is missing. Image payloads and private conversations were not republished. No approval denial was found; session permissions explicitly allowed all with sandbox disabled. There were tool-policy rejections of unmanaged shell backgrounding, missing relative file paths and one failed exact edit.

## Timeline (UTC)

- **Nov 10 19:28:** PXL Renaissance discovery workflow. It identifies dirty/stale main checkout and requires clean worktrees. Crucially, discovery explicitly warns that #1667 ordering forbids World redesign before working Focus/durable-session Gate 2. It also discovers PXL's VM escape and requires trusted executable-art treatment. This security discovery becomes code/trust policy; the sequencing warning does not prevent the art-first delivery.
- **19:29–22:03:** PXL skill, pipeline, 201 sprites, UI recolor and legacy-generator removal implemented as #1742–1746. Native art children produce 67 initial and 134 additional sprites; final reports describe concrete preview corrections. Desktop/packaged checks are repeatedly polled. #1745 later closes unmerged and is replaced by #1750. Agent labels remaining work “human only” and marks goal blocked despite no real-provider Desktop trial yet.
- **Nov 11 05:16–09:45:** GitHub confirms #1742, #1743, #1744, #1750 and #1746 merged. Session fixes Ruff formatting, re-stacks branches, retries missing Actions triggers and macOS dmg resource-busy failure. At 10:29 it again claims all agent-executable work done; real provider/screen-reader/art acceptance remain absent.
- **11:22–18:47:** Broader PR integration, PXL governance #1753, Git history #1655, CI Ubuntu pin #1756, release #1666. v1.49.0 is independently confirmed published Nov 11 18:17:40 with 20 assets. The session reports closure of #1741, deferring product acceptance to #1667/#1673.
- **20:50:** Daily Driver Gates 0–1 audit workflow correctly finds no packaged real-provider evidence at its start, two evidence-validator systems, PTY-only interactions, no structured tool events, auth inferred only from executable availability, unenforced token/worktree options and restart/resume differences. T3 is not cloned/run by that audit; its capabilities remain unverified.
- **21:56 onward:** Website portal workflow creates #1762/#1763/#1764; integrated later through #1767. A child accidentally pushes art directly to main (`d53b52fc`) because of upstream push configuration. Force-restore is blocked by branch protection; `9436c2b7` reverts the change and the proper PR follows. Both commits independently exist. The initial portal implementation lacks screenshots/axe and has red visual gates; independent workflow review flags these rather than certifying success.
- **Nov 12 02:58:** Runtime reconciles a run as `orphaned_by_process_loss`; resume and compaction follow. Do not infer the exact cause of process loss.
- **03:00–04:54:** Website #1767 merges. Genuine packaged Codex trial #1769 merges 03:34; OpenCode reaches account free-usage limit twice, produces no diff, and is recorded blocked for coding/change steps. Ledger initially fails because a later blocked run invalidates earlier success. A subsequent genuine Codex retest restores latest success while preserving OpenCode blockage; #1772 merges 04:54.
- **By 05:45:** D01 onboarding uncovers external-repository linking rejected by server root policy; #1773 fixes it and #1774 adds real UI first-run coverage (native picker substituted headlessly). Final run is cancelled at 05:45:15; its CI watcher is cancelled. Last tool observation still shows #1773 mergeable but blocked on pending gates. GitHub confirms these merged later at 06:24 and 06:25, beyond this session's terminal boundary.

## Classification of substantial work

| Work | Classification | Evidence and limit |
|---|---|---|
| Governed PXL integration, deterministic pipeline, legacy removal | Completed and verified for code delivery | GitHub merged #1742/#1743/#1746/#1753; original security/trust findings retained. Trust remains experimental; do not invent human provenance attestation. |
| Hornero Valley art and warm UI | Implemented; usability not established | #1744/#1750 merged; genuine sprite preview corrections and screenshots recorded. Neither sprite count nor green tests establishes professional visual quality. Owner dissatisfaction is not a precise defect reproduction. |
| Original #1745 UI PR | Superseded | Closed unmerged, replacement #1750 merged. |
| Git history, dependency integration, CI repair, release | Completed and verified for integration/publication | Merge records and v1.49.0 assets confirmed; release is not Daily Driver acceptance. Session admits nearly losing 26 review commits during force-push/rebase and recovering them; preservation warrants Git review, not blind trust. |
| Website portal, PXL assets, documentation search | Completed and verified for merge | #1762/#1763/#1764/#1767 merged; #1759 closed. Owner art sign-off, Lighthouse budgets and screen-reader pass explicitly deferred. |
| Claude/Codex packaged baseline | Partially implemented acceptance | #1760/#1769 merged; authentic terminal trials and file changes recorded. These are PTY journeys, not structured Focus conversation acceptance. |
| OpenCode coding task | Blocked by external dependency | #1772 merged with account usage-limit evidence; session start/stop/relaunch exercised, coding change steps blocked. A later Codex pass must not erase provider-specific failure. |
| D01 first-run and outside-root repository registration | Unmerged at interruption; subsequently merged | #1773/#1774 now merged. D01 native folder-picker substitution and coherent-package limitations must remain explicit. |
| Provider architecture spike/ADR-043 | Partially implemented | #1761/#1768 merged. Architecture proof/decision is not production structured Focus. |
| Complete native Focus, coherent product redesign, complete accessibility/platform matrix | Never completed in this session | No native conversation surface delivered by the target session; full screen-reader, macOS/Windows live provider and broad failure matrix absent. |
| ImgBot #1766 | Superseded/rejected | Closed without merge because deterministic outputs would drift. #1771 remains open and requires separate current review. |

## Current work and collision boundary

GitHub and local worktrees show substantial **later** rescue work: #1776 structured Focus runtime and #1779 symlink protection are merged; #1780 `rescue/shell-v2` is open. Its first authored commit is Nov 12 07:12, after this target session ended. Do not attribute #1780 to this session or rewrite over it without review. Its current commits go beyond its stale PR body: `e30b9794` renders a new village and `0c730540` wires Projects/Context and live Person/swarm links, while the body still says the World is not rendered. Installed-app acceptance on the new UI is not established by the PR's old runtime trial. Worktrees `rescue`, `rescue/valley-art` and the owner's integration tree need preservation. Old PXL/web worktrees exist but are historical; existence alone is not runtime activity.

## Findings that must guide implementation

1. The strongest root-cause evidence is sequencing: art-first delivery proceeded despite explicit discovery that the productive Focus slice did not exist. Repeated “all agent-executable work done” claims were falsified by the session's own later successful provider trials. Keep acceptance tied to user journeys, not PR count.
2. Green ledger validation means evidence meets a schema. Two validators and latest-run/provider aggregation can hide practical distinctions. Preserve per-provider outcomes and require one coherent installed-build journey.
3. Preserve trusted-art execution guards, journal/symlink protections, authored Git history and external-repo migration behavior.
4. Complete the existing rescue slice only after inspecting its current code and actual installed UX. Do not treat current issue #1775's baseline statements as present-tense facts after #1776/#1779/#1780.
5. No claim here establishes current app beauty, live authentication validity, provider quota availability or completed product acceptance. Those require fresh runtime inspection by the integration owner.

## Reproducibility

Sources: retained root/child records and native workflow reconciliation outputs; read-only `gh pr list/view`, `gh issue view 1775`, `gh release view v1.49.0`; local `git worktree list` and direct verification of accidental-main push/revert commits. Tool terminal completion was not conflated with shell exit success. Current state was observed on Nov 12 and may evolve during integration.
