module agent_toolkit_core

import os
import time

// BackendDoctor is the isolated UI-backend probe (ADR-008). No invented Herdr APIs.
pub struct BackendDoctor {
pub:
	name      string
	available bool
	version   string
	reason    string
}

pub fn swarm_backend_names() []string {
	return ['herdr', 'tmux', 'headless', 'auto']
}

pub fn doctor_backend(name string) BackendDoctor {
	n := if name == 'auto' { 'headless' } else { name }
	return match n {
		'headless' {
			BackendDoctor{
				name:      'headless'
				available: true
				version:   'filesystem'
				reason:    'always available (ADR-008 filesystem SoT)'
			}
		}
		'tmux' {
			probe_unix_bin('tmux', ['tmux', '-V'])
		}
		'herdr' {
			probe_unix_bin('herdr', ['herdr', '--version'])
		}
		else {
			BackendDoctor{
				name:      n
				available: false
				reason:    'unknown backend'
			}
		}
	}
}

pub fn resolve_swarm_backend(requested string) string {
	name := if requested.len == 0 { 'auto' } else { requested }
	if name == 'auto' {
		h := doctor_backend('herdr')
		if h.available {
			return 'herdr'
		}
		t := doctor_backend('tmux')
		if t.available {
			return 'tmux'
		}
		return 'headless'
	}
	return name
}

pub fn swarm_runner_names() []string {
	return ['auto', 'skeleton', 'opencode', 'claude', 'codex', 'cursor', 'copilot', 'muse']
}

pub fn resolve_swarm_runner(requested string) string {
	name := if requested.len == 0 { 'opencode' } else { requested }
	if name == 'auto' {
		return 'auto'
	}
	return name
}

pub fn herdr_runner_cmd(runner string, role string, task string, worktree string, prompt_file string) string {
	has_task := task.trim_space().len > 0
	q_role := shell_quote(role)
	q_wt := shell_quote(if worktree.len > 0 { worktree } else { '.' })
	q_prompt_file := if prompt_file.len > 0 { shell_quote(prompt_file) } else { '' }
	q_task := shell_quote(task)
	cat_expr := if prompt_file.len > 0 { '"$(cat ' + q_prompt_file + ')"' } else { '' }
	match runner {
		'opencode' {
			if has_task {
				if prompt_file.len > 0 {
					return 'opencode --agent ' + q_role + ' --prompt ' + cat_expr
				}
				return 'opencode --agent ' + q_role + ' --prompt ' + q_task
			}
			return 'opencode --agent ' + q_role
		}
		'claude' {
			if has_task {
				if prompt_file.len > 0 {
					return 'claude --dangerously-skip-permissions --append-system-prompt-file ' + q_prompt_file + ' ' + cat_expr
				}
				return 'claude --dangerously-skip-permissions ' + q_task
			}
			return 'claude --dangerously-skip-permissions'
		}
		'codex' {
			if has_task {
				if prompt_file.len > 0 {
					return 'codex -C ' + q_wt + ' ' + cat_expr
				}
				return 'codex -C ' + q_wt + ' ' + q_task
			}
			return 'codex -C ' + q_wt
		}
		'cursor' {
			if has_task {
				if prompt_file.len > 0 {
					return 'cursor-agent ' + cat_expr
				}
				return 'cursor-agent ' + q_task
			}
			return 'cursor-agent'
		}
		'copilot' {
			if has_task {
				if prompt_file.len > 0 {
					return 'copilot --name ' + shell_quote('Swarm ' + role) + ' -i ' + cat_expr
				}
				return 'copilot --name ' + shell_quote('Swarm ' + role) + ' -i ' + q_task
			}
			return 'copilot --name ' + shell_quote('Swarm ' + role)
		}
		'muse' {
			if has_task {
				if prompt_file.len > 0 {
					return 'muse chat ' + cat_expr
				}
				return 'muse chat ' + q_task
			}
			return 'muse chat'
		}
		'skeleton', 'auto' {
			return "echo '[skeleton:" + role + "] ready -- no LLM' && exec " + shell_base()
		}
		else {
			if has_task {
				if prompt_file.len > 0 {
					return shell_quote(runner) + ' ' + cat_expr
				}
				return shell_quote(runner) + ' ' + q_task
			}
			return shell_quote(runner)
		}
	}
}

fn probe_unix_bin(name string, argv []string) BackendDoctor {
	$if windows {
		return BackendDoctor{
			name:      name
			available: false
			reason:    '${name} is Unix-only; not supported on Windows'
		}
	}
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv:    argv
		timeout: 5 * time.second
	}) or { return BackendDoctor{
		name:      name
		available: false
		reason:    err.msg()
	} }
	if res.timed_out {
		return BackendDoctor{
			name:      name
			available: false
			reason:    '${name} probe timed out'
		}
	}
	if res.exit_code != 0 {
		mut msg := res.stderr.trim_space()
		if msg.len == 0 {
			msg = res.stdout.trim_space()
		}
		if msg.len == 0 {
			msg = 'exit ${res.exit_code}'
		}
		return BackendDoctor{
			name:      name
			available: false
			reason:    msg
		}
	}
	mut ver := res.stdout.trim_space()
	if ver.len == 0 {
		ver = res.stderr.trim_space()
	}
	return BackendDoctor{
		name:      name
		available: true
		version:   ver
	}
}

fn find_git_root(start string) ?string {
	mut cur := if start.len > 0 { start } else { os.getwd() }
	for {
		git_dir := os.join_path(cur, '.git')
		if os.is_dir(git_dir) || os.is_file(git_dir) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return none
}
