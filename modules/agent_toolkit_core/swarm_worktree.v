module agent_toolkit_core

import os
import time

// SwarmWorktree mirrors Python state["worktrees"] entries.
pub struct SwarmWorktree {
pub mut:
	role   string
	branch string
	path   string
	exists bool
}

pub fn swarm_is_valid_role(role string) bool {
	if role.len < 2 || role.len > 32 {
		return false
	}
	first := role[0]
	if !(first >= `a` && first <= `z`) {
		return false
	}
	for i in 1 .. role.len {
		c := role[i]
		if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_` || c == `-`) {
			return false
		}
	}
	return true
}

fn swarm_sanitize_run_id(run_id string) string {
	mut res := ''
	for i in 0 .. run_id.len {
		b := run_id[i]
		is_ok := (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`) || (b >= `0` && b <= `9`)
			|| b == `.` || b == `_` || b == `-`
		if is_ok {
			res += run_id[i..i + 1]
		} else {
			res += '-'
		}
	}
	if res.len > 32 {
		return res[..32]
	}
	return res
}

pub fn swarm_branch_for_run_role(run_id string, role string) !string {
	if !swarm_is_valid_role(role) {
		return error('Invalid role: ${role}')
	}
	safe := swarm_sanitize_run_id(run_id)
	return 'agent-toolkit-swarm/${safe}/${role}'
}

pub fn swarm_worktree_path_for(run_dir string, role string) !string {
	if !swarm_is_valid_role(role) {
		return error('Invalid role: ${role}')
	}
	return os.join_path(run_dir, 'worktrees', role)
}

pub fn swarm_role_has_worktree(recipe string, role string) bool {
	if role == 'planner' {
		return false
	}
	roles := swarm_recipe_roles(recipe)
	if roles.len == 0 {
		return role != 'planner'
	}
	if role !in roles {
		return false
	}
	return role != 'planner'
}

pub fn swarm_recipe_lazy_start(recipe string) bool {
	return true
}

fn swarm_git_run(args []string, cwd string) RunResult {
	mut argv := ['git']
	argv << args
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv:    argv
		cwd:     cwd
		timeout: 15 * time.second
	}) or {
		return RunResult{
			exit_code: -1
			stderr:    err.msg()
		}
	}
	return res
}

pub fn swarm_create_worktree(repo_root string, run_dir string, role string, run_id string, base_ref string) !SwarmWorktree {
	branch := swarm_branch_for_run_role(run_id, role)!
	wt_path := swarm_worktree_path_for(run_dir, role)!
	if os.exists(wt_path) {
		return SwarmWorktree{
			role:   role
			branch: branch
			path:   wt_path
			exists: true
		}
	}
	br_ref := if base_ref != '' { base_ref } else { 'HEAD' }
	rev := swarm_git_run(['rev-parse', '--verify', branch], repo_root)
	if rev.exit_code != 0 {
		cre := swarm_git_run(['branch', branch, br_ref], repo_root)
		if cre.exit_code != 0 {
			msg := cre.stderr.trim_space()
			extra := if msg.len > 0 { msg } else { cre.stdout.trim_space() }
			return error('Failed to create branch ${branch}: ${extra}')
		}
	}
	os.mkdir_all(os.dir(wt_path)) or {
		return error('mkdir worktree parent failed: ${err.msg()}')
	}
	wt_res := swarm_git_run(['worktree', 'add', wt_path, branch], repo_root)
	if wt_res.exit_code != 0 {
		msg := wt_res.stderr.trim_space()
		extra := if msg.len > 0 { msg } else { wt_res.stdout.trim_space() }
		return error('Failed to create worktree ${wt_path}: ${extra}')
	}
	return SwarmWorktree{
		role:   role
		branch: branch
		path:   wt_path
		exists: false
	}
}

pub fn swarm_is_worktree_dirty(wt_path string) bool {
	res := swarm_git_run(['status', '--porcelain'], wt_path)
	if res.exit_code != 0 {
		return false
	}
	return res.stdout.trim_space().len > 0
}

pub fn swarm_remove_worktree(repo_root string, wt_path string, force bool) !bool {
	if !os.exists(wt_path) {
		return false
	}
	if !force && swarm_is_worktree_dirty(wt_path) {
		return error('Worktree dirty, refusing removal without --force: ${wt_path}')
	}
	mut args := ['worktree', 'remove', wt_path]
	if force {
		args << '--force'
	}
	swarm_git_run(args, repo_root)
	if os.exists(wt_path) {
		os.rmdir_all(wt_path) or {}
	}
	return true
}
