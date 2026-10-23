module agent_toolkit_core

import time

// project_git.v — typed git working-tree surface for one registered
// project: status, per-file diff, stage/unstage, and commit. Every
// operation shells out to the user's own `git` with argv only (no
// shell) inside the resolved project repository. Failures are
// reported as ok=false with git's own message — never as fake data.
// Mutations validate every path as repository-relative before git
// sees it, so a caller can never stage outside the project.

pub struct GitFileChange {
pub:
	path string
	code string // the two-character porcelain XY status, e.g. "M.", ".M", "A."
}

pub struct ProjectGitStatusResponse {
pub:
	ok      bool
	project string
pub mut:
	branch    string
	staged    []GitFileChange
	unstaged  []GitFileChange
	untracked []GitFileChange
	detail    string
}

pub struct ProjectGitDiffResponse {
pub:
	ok        bool
	project   string
	path      string
	staged    bool
	diff      string
	truncated bool
	detail    string
}

const max_git_diff_chars = 200_000
const max_git_paths = 200

fn git_run(root string, args []string) !RunResult {
	mut argv := ['git', '-C', root]
	argv << args
	res := new_process_service().run(RunOptions{
		argv: argv
		cwd: root
		timeout: 30 * time.second
	}) or { return error('git is not available: ${err.msg()}') }
	if res.timed_out {
		return error('git ${args[0]} timed out')
	}
	return res
}

fn git_fail(project string, res RunResult) ProjectGitStatusResponse {
	msg := res.stderr.trim_space()
	return ProjectGitStatusResponse{
		ok: false
		project: project
		detail: if msg.len > 0 { msg } else { 'git exited with code ${res.exit_code}' }
	}
}

// rest_after_fields returns the remainder of a porcelain v2 line after
// skipping n space-separated fields; paths may themselves contain spaces.
fn rest_after_fields(line string, fields int) string {
	mut skipped := 0
	for i, ch in line {
		if ch == ` ` {
			skipped++
			if skipped == fields {
				return line[i + 1..]
			}
		}
	}
	return ''
}

// parse_git_status_v2 parses `git status --porcelain=v2 --branch` output
// into staged / unstaged / untracked buckets. It is a pure function so
// the porcelain contract is unit-testable without a repository.
pub fn parse_git_status_v2(project string, text string) ProjectGitStatusResponse {
	mut resp := ProjectGitStatusResponse{
		ok: true
		project: project
	}
	for line in text.split_into_lines() {
		if line.starts_with('# branch.head ') {
			resp.branch = line.all_after('# branch.head ').trim_space()
			if resp.branch.starts_with('(detached') {
				resp.branch = 'detached HEAD'
			}
			continue
		}
		if line.starts_with('? ') {
			resp.untracked << GitFileChange{
				path: line[2..]
				code: '??'
			}
			continue
		}
		if line.starts_with('1 ') || line.starts_with('u ') {
			xy := if line.len > 4 { line[2..4] } else { '' }
			path := rest_after_fields(line, 8)
			if xy.len == 2 && xy[0] != `.` && xy[0] != `?` {
				resp.staged << GitFileChange{
					path: path
					code: xy
				}
			}
			if xy.len == 2 && xy[1] != `.` {
				resp.unstaged << GitFileChange{
					path: path
					code: xy
				}
			}
			continue
		}
		if line.starts_with('2 ') {
			xy := if line.len > 4 { line[2..4] } else { '' }
			rest := rest_after_fields(line, 9)
			path := rest.all_before('\t')
			if xy.len == 2 && xy[0] != `.` && xy[0] != `?` {
				resp.staged << GitFileChange{
					path: path
					code: xy
				}
			}
			if xy.len == 2 && xy[1] != `.` {
				resp.unstaged << GitFileChange{
					path: path
					code: xy
				}
			}
			continue
		}
	}
	return resp
}

// project_git_status_typed reads the working-tree state of the project
// repository rooted at root (already resolved + validated by the caller).
pub fn project_git_status_typed(root string, project string) ProjectGitStatusResponse {
	res := git_run(root, ['status', '--porcelain=v2', '--branch']) or {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: err.msg()
		}
	}
	if res.exit_code != 0 {
		return git_fail(project, res)
	}
	return parse_git_status_v2(project, res.stdout)
}

// project_git_diff_typed returns the unified diff for one file, staged
// (index vs HEAD) or unstaged (working tree vs index).
pub fn project_git_diff_typed(root string, project string, path string, staged bool) ProjectGitDiffResponse {
	if !valid_repo_relative_path(path) {
		return ProjectGitDiffResponse{
			ok: false
			project: project
			path: path
			staged: staged
			detail: 'invalid repository-relative path'
		}
	}
	mut args := ['diff', '--no-color']
	if staged {
		args << '--cached'
	}
	args << '--'
	args << path
	res := git_run(root, args) or {
		return ProjectGitDiffResponse{
			ok: false
			project: project
			path: path
			staged: staged
			detail: err.msg()
		}
	}
	if res.exit_code != 0 {
		msg := res.stderr.trim_space()
		return ProjectGitDiffResponse{
			ok: false
			project: project
			path: path
			staged: staged
			detail: if msg.len > 0 { msg } else { 'git diff exited with code ${res.exit_code}' }
		}
	}
	mut diff := res.stdout
	mut truncated := false
	if diff.len > max_git_diff_chars {
		diff = diff[..max_git_diff_chars]
		truncated = true
	}
	return ProjectGitDiffResponse{
		ok: true
		project: project
		path: path
		staged: staged
		diff: diff
		truncated: truncated
	}
}

// valid_repo_relative_path accepts only paths that stay inside the
// repository: relative, no parent traversal, no control characters.
pub fn valid_repo_relative_path(path string) bool {
	if path.len == 0 || path.starts_with('/') || path.contains('\x00') || path.contains('\n')
		|| path.contains('\r') {
		return false
	}
	for segment in path.split('/') {
		if segment == '..' {
			return false
		}
	}
	return true
}

fn validate_git_paths(paths []string) ![]string {
	if paths.len == 0 {
		return error('no paths selected')
	}
	if paths.len > max_git_paths {
		return error('too many paths selected (max ${max_git_paths})')
	}
	for path in paths {
		if !valid_repo_relative_path(path) {
			return error('invalid repository-relative path: ${path}')
		}
	}
	return paths
}

// project_git_stage_typed stages the given files (git add).
pub fn project_git_stage_typed(root string, project string, paths []string) ProjectGitStatusResponse {
	checked := validate_git_paths(paths) or {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: err.msg()
		}
	}
	mut args := ['add', '--']
	args << checked
	res := git_run(root, args) or {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: err.msg()
		}
	}
	if res.exit_code != 0 {
		return git_fail(project, res)
	}
	return project_git_status_typed(root, project)
}

// project_git_unstage_typed removes the given files from the index
// (git restore --staged); working-tree contents are untouched.
pub fn project_git_unstage_typed(root string, project string, paths []string) ProjectGitStatusResponse {
	checked := validate_git_paths(paths) or {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: err.msg()
		}
	}
	mut args := ['restore', '--staged', '--']
	args << checked
	res := git_run(root, args) or {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: err.msg()
		}
	}
	if res.exit_code != 0 {
		return git_fail(project, res)
	}
	return project_git_status_typed(root, project)
}

// project_git_commit_typed commits the staged index with the given
// message. An empty index or empty message fails with git's own words.
pub fn project_git_commit_typed(root string, project string, message string) ProjectGitStatusResponse {
	trimmed := message.trim_space()
	if trimmed.len == 0 {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: 'a commit message is required'
		}
	}
	if trimmed.len > 1000 {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: 'commit message is too long (max 1000 characters)'
		}
	}
	res := git_run(root, ['commit', '-m', trimmed]) or {
		return ProjectGitStatusResponse{
			ok: false
			project: project
			detail: err.msg()
		}
	}
	if res.exit_code != 0 {
		return git_fail(project, res)
	}
	mut status := project_git_status_typed(root, project)
	if status.ok {
		status.detail = res.stdout.trim_space()
	}
	return status
}
