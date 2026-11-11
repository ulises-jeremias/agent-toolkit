# Downstream patches — Agent Toolkit

This vendored copy of `crsolver/claude-pxl` @ `21fee41f7ecce00bc868d7567f24ffd0f3acc8fa`
carries Agent Toolkit downstream modifications. The SKILL.md **body** remains
byte-identical to upstream; the engine files below do **not**. Never describe
this tree as a byte-identical upstream copy.

## Patch log

| Area | Change | Reason |
|---|---|---|
| `src/core/canvas.ts` | Reject non-positive/non-finite `wire` `every` before the hang loop | Infinite loop on `every <= 0` (CodeRabbit #1742) |
| `src/node/server.ts` | Preserve the watched-file set after a load failure; read/transform responses before `writeHead`; start the SSE ping interval only after `listen` succeeds | Live-reload, crash and timer-leak fixes (CodeRabbit #1742) |
| `src/viewer/app.ts` | Skip viewer shortcuts for range/select fields and modified key events | Double step / browser shortcut hijack (CodeRabbit #1742) |
| `src/node/load.ts` | VM execution timeout, string/WASM code generation disabled in the art context, source byte/file-count caps; loader no longer described as a sandbox | Defense-in-depth for trusted art code; Node `vm` is **not** a security sandbox |
| `src/node/cli.ts`, `bin/pxl.js` | CLI requires an explicit `--trust-art` acknowledgement before executing art files; one-shot commands run in a supervised child process with a wall-clock timeout and a bounded heap | Prevent automatic execution of untrusted art; contain runaway trusted code |

## Execution policy

Art files (`.px.js`/`.px.ts`, plus everything they `include()`) are
**trusted executable code**. They run with the invoking user's privileges.
The controls above limit accidents and runaway work; they are not an OS
sandbox and do not make hostile art safe. Only run art you have reviewed.
The Desktop asset pipeline passes `--trust-art` only for the reviewed
in-repo sources under `apps/desktop/scripts/world-art-pxl/`.

See `UPSTREAM.md` for provenance and the (separate, still pending) human
trust-review binding.
