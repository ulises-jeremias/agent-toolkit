module agent_toolkit_core

import os
import time

const memory_body_limit = 65536

// MemoryProvenance is what we can truthfully say about an entry.
// author and agent stay empty unless a real source exists (git author on
// read; never invented from the learnings "Session" context column).
pub struct MemoryProvenance {
pub:
	file      string
	author    string
	timestamp string
	project   string
	agent     string
}

// MemoryEntry is one knowledge/*.md file. body is populated on read and
// empty on list (list carries snippet only).
pub struct MemoryEntry {
pub:
	id         string
	kind       string
	title      string
	snippet    string
	body       string
	tags       []string
	provenance MemoryProvenance
}

// MemoryHit is one search match inside a knowledge file.
pub struct MemoryHit {
pub:
	path    string
	line    int
	snippet string
	kind    string
}

pub struct MemoryListResponse {
pub:
	ok      bool
	entries []MemoryEntry
}

pub struct MemorySearchResponse {
pub:
	ok    bool
	query string
	hits  []MemoryHit
}

pub struct MemoryReadResponse {
pub:
	ok    bool
	entry MemoryEntry
}

pub struct MemoryWriteResponse {
pub:
	ok      bool
	message string
	path    string
}

// list_memory_entries returns one row per knowledge/*.md file. Missing
// knowledge/ is an empty list, not an error.
pub fn list_memory_entries(workspace string) ![]MemoryEntry {
	ws := require_memory_workspace(workspace)!
	knowledge := os.join_path(ws, 'knowledge')
	if !os.is_dir(knowledge) {
		return []MemoryEntry{}
	}
	project := os.file_name(ws)
	mut out := []MemoryEntry{}
	for md in list_md_files(knowledge) {
		rel := pack_rel_path(ws, md)
		text := os.read_file(md) or { continue }
		out << memory_entry_from_file(ws, rel, text, project, false, '')
	}
	return out
}

// search_memory_entries is a case-insensitive line scan. Empty query is
// rejected so a missing ?q= cannot look like "everything matched".
pub fn search_memory_entries(workspace string, query string) ![]MemoryHit {
	q := query.trim_space()
	if q.len == 0 {
		return error('query is required')
	}
	ws := require_memory_workspace(workspace)!
	knowledge := os.join_path(ws, 'knowledge')
	if !os.is_dir(knowledge) {
		return []MemoryHit{}
	}
	low := q.to_lower()
	mut hits := []MemoryHit{}
	for md in list_md_files(knowledge) {
		rel := pack_rel_path(ws, md)
		text := os.read_file(md) or { continue }
		kind := memory_kind_from_path(rel)
		for i, line in text.split_into_lines() {
			if line.to_lower().contains(low) {
				hits << MemoryHit{
					path: rel
					line: i + 1
					snippet: clip(line.trim_space(), 160)
					kind: kind
				}
			}
		}
	}
	return hits
}

// read_memory_entry returns one contained knowledge/*.md file.
pub fn read_memory_entry(workspace string, rel_path string) !MemoryEntry {
	ws := require_memory_workspace(workspace)!
	abs := resolve_knowledge_file(ws, rel_path)!
	text := os.read_file(abs) or { return error('memory file not found') }
	rel := pack_rel_path(ws, abs)
	author := git_last_author(ws, rel)
	return memory_entry_from_file(ws, rel, text, os.file_name(ws), true, author)
}

// add_memory_entry records a learning, process, or todo via run_memory.
pub fn add_memory_entry(workspace string, entry_type string, title string, content string) MemoryWriteResponse {
	ws := require_memory_workspace(workspace) or {
		return MemoryWriteResponse{
			ok: false
			message: err.msg()
		}
	}
	report := run_memory(MemoryOptions{
		subcommand: 'add'
		workspace_path: ws
		entry_type: entry_type
		title: title
		content: content
	})
	return MemoryWriteResponse{
		ok: report.ok
		message: report.message
		path: report.data['path'] or { '' }
	}
}

// edit_memory_entry replaces a knowledge/*.md file atomically.
pub fn edit_memory_entry(workspace string, rel_path string, body string) !MemoryWriteResponse {
	ws := require_memory_workspace(workspace)!
	abs := resolve_knowledge_file(ws, rel_path)!
	if !os.is_file(abs) {
		return error('memory file not found')
	}
	check_memory_body(body)!
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
	return MemoryWriteResponse{
		ok: true
		message: 'updated ${rel}'
		path: rel
	}
}

// archive_memory_entry moves a knowledge file under knowledge/archive/,
// keeping the rest of the relative path. It does not delete.
pub fn archive_memory_entry(workspace string, rel_path string) !MemoryWriteResponse {
	ws := require_memory_workspace(workspace)!
	abs := resolve_knowledge_file(ws, rel_path)!
	if !os.is_file(abs) {
		return error('memory file not found')
	}
	rel := pack_rel_path(ws, abs)
	if rel.starts_with('knowledge/archive/') {
		return error('already archived')
	}
	rest := rel.all_after('knowledge/')
	dest := os.join_path(ws, 'knowledge', 'archive', rest)
	os.mkdir_all(os.dir(dest)) or { return error('write failed: ${err}') }
	if os.exists(dest) {
		return error('already archived')
	}
	os.mv(abs, dest) or { return error('write failed: ${err}') }
	dest_rel := pack_rel_path(ws, dest)
	return MemoryWriteResponse{
		ok: true
		message: 'archived ${rel}'
		path: dest_rel
	}
}

fn require_memory_workspace(workspace string) !string {
	ws := find_workspace_root(workspace) or { return error('workspace not found') }
	return ws
}

// resolve_knowledge_file requires a knowledge/*.md path contained in ws
// after symlink resolution.
fn resolve_knowledge_file(ws string, rel_path string) !string {
	rel := rel_path.trim_space().trim_left('/')
	if rel.len == 0 {
		return error('invalid path')
	}
	if rel.contains('..') || rel.contains('\x00') || rel.contains('%') {
		return error('invalid path')
	}
	if !rel.starts_with('knowledge/') {
		return error('path outside knowledge/')
	}
	if !rel.ends_with('.md') {
		return error('memory entries are markdown only')
	}
	joined := os.join_path(ws, rel)
	if os.is_dir(joined) {
		return error('memory entries are markdown only')
	}
	real := os.real_path(joined)
	knowledge := os.real_path(os.join_path(ws, 'knowledge'))
	sep := os.path_separator
	if knowledge.len == 0 || (real != knowledge && !real.starts_with(knowledge + sep)) {
		return error('path outside knowledge/')
	}
	return real
}

fn check_memory_body(body string) ! {
	if body.len > memory_body_limit {
		return error('content too large')
	}
	if body.contains('\x00') {
		return error('binary content not allowed')
	}
}

fn memory_entry_from_file(ws string, rel string, text string, project string, include_body bool, author string) MemoryEntry {
	title := memory_title(rel, text)
	return MemoryEntry{
		id: rel
		kind: memory_kind_from_path(rel)
		title: title
		snippet: memory_snippet(text)
		body: if include_body { text } else { '' }
		tags: memory_hashtags(text)
		provenance: MemoryProvenance{
			file: rel
			author: author
			timestamp: memory_timestamp(rel, text, ws)
			project: project
			agent: ''
		}
	}
}

fn memory_kind_from_path(rel string) string {
	if rel.contains('/learnings/') || rel.ends_with('/learnings.md') {
		return 'learning'
	}
	if rel.contains('/processes/') {
		return 'process'
	}
	if rel.contains('/todos/') {
		return 'todo'
	}
	return 'general'
}

fn memory_title(rel string, text string) string {
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('# ') {
			return t[2..].trim_space()
		}
	}
	return os.file_name(rel).all_before_last('.md')
}

fn memory_snippet(text string) string {
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 || t.starts_with('#') || t.starts_with('<!--') || t.starts_with('|---')
			|| t.starts_with('| Date |') {
			continue
		}
		return clip(t, 160)
	}
	return clip(text.trim_space(), 160)
}

fn memory_timestamp(rel string, text string, ws string) string {
	for line in text.split_into_lines() {
		dated := first_iso_date(line)
		if dated.len > 0 {
			return dated
		}
	}
	abs := os.join_path(ws, rel)
	mtime := os.file_last_mod_unix(abs)
	if mtime > 0 {
		return time.unix(i64(mtime)).format_rfc3339()[..10]
	}
	return ''
}

fn memory_hashtags(text string) []string {
	mut out := []string{}
	mut seen := map[string]bool{}
	for raw in text.split(' ') {
		tok := raw.trim_space().trim_right('.,;:)|')
		if tok.len < 2 || !tok.starts_with('#') {
			continue
		}
		tag := tok[1..].to_lower()
		if tag.len == 0 || !has_tag_chars(tag) || tag in seen {
			continue
		}
		seen[tag] = true
		out << tag
		if out.len >= 8 {
			break
		}
	}
	return out
}

fn has_tag_chars(s string) bool {
	for c in s {
		if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_` || c == `-`) {
			return false
		}
	}
	return true
}

fn git_last_author(ws string, rel string) string {
	if !os.exists(os.join_path(ws, '.git')) {
		return ''
	}
	git := os.find_abs_path_of_executable('git') or { return '' }
	mut p := os.new_process(git)
	p.set_args(['-C', ws, 'log', '-1', '--format=%an', '--', rel])
	p.set_redirect_stdio()
	p.run()
	mut waited := 0
	for waited < 2000 && p.is_alive() {
		time.sleep(50 * time.millisecond)
		waited += 50
	}
	if p.is_alive() {
		p.signal_kill()
	}
	p.wait()
	if p.status != .exited || p.code != 0 {
		p.close()
		return ''
	}
	out := p.stdout_slurp().trim_space()
	p.close()
	if out.len == 0 || out.len > 128 || out.contains('\n') {
		return ''
	}
	return out
}
