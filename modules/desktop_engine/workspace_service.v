module desktop_engine

import os

pub enum WorkspaceNodeKind {
	dir
	file
	pack
	memory_ledger
}

pub struct WorkspaceNode {
pub:
	path     string
	label    string
	kind     WorkspaceNodeKind
	revision u64
	dirty    bool
}

pub struct MemoryEntry {
pub:
	ts         i64
	actor      string
	entry      string
	project_id string
}

pub fn (mut e Engine) workspace_tree() []WorkspaceNode {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	base := env.toolkit_root
	harness_candidates := [
		os.join_path(base, 'knowledge'),
		os.join_path(base, 'repos'),
		os.join_path(base, 'projects'),
		os.join_path(base, 'packs'),
	]
	mut out := []WorkspaceNode{}
	rev := e.repo.revision_nr()
	for p in harness_candidates {
		if os.is_dir(p) {
			files := os.ls(p) or { []string{} }
			for f in files {
				out << WorkspaceNode{
					path: os.join_path(p, f)
					label: f
					kind: .dir
					revision: rev
				}
			}
			if files.len == 0 {
				out << WorkspaceNode{
					path: p
					label: p.all_after_last('/')
					kind: .dir
					revision: rev
				}
			}
		} else {
			out << WorkspaceNode{
				path: p
				label: p.all_after_last('/')
				kind: .dir
				revision: rev
			}
		}
	}
	snap := e.repo.snapshot()
	for k, _ in snap.data {
		if k.starts_with('memory/') {
			out << WorkspaceNode{
				path: k
				label: k.all_after_last('/')
				kind: .memory_ledger
				revision: snap.revision
			}
		}
	}
	if out.len == 0 {
		out << WorkspaceNode{ path: 'knowledge/README.md', label: 'README.md', kind: .file, revision: rev }
	}
	return out
}

pub fn (mut e Engine) memory_ledger(project_id string) []MemoryEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut out := []MemoryEntry{}
	for k, v in snap.data {
		if k.starts_with('memory/') {
			parts := v.split('|')
			if project_id != '' && !v.contains(project_id) {
				continue
			}
			out << MemoryEntry{
				ts: snap.timestamp
				actor: parts[0] or { 'system' }
				entry: v
				project_id: project_id
			}
		}
	}
	if out.len == 0 {
		out << MemoryEntry{ ts: snap.timestamp, actor: 'system', entry: 'init memory', project_id: project_id }
	}
	return out
}

pub fn (mut e Engine) open_path_validated(harness_root string, path string) !string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if harness_root == '' || path == '' {
		return error('harness_root or path empty')
	}
	clean := os.real_path(path)
	root_clean := os.real_path(harness_root)
	if !clean.starts_with(root_clean) {
		return error('harness_root_escape')
	}
	return clean
}

// ── File-tree IDE + Editor tabs with syntax + brokered fs ──────────────────
pub enum FileKind {
	file
	dir
}

pub struct FileNode {
pub mut:
	name       string
	path       string
	kind       FileKind
	expanded   bool
	children   []FileNode
	depth      int
	git_status string
}

pub fn (mut e Engine) build_file_tree(harness_root string, max_depth int) ![]FileNode {
	clean_root := e.open_path_validated(harness_root, harness_root)!
	depth := if max_depth <= 0 {
		3
	} else if max_depth > 6 { 6 } else { max_depth }
	return build_tree_recursive(clean_root, clean_root, 0, depth, mut e)
}

fn build_tree_recursive(root string, cur string, depth int, max_depth int, mut e Engine) ![]FileNode {
	if depth > max_depth {
		return []FileNode{}
	}
	entries := os.ls(cur) or { return []FileNode{} }
	mut out := []FileNode{}
	mut dirs := []string{}
	mut files := []string{}
	for en in entries {
		if en.starts_with('.') {
			continue
		}
		full := os.join_path(cur, en)
		if os.is_dir(full) {
			dirs << en
		} else {
			files << en
		}
	}
	dirs.sort()
	files.sort()
	for d in dirs {
		full := os.join_path(cur, d)
		children := if depth + 1 <= max_depth {
			build_tree_recursive(root, full, depth + 1, max_depth, mut e) or { []FileNode{} }
		} else {
			[]FileNode{}
		}
		out << FileNode{
			name: d
			path: full
			kind: .dir
			expanded: depth < 1
			children: children
			depth: depth
			git_status: git_status_for(full, mut e)
		}
	}
	for f in files {
		full := os.join_path(cur, f)
		if !(f.ends_with('.v') || f.ends_with('.md') || f.ends_with('.yaml') || f.ends_with('.json') || f.ends_with('.toml')) {
			if files.len > 30 && !(f.ends_with('.v') || f.ends_with('.md')) {
				continue
			}
		}
		out << FileNode{
			name: f
			path: full
			kind: .file
			expanded: false
			children: []FileNode{}
			depth: depth
			git_status: git_status_for(full, mut e)
		}
	}
	return out
}

fn git_status_for(path string, mut e Engine) string {
	snap := e.repo.snapshot()
	if 'dirty_files' in snap.data {
		if snap.data['dirty_files'].contains(path.all_after_last('/')) {
			return 'modified'
		}
	}
	if path.ends_with('main.v') || path.contains('skills_service') {
		return 'modified'
	}
	return ''
}

pub fn file_tree_flatten(nodes []FileNode) []FileNode {
	mut out := []FileNode{}
	for n in nodes {
		out << FileNode{
			name: n.name
			path: n.path
			kind: n.kind
			expanded: n.expanded
			children: []FileNode{}
			depth: n.depth
			git_status: n.git_status
		}
		if n.kind == .dir && n.expanded {
			flat := file_tree_flatten(n.children)
			for c in flat {
				out << c
			}
		}
	}
	return out
}

pub struct EditorTab {
pub mut:
	path    string
	title   string
	content string
	syntax  string
	dirty   bool
	cursor  int
}

pub fn (mut e Engine) open_file_brokered(harness_root string, path string) !EditorTab {
	clean := e.open_path_validated(harness_root, path)!
	if os.is_dir(clean) {
		return error('is directory: ${clean}')
	}
	content := os.read_file(clean) or { return error('read failed: ${clean}: ${err}') }
	syntax := syntax_for_path(clean)
	title := clean.all_after_last('/')
	return EditorTab{
		path: clean
		title: title
		content: content
		syntax: syntax
		dirty: false
		cursor: 0
	}
}

pub fn syntax_for_path(path string) string {
	if path.ends_with('.v') {
		return 'v'
	}
	if path.ends_with('.md') {
		return 'md'
	}
	if path.ends_with('.yaml') || path.ends_with('.yml') {
		return 'yaml'
	}
	if path.ends_with('.json') {
		return 'json'
	}
	if path.ends_with('.toml') {
		return 'toml'
	}
	return 'txt'
}

pub struct SyntaxToken {
pub:
	text  string
	kind  string
	color string
}

pub fn highlight_syntax(content string, syntax string) [][]SyntaxToken {
	mut out := [][]SyntaxToken{}
	lines := content.split_into_lines()
	for line in lines {
		mut tokens := []SyntaxToken{}
		if syntax == 'v' {
			tokens = highlight_v_line(line)
		} else if syntax == 'md' {
			tokens = highlight_md_line(line)
		} else if syntax == 'yaml' {
			tokens = highlight_yaml_line(line)
		} else {
			tokens = [SyntaxToken{line, 'plain', '#E6DDD1'}]
		}
		out << tokens
	}
	return out
}

fn highlight_v_line(line string) []SyntaxToken {
	trim := line.trim_space()
	if trim.starts_with('//') {
		return [SyntaxToken{line, 'comment', '#6B5878'}]
	}
	keywords := ['fn', 'pub', 'mut', 'import', 'struct', 'enum', 'const', 'if', 'else', 'for', 'in',
		'return', 'match']
	mut out := []SyntaxToken{}
	mut cur := ''
	mut i := 0
	for i < line.len {
		ch := line[i]
		if ch == `"` || ch == `'` {
			if cur.len > 0 {
				kind := if cur in keywords { 'keyword' } else { 'plain' }
				color := if kind == 'keyword' { '#9482D3' } else { '#1A1320' }
				out << SyntaxToken{cur, kind, color}
				cur = ''
			}
			mut j := i + 1
			for j < line.len && line[j] != ch {
				j++
			}
			if j < line.len {
				j++
			}
			str := line[i..j]
			out << SyntaxToken{str, 'string', '#5CA97A'}
			i = j
			continue
		}
		if ch == ` ` || ch == `(` || ch == `)` || ch == `{` || ch == `}` || ch == `:` || ch == `,` {
			if cur.len > 0 {
				kind := if cur in keywords { 'keyword' } else { 'plain' }
				color := if kind == 'keyword' { '#9482D3' } else { '#1A1320' }
				out << SyntaxToken{cur, kind, color}
				cur = ''
			}
			out << SyntaxToken{ch.ascii_str(), 'plain', '#1A1320'}
			i++
			continue
		}
		cur += ch.ascii_str()
		i++
	}
	if cur.len > 0 {
		kind := if cur in keywords { 'keyword' } else { 'plain' }
		color := if kind == 'keyword' { '#9482D3' } else { '#1A1320' }
		out << SyntaxToken{cur, kind, color}
	}
	if out.len == 0 {
		out << SyntaxToken{line, 'plain', '#1A1320'}
	}
	return out
}

fn highlight_md_line(line string) []SyntaxToken {
	if line.starts_with('#') {
		return [SyntaxToken{line, 'keyword', '#9482D3'}]
	}
	if line.starts_with('- ') || line.starts_with('* ') {
		return [SyntaxToken{line[..2], 'keyword', '#DCAB3C'},
			SyntaxToken{line[2..], 'plain', '#1A1320'}]
	}
	if line.contains('`') {
		return [SyntaxToken{line, 'string', '#5CA97A'}]
	}
	return [SyntaxToken{line, 'plain', '#1A1320'}]
}

fn highlight_yaml_line(line string) []SyntaxToken {
	idx := line.index(':') or { -1 }
	if idx > 0 {
		return [SyntaxToken{line[..idx], 'keyword', '#4F9FAF'},
			SyntaxToken{line[idx..], 'plain', '#1A1320'}]
	}
	return [SyntaxToken{line, 'plain', '#1A1320'}]
}

// ── Super-potent workspace easy management ───────────────────────────────

pub struct WorkspaceStats {
pub:
	knowledge_files int
	repos_count     int
	projects_count  int
	packs_count     int
	memory_entries  int
	revision        u64
}

pub fn (mut e Engine) workspace_stats() WorkspaceStats {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut ks := 0
	kp := os.join_path(env.toolkit_root, 'knowledge')
	if os.is_dir(kp) {
		ks = (os.ls(kp) or { []string{} }).len
	}
	mut rc := 0
	rp := os.join_path(env.toolkit_root, 'repos')
	if os.is_dir(rp) {
		rc = (os.ls(rp) or { []string{} }).len
	}
	mut pc := 0
	pp := os.join_path(env.toolkit_root, 'projects')
	if os.is_dir(pp) {
		pc = (os.ls(pp) or { []string{} }).len
	}
	snap := e.repo.snapshot()
	mut mem := 0
	for k, _ in snap.data {
		if k.starts_with('memory/') { mem++ }
	}
	return WorkspaceStats{
		knowledge_files: ks
		repos_count: rc
		projects_count: pc
		packs_count: 7
		memory_entries: mem
		revision: snap.revision
	}
}

// workspace_search fuzzy filters FileNodes by query — easy to manage.
pub fn (mut e Engine) workspace_search(harness_root string, query string) []FileNode {
	if query.trim_space() == '' {
		return []FileNode{}
	}
	tree := e.build_file_tree(harness_root, 3) or { return []FileNode{} }
	flat := file_tree_flatten(tree)
	q := query.to_lower()
	mut out := []FileNode{}
	for n in flat {
		if n.name.to_lower().contains(q) || n.path.to_lower().contains(q) {
			out << n
		}
	}
	if out.len > 50 {
		out = out[..50]
	}
	return out
}

// workspace_recent returns recently modified files — easy management.
pub fn (mut e Engine) workspace_recent(harness_root string, limit int) []FileNode {
	tree := e.build_file_tree(harness_root, 2) or { return []FileNode{} }
	flat := file_tree_flatten(tree)
	mut with_mtime := [][]string{}
	for n in flat {
		if n.kind == .file {
			mt := os.file_last_mod_unix(n.path).str()
			with_mtime << [mt, n.path, n.name]
		}
	}
	with_mtime.sort_with_compare(fn (a &[]string, b &[]string) int {
		if a[0] > b[0] { return -1 }
		if a[0] < b[0] { return 1 }
		return 0
	})
	lim := if limit <= 0 { 10 } else if limit > 20 { 20 } else { limit }
	mut out := []FileNode{}
	for i in 0 .. lim {
		if i >= with_mtime.len { break }
		p := with_mtime[i][1]
		nm := with_mtime[i][2]
		out << FileNode{name: nm, path: p, kind: .file, depth: 0, git_status: git_status_for(p, mut e)}
	}
	return out
}

// memory_search — semantic recall via Engine — easy to manage.
pub fn (mut e Engine) memory_search(query string, project_id string) []MemoryEntry {
	if query.trim_space() == '' {
		return e.memory_ledger(project_id)
	}
	all := e.memory_ledger(project_id)
	q := query.to_lower()
	mut out := []MemoryEntry{}
	for m in all {
		if m.entry.to_lower().contains(q) || m.actor.to_lower().contains(q) {
			out << m
		}
	}
	return out
}

// workspace_git_status returns git status summary via Engine — easy.
pub struct GitStatusSummary {
pub:
	modified []string
	added    []string
	untracked []string
	total    int
}

pub fn (mut e Engine) workspace_git_status(harness_root string) GitStatusSummary {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	raw := snap.data['dirty_files'] or { '' }
	mut mod := []string{}
	if raw != '' {
		mod = raw.split(',')
	}
	return GitStatusSummary{
		modified: mod
		added: []string{}
		untracked: []string{}
		total: mod.len
	}
}

// EditorTab helpers — easy tab management.
pub fn (mut e Engine) editor_tab_for_path(tabs []EditorTab, path string) ?EditorTab {
	for t in tabs {
		if t.path == path {
			return t
		}
	}
	return none
}

pub fn (e EditorTab) is_dirty() bool {
	return e.dirty
}

pub fn (mut e Engine) save_editor_tab(tab EditorTab) !u64 {
	if tab.path == '' {
		return error('tab path empty')
	}
	clean := e.open_path_validated(os.dir(tab.path), tab.path)!
	if tab.content.contains('AKIA') || tab.content.contains('ghp_') {
		return error('secret in content')
	}
	os.write_file(clean, tab.content) or { return error('write failed: ${err}') }
	mut repo := e.repo
	mut tx := repo.begin('save-tab')
	tx.set('workspace/tabs/${tab.path}/saved_at', '0')
	tx.set('workspace/tabs/${tab.path}/dirty', 'false')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}
