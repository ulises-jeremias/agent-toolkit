module agent_toolkit_core

import time
import x.json2

// github_issues.v — read-only GitHub issue listing for the Desktop issue
// picker (Slice 6, pack E). The engine shells out to the user's authenticated
// `gh` CLI (argv only, no shell) inside the project checkout. Failures are
// reported as ok=false with a human-readable detail — never as fake data.

pub struct GithubIssueView {
pub:
	number int
	title  string
	url    string
	state  string
	labels []string
	author string
}

pub struct ProjectIssuesResponse {
pub:
	ok     bool
	repo   string
	issues []GithubIssueView
	detail string
}

pub struct GhIssueLabel {
pub:
	name string
}

pub struct GhIssueAuthor {
pub:
	login string
}

pub struct GhIssue {
pub:
	number int
	title  string
	url    string
	state  string
	labels []GhIssueLabel
	author GhIssueAuthor
}

// parse_github_issues_json decodes `gh issue list --json ...` output.
fn parse_github_issues_json(text string) ![]GithubIssueView {
	raw := json2.decode[[]GhIssue](text) or { return error('could not parse gh issue list output') }
	return raw.map(GithubIssueView{
		number: it.number
		title: it.title
		url: it.url
		state: it.state
		labels: it.labels.map(it.name)
		author: it.author.login
	})
}

// list_project_issues_typed lists open issues for the GitHub repo checked out
// at project_path. limit is clamped to 1..100 (default 30).
pub fn list_project_issues_typed(project_path string, limit int) ProjectIssuesResponse {
	fail := fn (detail string) ProjectIssuesResponse {
		return ProjectIssuesResponse{
			ok: false
			issues: []GithubIssueView{}
			detail: detail
		}
	}
	if project_path.len == 0 {
		return fail('project path is required')
	}
	effective_limit := if limit <= 0 { 30 } else if limit > 100 { 100 } else { limit }
	ps := new_process_service()
	repo_res := ps.run(RunOptions{
		argv: ['gh', 'repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner']
		cwd: project_path
		timeout: 15 * time.second
	}) or { return fail('GitHub CLI (gh) is not available: ${err.msg()}') }
	if repo_res.exit_code != 0 {
		return fail('could not resolve a GitHub repository here: ${repo_res.stderr.trim_space()}')
	}
	repo := repo_res.stdout.trim_space()
	list_res := ps.run(RunOptions{
		argv: ['gh', 'issue', 'list', '--state', 'open', '--limit', effective_limit.str(), '--json',
			'number,title,url,state,labels,author']
		cwd: project_path
		timeout: 30 * time.second
	}) or { return fail('GitHub CLI (gh) is not available: ${err.msg()}') }
	if list_res.exit_code != 0 {
		return fail('gh issue list failed: ${list_res.stderr.trim_space()}')
	}
	issues := parse_github_issues_json(list_res.stdout) or { return fail(err.msg()) }
	return ProjectIssuesResponse{
		ok: true
		repo: repo
		issues: issues
	}
}
