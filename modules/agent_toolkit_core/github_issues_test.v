module agent_toolkit_core

import os

fn test_parse_github_issues_json_maps_fields() {
	text := '[{"number":42,"title":"Fix the thing","url":"https://github.com/o/r/issues/42","state":"OPEN","labels":[{"name":"bug"},{"name":"p1"}],"author":{"login":"octocat"}},{"number":7,"title":"Docs","url":"https://github.com/o/r/issues/7","state":"OPEN","labels":[],"author":{"login":"hubot"}}]'
	issues := parse_github_issues_json(text) or { panic(err.msg()) }
	assert issues.len == 2
	assert issues[0].number == 42
	assert issues[0].title == 'Fix the thing'
	assert issues[0].labels == ['bug', 'p1']
	assert issues[0].author == 'octocat'
	assert issues[1].labels.len == 0
}

fn test_parse_github_issues_json_rejects_garbage() {
	if _ := parse_github_issues_json('not json') {
		assert false, 'expected parse error'
	}
}

fn test_list_project_issues_requires_path() {
	res := list_project_issues_typed('', 0)
	assert !res.ok
	assert res.detail.contains('required')
}

fn test_list_project_issues_reports_non_repo() {
	dir := os.join_path(os.temp_dir(), 'at-issues-nonrepo-${os.getpid()}')
	os.mkdir_all(dir) or { panic(err) }
	defer { os.rmdir_all(dir) or {} }
	res := list_project_issues_typed(dir, 5)
	assert !res.ok
	assert res.detail.len > 0
	assert res.issues.len == 0
}
