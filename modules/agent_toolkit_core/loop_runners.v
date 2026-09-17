module agent_toolkit_core

import os
import time
import x.json2

// LLM runner adapters for `agent-toolkit loop run --runner`.
// Re-port of the Python-era runner table in docs/LOOP_RUNNER_DESIGN.md.
//
// Each runner is an argv adapter over an existing PATH binary plus stdout
// capture to the run dir. Availability is a PATH probe; unknown or missing
// runners fail closed to skeleton with a clear message (ADR-020).

// Implemented LLM runners. `cursor`, `copilot`, and `muse` share the swarm
// vocabulary; `pi` is loop-only (no swarm backend yet).
pub const loop_llm_runners = ['claude', 'opencode', 'codex', 'cursor', 'copilot', 'muse', 'pi']

// resolve_loop_runner maps the --runner flag (or AGENT_TOOLKIT_LOOP_RUNNER)
// to a concrete runner name. Returns '' when the name is not recognized;
// callers fail closed to skeleton in that case.
pub fn resolve_loop_runner(explicit string) string {
	mut name := explicit.trim_space().to_lower()
	if name == '' {
		name = os.getenv('AGENT_TOOLKIT_LOOP_RUNNER').trim_space().to_lower()
	}
	if name == '' || name == 'auto' {
		return 'auto'
	}
	if name in loop_llm_runners || name == 'skeleton' {
		return name
	}
	return ''
}

// runner_bin_chain maps a runner name to its PATH binaries in probe order.
// Cursor follows the Python-era chain (cursor-agent → agent → cursor).
pub fn runner_bin_chain(name string) []string {
	return match name {
		'claude' { ['claude'] }
		'opencode' { ['opencode'] }
		'codex' { ['codex'] }
		'cursor' { ['cursor-agent', 'agent', 'cursor'] }
		'copilot' { ['copilot'] }
		'muse' { ['muse'] }
		'pi' { ['pi'] }
		else { [] }
	}
}

// runner_binary maps a runner name to its primary PATH binary.
// Empty for non-binaries.
pub fn runner_binary(name string) string {
	chain := runner_bin_chain(name)
	if chain.len == 0 {
		return ''
	}
	return chain[0]
}

// resolve_runner_bin returns the first chain binary found on PATH, or ''.
fn resolve_runner_bin(name string) string {
	for bin in runner_bin_chain(name) {
		found := os.find_abs_path_of_executable(bin) or { '' }
		if found != '' {
			return bin
		}
	}
	return ''
}

// runner_is_available probes PATH for the runner binaries (no subprocess).
pub fn runner_is_available(name string) bool {
	return resolve_runner_bin(name) != ''
}

// auto_select_runner probes loop_llm_runners in order, then skeleton.
// (Python-era order had harness first; the harness stays external, so V
// auto covers LLM CLIs and ends at skeleton.)
pub fn auto_select_runner() string {
	for name in loop_llm_runners {
		if runner_is_available(name) {
			return name
		}
	}
	return 'skeleton'
}

// select_loop_runner fully resolves selection: returns (runner, note).
// note is '' on a clean pick, else the reason skeleton was chosen.
pub fn select_loop_runner(explicit string) (string, string) {
	name := resolve_loop_runner(explicit)
	if name == '' {
		return 'skeleton', "unknown runner '${explicit.trim_space()}' — failing closed to skeleton (use auto|skeleton|claude|opencode|codex|cursor|copilot|muse|pi)"
	}
	if name == 'skeleton' {
		return 'skeleton', ''
	}
	if name == 'auto' {
		picked := auto_select_runner()
		if picked == 'skeleton' {
			return 'skeleton', 'auto: no LLM runner on PATH — failing closed to skeleton'
		}
		return picked, ''
	}
	if !runner_is_available(name) {
		return 'skeleton', "runner '${name}' not on PATH — failing closed to skeleton"
	}
	return name, ''
}

// loop_run_prompt returns the full run prompt: loops/<name>/request.md when
// present (full runbooks live there), else the loop.yaml request: field.
pub fn loop_run_prompt(loop_dir string, meta_request string) string {
	req_path := os.join_path(loop_dir, 'request.md')
	if os.is_file(req_path) {
		content := os.read_file(req_path) or { '' }
		if content.trim_space() != '' {
			return content
		}
	}
	return meta_request
}

// loop_runner_sysprompt mirrors bin/loop-run-llm: report + STATE discipline.
pub fn loop_runner_sysprompt(loop_name string, run_id string, tier string, run_dir string, loop_dir string) string {
	return "You are executing loop '${loop_name}' (run ${run_id}, tier ${tier}). When finished, write your full report to ${run_dir}/report.md and refresh ${loop_dir}/report.md with the same content. Keep STATE.md checkpointing as instructed in the prompt."
}

// sh_quote renders one argv element safe for POSIX sh -c.
pub fn sh_quote(s string) string {
	if s == '' {
		return "''"
	}
	for c in s {
		if c.is_alnum() {
			continue
		}
		if c in [`_`, `@`, `%`, `+`, `=`, `:`, `,`, `.`, `/`, `-`] {
			continue
		}
		return "'" + s.replace("'", "'\\''") + "'"
	}
	return s
}

// loop_model returns AGENT_TOOLKIT_LOOP_MODEL trimmed ('' when unset).
fn loop_model() string {
	return os.getenv('AGENT_TOOLKIT_LOOP_MODEL').trim_space()
}

// runner_argv builds the child argv for a runner over prompt text.
// prompt travels as a single argv element (ARG_MAX-safe for runbooks).
pub fn runner_argv(name string, prompt string, sysprompt string) []string {
	full := if sysprompt != '' { sysprompt + '\n\n---\n\n' + prompt } else { prompt }
	model := loop_model()
	return match name {
		'claude' {
			mut argv := ['claude', '--print', '--allowedTools', 'Bash(gh *) Bash(git *) Edit Read Write Glob Grep',
				'--append-system-prompt', sysprompt]
			if model != '' {
				argv << '--model'
				argv << model
			}
			argv << prompt
			argv
		}
		'opencode' {
			mut argv := ['opencode', 'run']
			if model != '' {
				argv << '--model'
				argv << model
			}
			argv << full
			argv
		}
		'codex' {
			mut argv := ['codex', 'exec']
			if model != '' {
				argv << '--model'
				argv << model
			}
			argv << full
			argv
		}
		'cursor' {
			// Python-era form: <bin> --print --force --trust
			// --output-format text <prompt> (#228).
			bin := resolve_runner_bin('cursor')
			if bin == '' {
				[]string{}
			} else {
				[bin, '--print', '--force', '--trust', '--output-format', 'text', prompt]
			}
		}
		'copilot' {
			// Python-era form: copilot -p <prompt> -s --no-ask-user
			// --allow-all (#229); gh mutations still go through the gate.
			mut argv := ['copilot', '-p', prompt, '-s', '--no-ask-user', '--allow-all']
			if model != '' {
				argv << '--model'
				argv << model
			}
			argv
		}
		'muse' {
			// muse exec runs one prompt headless; --approval-mode never
			// keeps runs unattended without disabling the sandbox.
			mut argv := ['muse', 'exec', '--approval-mode', 'never']
			if model != '' {
				argv << '--model'
				argv << model
			}
			argv << prompt
			argv
		}
		'pi' {
			// pi -p is non-interactive; the loop sysprompt travels as
			// --append-system-prompt instead of fused into the prompt.
			mut argv := ['pi']
			if sysprompt != '' {
				argv << '--append-system-prompt'
				argv << sysprompt
			}
			if model != '' {
				argv << '--model'
				argv << model
			}
			argv << '-p'
			argv << prompt
			argv
		}
		else {
			[]string{}
		}
	}
}

pub struct RunnerResult {
pub:
	ok          bool
	timed_out   bool
	exit_code   int
	transcript  string // transcript.log path (always set)
	runner      string
	elapsed_sec i64
}

// execute_loop_runner runs the adapter with wall-clock enforcement and
// streams child output straight to transcript.log (no pipe deadlock).
// Returns ok=false only on spawn failure; timeouts and non-zero exits are
// reported in the result (caller records them, run still counts).
pub fn execute_loop_runner(name string, prompt string, sysprompt string, workdir string, run_dir string, wall_seconds int, gate GatePolicy) RunnerResult {
	transcript := os.join_path(run_dir, 'transcript.log')
	// Gate enforcement: per-run gate-bin/gh shim first on PATH, policy via env.
	mut env_prefix := ''
	if gate.tier != '' {
		gate_bin := os.join_path(run_dir, 'gate-bin')
		toolkit_bin := os.executable()
		real_gh := os.find_abs_path_of_executable('gh') or { '' }
		if real_gh != '' {
			gate_write_shim(gate_bin, toolkit_bin, real_gh) or {}
			env_prefix = 'ATK_GATE_TIER=' + sh_quote(gate.tier) + ' ATK_GATE_ALLOW=' + sh_quote(gate.allowlist.join(',')) + ' ATK_GATE_DENY=' + sh_quote(gate.deny.join(',')) + ' ATK_GATE_RUNDIR=' + sh_quote(run_dir) + ' ATK_GATE_RUNID=' + sh_quote(gate.run_id) + ' PATH=' + sh_quote(gate_bin + ':' + os.getenv('PATH')) + ' '
		}
	}
	argv := runner_argv(name, prompt, sysprompt)
	if argv == [] {
		return RunnerResult{
			ok:          false
			transcript:  transcript
			runner:      name
			elapsed_sec: 0
		}
	}
	mut parts := []string{}
	for a in argv {
		parts << sh_quote(a)
	}
	cmd := env_prefix + parts.join(' ') + ' > ' + sh_quote(transcript) + ' 2>&1'
	os.write_file(transcript, '') or {}
	start := time.now()
	mut p := os.new_process('/bin/sh')
	p.set_args(['-c', cmd])
	if workdir != '' && os.is_dir(workdir) {
		p.work_folder = workdir
	}
	p.run()
	wall := if wall_seconds > 0 { wall_seconds } else { 600 }
	deadline := start.add_seconds(wall)
	mut timed_out := false
	for p.is_alive() {
		if time.now() > deadline {
			p.signal_kill()
			timed_out = true
			break
		}
		time.sleep(500 * time.millisecond)
	}
	p.wait()
	code := p.code
	p.close()
	elapsed := time.now().unix() - start.unix()
	note := if timed_out {
		'\n[runner] wall timeout after ${wall}s — process killed\n'
	} else {
		''
	}
	existing := os.read_file(transcript) or { '' }
	os.write_file(transcript, existing + note) or {}
	return RunnerResult{
		ok:          true
		timed_out:   timed_out
		exit_code:   code
		transcript:  transcript
		runner:      name
		elapsed_sec: elapsed
	}
}

// run_loop_llm executes one loop iteration with an LLM runner and records
// the same artifacts skeleton does (plan.md, transcript.log, trace.jsonl,
// report discipline via prompt, STATE.md). Called from run_loop after the
// budget gates; gate enforcement around gh calls lands in PR2.
fn run_loop_llm(ws string, loop_name string, meta LoopMeta, loop_dir string, rid string, run_dir string, runs_today int, escalations []string, wall int, runner_name string, runner_note string) LoopReport {
	mut lines := []string{}
	if runner_note != '' {
		lines << '[loop] ${runner_note}'
	}
	lines << '[loop] Running ${loop_name} (tier=${meta.tier} cadence=${meta.cadence})'
	lines << '[loop] LLM runner: ${runner_name} (wall ${wall}s)'
	prompt := loop_run_prompt(loop_dir, meta.request)
	sysp := loop_runner_sysprompt(loop_name, rid, meta.tier, run_dir, loop_dir)
	gate := GatePolicy{
		tier:      meta.tier
		allowlist: meta.allowlist.clone()
		deny:      meta.deny.clone()
		run_dir:   run_dir
		run_id:    rid
	}
	res := execute_loop_runner(runner_name, prompt, sysp, ws, run_dir, wall, gate)
	if !res.ok {
		return LoopReport{
			ok:      false
			message: lines.join('\n') + '\n[loop] runner spawn failed for ${runner_name}'
			data:    {
				'subcommand': 'run'
				'workspace':  ws
				'name':       loop_name
				'run_id':     rid
				'status':     'spawn_failed'
				'runner':     runner_name
			}
		}
	}
	trace := '{"kind":"run_end","status":"completed","runner":' + json2.encode(runner_name,
		escape_unicode: true
	) + ',"run_id":' + json2.encode(rid,
		escape_unicode: true
	) + ',"transcript":"transcript.log","exit_code":${res.exit_code},"timed_out":${res.timed_out},"elapsed_sec":${res.elapsed_sec}}\n'
	os.write_file(os.join_path(run_dir, 'trace.jsonl'), trace) or {}
	write_state_md(loop_dir, time.utc().format_rfc3339(), 'completed', rid, runs_today + 1, escalations)
	lines << '[loop] transcript → ${res.transcript} (exit ${res.exit_code}, ${res.elapsed_sec}s)'
	if res.timed_out {
		lines << '[loop] wall timeout hit — runner killed, token accounting skipped (PR2 tailer)'
	}
	lines << '[loop] STATE.md updated (completed, runs_today+1)'
	return LoopReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'run'
			'workspace':  ws
			'name':       loop_name
			'run_id':     rid
			'status':     'completed'
			'runner':     runner_name
			'transcript': res.transcript
		}
	}
}
