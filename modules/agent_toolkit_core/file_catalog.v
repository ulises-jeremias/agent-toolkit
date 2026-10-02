module agent_toolkit_core

import os

const file_body_limit = 262144
const file_tree_max_depth = 6
const file_tree_default_depth = 3
const file_tree_max_nodes = 500
const file_search_max_hits = 50

pub struct WorkspaceFileNode {
pub:
	name   string
	path   string
	kind   string
	size   int
	depth  int
	masked bool
}

pub struct WorkspaceFileListResponse {
pub:
	ok    bool
	root  string
	nodes []WorkspaceFileNode
}

pub struct WorkspaceFileReadResponse {
pub:
	ok        bool
	path      string
	name      string
	content   string
	size      int
	binary    bool
	truncated bool
	masked    bool
}

pub struct WorkspaceFileHit {
pub:
	path    string
	line    int
	snippet string
}

pub struct WorkspaceFileSearchResponse {
pub:
	ok    bool
	query string
	hits  []WorkspaceFileHit
}

pub struct WorkspaceFileWriteResponse {
pub:
	ok      bool
	message string
	path    string
}

pub fn list_workspace_files(workspace string, rel_path string, max_depth int) !WorkspaceFileListResponse {
	ws := require_files_workspace(workspace)!
	return list_files_from_root(ws, rel_path, max_depth)
}

pub fn list_project_files(workspace string, project string, rel_path string, max_depth int) !WorkspaceFileListResponse {
	root := resolve_project_files_root(workspace, project)!
	return list_files_from_root(root, rel_path, max_depth)
}

fn list_files_from_root(root string, rel_path string, max_depth int) !WorkspaceFileListResponse {
	start := resolve_workspace_dir(root, rel_path)!
	depth := clamp_tree_depth(max_depth)
	mut nodes := []WorkspaceFileNode{}
	walk_workspace_tree(root, start, 0, depth, mut nodes)
	return WorkspaceFileListResponse{
		ok: true
		root: pack_rel_or_dot(root, start)
		nodes: nodes
	}
}

pub fn read_workspace_file(workspace string, rel_path string) !WorkspaceFileReadResponse {
	ws := require_files_workspace(workspace)!
	return read_file_from_root(ws, rel_path)
}

pub fn read_project_file(workspace string, project string, rel_path string) !WorkspaceFileReadResponse {
	root := resolve_project_files_root(workspace, project)!
	return read_file_from_root(root, rel_path)
}

fn read_file_from_root(root string, rel_path string) !WorkspaceFileReadResponse {
	abs := resolve_workspace_file(root, rel_path)!
	rel := pack_rel_path(root, abs)
	name := os.file_name(rel)
	size := int(os.file_size(abs))
	if is_secret_file_name(name) {
		return WorkspaceFileReadResponse{
			ok: true
			path: rel
			name: name
			content: ''
			size: size
			binary: false
			truncated: false
			masked: true
		}
	}
	raw := os.read_file(abs) or { return error('file not found') }
	if file_bytes_are_binary(raw) {
		return WorkspaceFileReadResponse{
			ok: true
			path: rel
			name: name
			content: ''
			size: size
			binary: true
			truncated: false
			masked: false
		}
	}
	if raw.len > file_body_limit {
		return WorkspaceFileReadResponse{
			ok: true
			path: rel
			name: name
			content: raw[..file_body_limit]
			size: size
			binary: false
			truncated: true
			masked: false
		}
	}
	return WorkspaceFileReadResponse{
		ok: true
		path: rel
		name: name
		content: raw
		size: size
		binary: false
		truncated: false
		masked: false
	}
}

pub fn search_workspace_files(workspace string, query string) !WorkspaceFileSearchResponse {
	ws := require_files_workspace(workspace)!
	return search_files_from_root(ws, query)
}

pub fn search_project_files(workspace string, project string, query string) !WorkspaceFileSearchResponse {
	root := resolve_project_files_root(workspace, project)!
	return search_files_from_root(root, query)
}

fn search_files_from_root(root string, query string) !WorkspaceFileSearchResponse {
	q := query.trim_space()
	if q.len == 0 {
		return error('query is required')
	}
	low := q.to_lower()
	mut hits := []WorkspaceFileHit{}
	mut nodes := []WorkspaceFileNode{}
	walk_workspace_tree(root, root, 0, file_tree_default_depth, mut nodes)
	for n in nodes {
		if n.kind != 'file' || n.masked {
			continue
		}
		if n.name.to_lower().contains(low) || n.path.to_lower().contains(low) {
			hits << WorkspaceFileHit{
				path: n.path
				line: 0
				snippet: n.name
			}
			if hits.len >= file_search_max_hits {
				break
			}
			continue
		}
		abs := os.join_path(root, n.path)
		text := os.read_file(abs) or { continue }
		if file_bytes_are_binary(text) {
			continue
		}
		for i, line in text.split_into_lines() {
			if line.to_lower().contains(low) {
				hits << WorkspaceFileHit{
					path: n.path
					line: i + 1
					snippet: clip(line.trim_space(), 160)
				}
				if hits.len >= file_search_max_hits {
					break
				}
			}
		}
		if hits.len >= file_search_max_hits {
			break
		}
	}
	return WorkspaceFileSearchResponse{
		ok: true
		query: q
		hits: hits
	}
}

pub fn write_workspace_file(workspace string, rel_path string, body string) !WorkspaceFileWriteResponse {
	ws := require_files_workspace(workspace)!
	if body.len > file_body_limit {
		return error('content too large')
	}
	if body.contains('\x00') {
		return error('binary content not allowed')
	}
	abs := resolve_workspace_write_path(ws, rel_path)!
	name := os.file_name(abs)
	if is_secret_file_name(name) && (body.contains('AKIA') || body.contains('ghp_')) {
		return error('secret in content')
	}
	os.mkdir_all(os.dir(abs)) or { return error('write failed: ${err}') }
	tmp := abs + '.tmp'
	os.write_file(tmp, body) or {
		os.rm(tmp) or {}
		return error('write failed: ${err}')
	}
	os.mv(tmp, abs) or {
		os.rm(tmp) or {}
		return error('write failed: ${err}')
	}
	rel := pack_rel_path(ws, abs)
	return WorkspaceFileWriteResponse{
		ok: true
		message: 'updated ${rel}'
		path: rel
	}
}

fn require_files_workspace(workspace string) !string {
	ws := find_workspace_root(workspace) or { return error('workspace not found') }
	return os.real_path(ws)
}

fn resolve_project_files_root(workspace string, project string) !string {
	ws := require_files_workspace(workspace)!
	name := project.trim_space()
	if name.len == 0 || name in ['.', '..'] || name.contains('/') || name.contains('\\') || name.contains('\x00')
		|| name.contains('%') {
		return error('invalid project')
	}
	link := os.join_path(ws, 'projects', name)
	if !os.is_link(link) {
		return error('project not found')
	}
	root := os.real_path(link)
	if root.len == 0 || !os.is_dir(root) {
		return error('project not found')
	}
	return root
}

fn resolve_workspace_dir(ws string, rel_path string) !string {
	rel := normalize_rel(rel_path) or { return err }
	if rel.len == 0 {
		return ws
	}
	joined := os.join_path(ws, rel)
	real := os.real_path(joined)
	contain_in_workspace(ws, real)!
	if !os.is_dir(real) {
		return error('not a directory')
	}
	return real
}

fn resolve_workspace_file(ws string, rel_path string) !string {
	rel := normalize_rel(rel_path) or { return err }
	if rel.len == 0 {
		return error('invalid path')
	}
	joined := os.join_path(ws, rel)
	if os.is_dir(joined) {
		return error('is a directory')
	}
	real := os.real_path(joined)
	contain_in_workspace(ws, real)!
	if !os.is_file(real) {
		return error('file not found')
	}
	return real
}

fn resolve_workspace_write_path(ws string, rel_path string) !string {
	rel := normalize_rel(rel_path) or { return err }
	if rel.len == 0 {
		return error('invalid path')
	}
	joined := os.join_path(ws, rel)
	parent := os.dir(joined)
	if os.exists(parent) {
		parent_real := os.real_path(parent)
		contain_in_workspace(ws, parent_real)!
	} else {
		contain_in_workspace(ws, os.real_path(os.dir(parent))) or {
			return error('path outside workspace')
		}
	}
	if os.exists(joined) {
		real := os.real_path(joined)
		contain_in_workspace(ws, real)!
		if os.is_dir(real) {
			return error('is a directory')
		}
		return real
	}
	return joined
}

fn contain_in_workspace(ws string, real string) ! {
	sep := os.path_separator
	if real.len == 0 || (real != ws && !real.starts_with(ws + sep)) {
		return error('path outside workspace')
	}
}

fn normalize_rel(rel_path string) !string {
	rel := rel_path.trim_space().trim_left('/').trim_right('/')
	if rel == '.' {
		return ''
	}
	if rel.contains('..') || rel.contains('\x00') || rel.contains('%') {
		return error('invalid path')
	}
	return rel
}

fn walk_workspace_tree(ws string, cur string, depth int, max_depth int, mut nodes []WorkspaceFileNode) {
	if depth > max_depth || nodes.len >= file_tree_max_nodes {
		return
	}
	entries := os.ls(cur) or { return }
	mut dirs := []string{}
	mut files := []string{}
	for en in entries {
		if skip_tree_name(en) {
			continue
		}
		full := os.join_path(cur, en)
		if os.is_link(full) {
			real := os.real_path(full)
			if real.len == 0 || (real != ws && !real.starts_with(ws + os.path_separator)) {
				continue
			}
		}
		if os.is_dir(full) {
			dirs << en
		} else {
			files << en
		}
	}
	dirs.sort()
	files.sort()
	for d in dirs {
		if nodes.len >= file_tree_max_nodes {
			return
		}
		full := os.join_path(cur, d)
		rel := pack_rel_path(ws, full)
		nodes << WorkspaceFileNode{
			name: d
			path: rel
			kind: 'dir'
			size: 0
			depth: depth
			masked: false
		}
		walk_workspace_tree(ws, full, depth + 1, max_depth, mut nodes)
	}
	for f in files {
		if nodes.len >= file_tree_max_nodes {
			return
		}
		full := os.join_path(cur, f)
		rel := pack_rel_path(ws, full)
		nodes << WorkspaceFileNode{
			name: f
			path: rel
			kind: 'file'
			size: int(os.file_size(full))
			depth: depth
			masked: is_secret_file_name(f)
		}
	}
}

fn skip_tree_name(name string) bool {
	return name in ['.git', 'node_modules', '.v', 'dist', 'target', '__pycache__', '.venv', 'venv',
		'.turbo', 'coverage']
}

fn is_secret_file_name(name string) bool {
	n := name.to_lower()
	if n == '.env' || n.starts_with('.env.') {
		return true
	}
	if n in ['id_rsa', 'id_ed25519', 'id_ecdsa', 'credentials.json', 'secrets.json', 'secrets.yaml',
		'secrets.yml'] {
		return true
	}
	return n.ends_with('.pem') || n.ends_with('.key') || n.ends_with('.p12') || n.ends_with('.pfx')
		|| n.ends_with('.keystore')
}

fn file_bytes_are_binary(s string) bool {
	limit := if s.len < 8192 { s.len } else { 8192 }
	for i in 0 .. limit {
		if s[i] == 0 {
			return true
		}
	}
	return false
}

fn clamp_tree_depth(max_depth int) int {
	if max_depth <= 0 {
		return file_tree_default_depth
	}
	if max_depth > file_tree_max_depth {
		return file_tree_max_depth
	}
	return max_depth
}

fn pack_rel_or_dot(ws string, abs string) string {
	if abs == ws {
		return '.'
	}
	return pack_rel_path(ws, abs)
}
