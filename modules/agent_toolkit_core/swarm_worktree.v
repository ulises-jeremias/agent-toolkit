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
		is_ok := (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`) || (b >= `0` && b <= `9`) || b == `.` || b == `_` || b == `-`
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

// Resolve the execution directory for a role. Writer roles must use the
// Toolkit-owned worktree recorded in run state; silently falling back to the
// project checkout would defeat swarm isolation.
fn swarm_role_execution_root(st SwarmStateFile, run_dir string, repo_root string, role string) !string {
	if !swarm_role_has_worktree(st.recipe, role) {
		return repo_root
	}
	expected := swarm_worktree_path_for(run_dir, role)!
	worktrees_dir := os.join_path(run_dir, 'worktrees')
	if os.is_link(run_dir) || os.is_link(worktrees_dir) || os.is_link(expected) || !os.is_dir(expected) {
		return error('Worktree path for ${role} is missing or uses a symlink; refusing to launch')
	}
	canonical_expected := os.join_path(os.real_path(run_dir), 'worktrees', role)
	if os.real_path(expected) != canonical_expected {
		return error('Worktree path for ${role} resolves outside this run; refusing to launch')
	}
	expected_branch := swarm_branch_for_run_role(st.run_id, role)!
	mut recorded := false
	for wt in st.worktrees {
		if wt.role == role {
			if os.real_path(wt.path) != canonical_expected || wt.branch != expected_branch {
				return error('Recorded worktree for ${role} is missing or outside this run; refusing to launch')
			}
			recorded = true
			break
		}
	}
	if !recorded {
		return error('Worktree for ${role} has not been recorded; refusing to launch')
	}
	if !swarm_is_registered_worktree(repo_root, canonical_expected, expected_branch)! {
		return error('Path for ${role} is not the registered swarm Git worktree; refusing to launch')
	}
	return expected
}

fn swarm_is_registered_worktree(repo_root string, path string, branch string) !bool {
	worktree_list := swarm_git_run(['worktree', 'list', '--porcelain'], repo_root)
	if worktree_list.exit_code != 0 {
		return error('Cannot verify Git worktree at ${path}')
	}
	mut current_path_matches := false
	for line in worktree_list.stdout.split_into_lines() {
		if line.starts_with('worktree ') {
			current_path_matches = line['worktree '.len..] == path
		} else if current_path_matches && line == 'branch refs/heads/${branch}' {
			return true
		}
	}
	return false
}

pub fn swarm_recipe_lazy_start(recipe string) bool {
	return true
}

fn swarm_git_run(args []string, cwd string) RunResult {
	mut argv := ['git']
	argv << args
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv: argv
		cwd: cwd
		timeout: 15 * time.second
	}) or {
		return RunResult{
			exit_code: -1
			stderr: err.msg()
		}
	}
	return res
}

pub fn swarm_create_worktree(repo_root string, run_dir string, role string, run_id string, base_ref string) !SwarmWorktree {
	branch := swarm_branch_for_run_role(run_id, role)!
	wt_path := swarm_worktree_path_for(run_dir, role)!
	worktrees_dir := os.join_path(run_dir, 'worktrees')
	if os.is_link(run_dir) || os.is_link(worktrees_dir) || os.is_link(wt_path) {
		return error('Cannot create worktree for ${role} through a symlink')
	}
	if os.exists(wt_path) {
		if !os.is_dir(wt_path) || !swarm_is_registered_worktree(repo_root, os.real_path(wt_path), branch)! {
			return error('Existing worktree path is not the registered swarm Git worktree: ${wt_path}')
		}
		return SwarmWorktree{
			role: role
			branch: branch
			path: wt_path
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
	os.mkdir_all(worktrees_dir) or {
		return error('mkdir worktree parent failed: ${err.msg()}')
	}
	wt_res := swarm_git_run(['worktree', 'add', wt_path, branch], repo_root)
	if wt_res.exit_code != 0 {
		msg := wt_res.stderr.trim_space()
		extra := if msg.len > 0 { msg } else { wt_res.stdout.trim_space() }
		return error('Failed to create worktree ${wt_path}: ${extra}')
	}
	return SwarmWorktree{
		role: role
		branch: branch
		path: wt_path
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
