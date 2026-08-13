module agent_toolkit_core

import os
import time

// ProjectOptions configures the project command family (#522).
pub struct ProjectOptions {
pub:
	subcommand     string
	workspace_path string
	arg            string // owner/repo, path, or name
	ssh            bool
	json_out       bool
}

// ProjectReport is the domain result for project subcommands.
pub struct ProjectReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

// run_project implements init/clone/list/add/remove/scan (Python cli/project.py).
pub fn run_project(opts ProjectOptions) ProjectReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return ProjectReport{
			ok:      true
			message: project_help_text()
			data:    {
				'subcommand': 'help'
			}
		}
	}
	ws := find_workspace_root(opts.workspace_path) or {
		return ProjectReport{
			ok:      false
			message: workspace_missing
			data:    {
				'subcommand': sub
			}
		}
	}
	return match sub {
		'init' {
			project_init(ws)
		}
		'clone' {
			project_clone(ws, opts)
		}
		'list' {
			project_list(ws)
		}
		'add' {
			project_add(ws, opts)
		}
		'remove' {
			project_remove(ws, opts)
		}
		'scan' {
			project_scan(ws)
		}
		else {
			ProjectReport{
				ok:      false
				message: "Unknown project subcommand: ${sub}\nRun 'agent-toolkit project --help' for usage."
			}
		}
	}
}

// project_result maps ProjectReport to CommandResult.
pub fn project_result(report ProjectReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'project'
		ok:      report.ok
		message: report.message
		data:    data
	}
}

// project_help_text matches Python cli/project.py module docstring.
pub fn project_help_text() string {
	return 'project — Project clone and symlink management.

Usage:
    agent-toolkit project <subcommand> [args]

Subcommands:
    init [--workspace PATH]               Create repos/ and projects/ scaffolding
    clone owner/repo [--ssh] [--workspace PATH]   Clone a GitHub repo and create a symlink
    list [--workspace PATH]               List all symlinked projects
    add <path> [--workspace PATH]         Symlink an already-cloned repo
    remove <name> [--workspace PATH]      Remove symlink (keeps the actual repo)
    scan [--workspace PATH]               Check project/repo consistency

Structure:
    <workspace>/repos/github.com/<owner>/<repo>/   (gitignored)
    <workspace>/projects/<repo> -> ../repos/...    (gitignored)

Options:
    --help    Show this help message
'
}

// project_clone_argv builds git/gh argv (never a shell string). HTTPS unless --ssh;
// `gh repo clone` when gh is on PATH (Python parity).
pub fn project_clone_argv(owner string, repo string, dest string, use_ssh bool, have_gh bool) []string {
	if use_ssh {
		return ['git', 'clone', 'git@github.com:${owner}/${repo}.git', dest]
	}
	if have_gh {
		return ['gh', 'repo', 'clone', '${owner}/${repo}', dest]
	}
	return ['git', 'clone', 'https://github.com/${owner}/${repo}.git', dest]
}

// gh_on_path reports whether `gh` is resolvable without a shell.
pub fn gh_on_path() bool {
	os.find_abs_path_of_executable('gh') or { return false }
	return true
}

fn project_init(ws string) ProjectReport {
	repos := os.join_path(ws, 'repos', 'github.com')
	projects := os.join_path(ws, 'projects')
	os.mkdir_all(repos) or {
		return ProjectReport{
			ok:      false
			message: 'mkdir failed: ${err}'
		}
	}
	os.mkdir_all(projects) or {
		return ProjectReport{
			ok:      false
			message: 'mkdir failed: ${err}'
		}
	}
	gitignore_append(ws, ['repos/', 'projects/'])
	mut lines := []string{}
	lines << 'Initialized project directories'
	lines << '  ${repos}'
	lines << '  ${projects}'
	return ProjectReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'init'
			'workspace':  ws
		}
	}
}

fn project_clone(ws string, opts ProjectOptions) ProjectReport {
	slug := opts.arg
	if slug.len == 0 {
		return ProjectReport{
			ok:      false
			message: 'Usage: agent-toolkit project clone owner/repo [--ssh] [--workspace PATH]'
		}
	}
	if !slug.contains('/') {
		return ProjectReport{
			ok:      false
			message: 'Error: expected owner/repo, got: ${slug}'
		}
	}
	owner := slug.all_before('/')
	repo_name := slug.all_after('/')
	repos_dir := os.join_path(ws, 'repos', 'github.com', owner)
	target_dir := os.join_path(repos_dir, repo_name)
	projects_dir := os.join_path(ws, 'projects')
	link_path := os.join_path(projects_dir, repo_name)
	mut lines := []string{}
	if os.is_dir(target_dir) {
		lines << 'Already cloned: ${target_dir}'
	} else {
		os.mkdir_all(repos_dir) or {
			return ProjectReport{
				ok:      false
				message: 'mkdir failed: ${err}'
			}
		}
		mut argv := project_clone_argv(owner, repo_name, target_dir, opts.ssh, gh_on_path())
		mut verb := 'git clone'
		if opts.ssh {
			verb = 'git clone (ssh)'
		} else if argv[0] == 'gh' {
			verb = 'gh repo clone'
		}
		lines << 'Cloning ${owner}/${repo_name} via ${verb} ...'
		ps := new_process_service()
		res := ps.run(
			argv:    argv
			timeout: 10 * time.minute
		) or {
			return ProjectReport{
				ok:      false
				message: 'Error: clone failed: ${err}'
			}
		}
		if res.exit_code != 0 {
			return ProjectReport{
				ok:      false
				message: 'Error: clone failed (exit ${res.exit_code})\n${res.stderr}'
			}
		}
		lines << 'Cloned to ${target_dir}'
	}
	os.mkdir_all(projects_dir) or {}
	if os.is_link(link_path) {
		os.rm(link_path) or {}
	}
	os.symlink(target_dir, link_path) or {
		return ProjectReport{
			ok:      false
			message: 'symlink failed: ${err}'
		}
	}
	lines << 'Symlink: projects/${repo_name} -> ${target_dir}'
	upsert_project(ws, repo_name, target_dir, 'github.com/${owner}/${repo_name}')
	lines << 'Updated projects.yaml'
	return ProjectReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'clone'
			'workspace':  ws
			'name':       repo_name
		}
	}
}

fn project_list(ws string) ProjectReport {
	projects_dir := os.join_path(ws, 'projects')
	mut lines := []string{}
	lines << ''
	lines << '=== Projects ==='
	lines << ''
	if !os.is_dir(projects_dir) {
		lines << '  (projects/ directory not found)'
		lines << ''
		return ProjectReport{
			ok:      true
			message: lines.join('\n')
			data:    {
				'subcommand': 'list'
				'workspace':  ws
				'count':      '0'
			}
		}
	}
	entries := os.ls(projects_dir) or { []string{} }
	mut names := entries.clone()
	names.sort()
	mut n := 0
	for name in names {
		p := os.join_path(projects_dir, name)
		if !os.is_link(p) {
			continue
		}
		target := os.readlink(p) or { '' }
		status := if symlink_target_exists(p, target) { 'ok' } else { 'broken' }
		lines << '  [${status}]  ${name} -> ${target}'
		n++
	}
	if n == 0 {
		lines << '  (no projects — run: agent-toolkit project clone owner/repo)'
	}
	lines << ''
	return ProjectReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'list'
			'workspace':  ws
			'count':      '${n}'
		}
	}
}

fn project_add(ws string, opts ProjectOptions) ProjectReport {
	if opts.arg.len == 0 {
		return ProjectReport{
			ok:      false
			message: 'Usage: agent-toolkit project add <path> [--workspace PATH]'
		}
	}
	repo_path := os.real_path(os.expand_tilde_to_home(opts.arg))
	if !os.is_dir(repo_path) {
		return ProjectReport{
			ok:      false
			message: 'Error: not a directory: ${repo_path}'
		}
	}
	repo_name := os.file_name(repo_path)
	projects_dir := os.join_path(ws, 'projects')
	link_path := os.join_path(projects_dir, repo_name)
	os.mkdir_all(projects_dir) or {}
	mut lines := []string{}
	if os.is_link(link_path) {
		existing := os.readlink(link_path) or { '' }
		lines << 'Replacing existing symlink: ${existing}'
		os.rm(link_path) or {}
	}
	os.symlink(repo_path, link_path) or {
		return ProjectReport{
			ok:      false
			message: 'symlink failed: ${err}'
		}
	}
	lines << 'Symlink: projects/${repo_name} -> ${repo_path}'
	upsert_project(ws, repo_name, repo_path, '')
	lines << 'Updated projects.yaml'
	return ProjectReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'add'
			'workspace':  ws
			'name':       repo_name
		}
	}
}

fn project_remove(ws string, opts ProjectOptions) ProjectReport {
	if opts.arg.len == 0 {
		return ProjectReport{
			ok:      false
			message: 'Usage: agent-toolkit project remove <name> [--workspace PATH]'
		}
	}
	name := opts.arg
	link_path := os.join_path(ws, 'projects', name)
	if !os.is_link(link_path) {
		return ProjectReport{
			ok:      false
			message: "Error: no symlink found for '${name}' in projects/"
		}
	}
	os.rm(link_path) or {
		return ProjectReport{
			ok:      false
			message: 'remove failed: ${err}'
		}
	}
	return ProjectReport{
		ok:      true
		message: 'Removed: projects/${name}\n(actual repo was not deleted)'
		data:    {
			'subcommand': 'remove'
			'workspace':  ws
			'name':       name
		}
	}
}

fn project_scan(ws string) ProjectReport {
	projects_dir := os.join_path(ws, 'projects')
	repos_dir := os.join_path(ws, 'repos')
	mut lines := []string{}
	lines << ''
	lines << '=== Project Scan ==='
	lines << ''
	lines << 'Symlinks in projects/:'
	mut ok_links := map[string]bool{}
	mut broken := []string{}
	if os.is_dir(projects_dir) {
		entries := os.ls(projects_dir) or { []string{} }
		mut names := entries.clone()
		names.sort()
		for name in names {
			p := os.join_path(projects_dir, name)
			if !os.is_link(p) {
				continue
			}
			if symlink_target_exists(p, os.readlink(p) or { '' }) {
				lines << '  ok      ${name}'
				ok_links[name] = true
			} else {
				target := os.readlink(p) or { '' }
				lines << '  broken  ${name} -> ${target}'
				broken << name
			}
		}
	} else {
		lines << '  (projects/ directory not found)'
	}
	lines << ''
	lines << 'Repos in repos/ (symlink status):'
	mut unlinked := []string{}
	if os.is_dir(repos_dir) {
		hosts := os.ls(repos_dir) or { []string{} }
		for host in hosts {
			host_dir := os.join_path(repos_dir, host)
			if !os.is_dir(host_dir) {
				continue
			}
			owners := os.ls(host_dir) or { []string{} }
			for owner in owners {
				owner_dir := os.join_path(host_dir, owner)
				if !os.is_dir(owner_dir) {
					continue
				}
				repos := os.ls(owner_dir) or { []string{} }
				for repo in repos {
					repo_dir := os.join_path(owner_dir, repo)
					if !os.is_dir(repo_dir) {
						continue
					}
					rel := '${host}/${owner}/${repo}'
					if repo in ok_links {
						lines << '  linked    ${rel}'
					} else {
						lines << '  no link   ${rel}'
						unlinked << repo_dir
					}
				}
			}
		}
	} else {
		lines << '  (repos/ directory not found)'
	}
	lines << ''
	lines << '── Summary ──'
	lines << '  Linked:    ${ok_links.len}'
	lines << '  Broken:    ${broken.len}'
	lines << '  Unlinked:  ${unlinked.len}'
	if broken.len > 0 {
		lines << ''
		lines << "  Run 'agent-toolkit project remove <name>' to clean up broken links."
	}
	if unlinked.len > 0 {
		lines << ''
		lines << "  Run 'agent-toolkit project add <path>' to link unlinked repos."
	}
	lines << ''
	return ProjectReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'scan'
			'workspace':  ws
			'linked':     '${ok_links.len}'
			'broken':     '${broken.len}'
			'unlinked':   '${unlinked.len}'
		}
	}
}

struct ProjectYamlEntry {
	name      string
	path      string
	source    string
	cloned_at string
}

fn load_projects_yaml(ws string) []ProjectYamlEntry {
	path := os.join_path(ws, 'projects.yaml')
	if !os.is_file(path) {
		return []
	}
	text := os.read_file(path) or { return [] }
	mut projects := []ProjectYamlEntry{}
	mut current := ProjectYamlEntry{}
	mut has := false
	for line in text.split_into_lines() {
		stripped := line.trim_space()
		if stripped.starts_with('- name:') {
			if has {
				projects << current
			}
			current = ProjectYamlEntry{
				name: stripped.all_after('- name:').trim_space()
			}
			has = true
		} else if has {
			if stripped.starts_with('path:') {
				current = ProjectYamlEntry{
					...current
					path: stripped.all_after('path:').trim_space()
				}
			} else if stripped.starts_with('source:') {
				current = ProjectYamlEntry{
					...current
					source: stripped.all_after('source:').trim_space()
				}
			} else if stripped.starts_with('cloned_at:') {
				current = ProjectYamlEntry{
					...current
					cloned_at: stripped.all_after('cloned_at:').trim_space()
				}
			}
		}
	}
	if has {
		projects << current
	}
	return projects
}

fn save_projects_yaml(ws string, projects []ProjectYamlEntry) {
	mut lines := []string{}
	lines << 'projects:'
	for e in projects {
		lines << '  - name: ${e.name}'
		if e.path.len > 0 {
			lines << '    path: ${e.path}'
		}
		if e.source.len > 0 {
			lines << '    source: ${e.source}'
		}
		if e.cloned_at.len > 0 {
			lines << '    cloned_at: ${e.cloned_at}'
		}
	}
	os.write_file(os.join_path(ws, 'projects.yaml'), lines.join('\n') + '\n') or {}
}

fn upsert_project(ws string, name string, path string, source string) {
	mut projects := load_projects_yaml(ws)
	mut found := false
	for i, e in projects {
		if e.name == name {
			projects[i] = ProjectYamlEntry{
				...e
				path:   path
				source: if source.len > 0 { source } else { e.source }
			}
			found = true
			break
		}
	}
	if !found {
		projects << ProjectYamlEntry{
			name:      name
			path:      path
			source:    source
			cloned_at: time.utc().format_rfc3339()[..10]
		}
	}
	save_projects_yaml(ws, projects)
}

fn symlink_target_exists(link string, target string) bool {
	if target.len == 0 {
		return false
	}
	if os.is_abs_path(target) {
		return os.exists(target)
	}
	return os.exists(os.join_path(os.dir(link), target))
}

fn gitignore_append(ws string, entries []string) {
	gi := os.join_path(ws, '.gitignore')
	existing := if os.is_file(gi) { os.read_file(gi) or { '' } } else { '' }
	mut lines := existing.split_into_lines()
	mut changed := !os.exists(gi)
	for entry in entries {
		if entry !in lines {
			lines << entry
			changed = true
		}
	}
	if changed {
		mut text := lines.join('\n')
		if text.len > 0 && !text.ends_with('\n') {
			text += '\n'
		}
		os.write_file(gi, text) or {}
	}
}
