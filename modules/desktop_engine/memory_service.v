module desktop_engine

import agent_toolkit_core
import os
import time
import x.json2
import desktop_engine.eventbus

pub struct MemoryPalaceEntry {
pub:
	path   string
	title  string
	body   string
	kind   string
	tags   []string
	vector []f64
	hash   string
}

pub struct MemoryRecallResult {
pub mut:
	entry   MemoryPalaceEntry
	score   f64
	rank    int
	snippet string
}

pub fn (mut e Engine) memory_palace_entries() []MemoryPalaceEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	// Knowledge is workspace data: entries come from the active workspace's
	// knowledge/ directory (real filesystem workspace authority), never from
	// the bundled toolkit root (an embedded toolkit has no filesystem tree).
	base := e.active_workspace_root()
	mut out := []MemoryPalaceEntry{}
	if base != '' {
		knowledge := os.join_path(base, 'knowledge')
		if os.is_dir(knowledge) {
			files := os.walk_ext(knowledge, '.md', hidden: false)
			for f in files {
				content := os.read_file(f) or { continue }
				rel := if f.starts_with(base) {
					f[base.len..].trim_string_left('/')
				} else {
					f
				}
				kind := if rel.contains('learnings') {
					'learning'
				} else if rel.contains('processes') {
					'process'
				} else if rel.contains('todos') { 'todo' } else { 'general' }
				lines := content.split_into_lines()
				mut title := rel
				for line in lines {
					if line.trim_space().starts_with('# ') {
						title = line.trim_space()[2..].trim_space()
						break
					}
				}
				tags := extract_tags(content)
				vector := embed_text(title + ' ' + content)
				out << MemoryPalaceEntry{
					path: rel
					title: title
					body: content
					kind: kind
					tags: tags
					vector: vector
					hash: vector_hash(vector)
				}
			}
		}
	}
	snap := e.repo.snapshot()
	for k, v in snap.data {
		if k.starts_with('memory/') {
			vector := embed_text(v)
			out << MemoryPalaceEntry{
				path: k
				title: k.all_after_last('/')
				body: v
				kind: 'ledger'
				tags: extract_tags(v)
				vector: vector
				hash: vector_hash(vector)
			}
		}
	}
	// an empty palace is empty — no demo nodes with invented bodies
	return out
}

pub fn (mut e Engine) memory_semantic_recall(query string, limit int) []MemoryRecallResult {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	q := query.trim_space()
	if q == '' {
		return []MemoryRecallResult{}
	}
	entries := e.memory_palace_entries()
	qvec := embed_text(q)
	mut scored := []MemoryRecallResult{}
	for en in entries {
		cos := cosine(qvec, en.vector)
		overlap := token_overlap(q.to_lower(), (en.title + ' ' + en.body).to_lower())
		hybrid := cos * 0.7 + overlap * 0.3
		mut score := hybrid
		if en.title.to_lower().contains(q.to_lower()) || en.body.to_lower().contains(q.to_lower()) {
			if hybrid < 0.85 {
				score = 0.85 + hybrid * 0.1
			}
		}
		if score > 0.05 {
			snippet := snippet_for(q, en.body)
			scored << MemoryRecallResult{
				entry: en
				score: score
				snippet: snippet
			}
		}
	}
	scored.sort_with_compare(fn (a &MemoryRecallResult, b &MemoryRecallResult) int {
		if a.score > b.score {
			return -1
		}
		if a.score < b.score {
			return 1
		}
		if a.entry.path < b.entry.path {
			return -1
		}
		if a.entry.path > b.entry.path {
			return 1
		}
		return 0
	})
	for i, _ in scored {
		scored[i].rank = i + 1
	}
	mut lim := if limit <= 0 { 10 } else { limit }
	if lim > scored.len {
		lim = scored.len
	}
	return scored[..lim]
}

fn embed_text(s string) []f64 {
	mut vec := []f64{len: 16}
	tokens := tokenize(s.to_lower())
	if tokens.len == 0 {
		return vec
	}
	for tok in tokens {
		mut h := 0
		for ch in tok {
			h = (h * 31 + int(ch)) & 0x7fffffff
		}
		idx := h % 16
		w := 1.0 + f64(tok.len % 3) * 0.2
		vec[idx] += w
		h2 := ((h * 131) & 0x7fffffff) % 16
		vec[h2] += 0.3
	}
	mut norm := 0.0
	for v in vec {
		norm += v * v
	}
	norm = if norm == 0 { 1.0 } else { math_sqrt(norm) }
	for i, _ in vec {
		vec[i] /= norm
	}
	return vec
}

fn math_sqrt(x f64) f64 {
	if x <= 0 {
		return 0
	}
	mut r := x
	for _ in 0 .. 10 {
		r = 0.5 * (r + x / r)
	}
	return r
}

fn cosine(a []f64, b []f64) f64 {
	if a.len != b.len || a.len == 0 {
		return 0
	}
	mut dot := 0.0
	mut na := 0.0
	mut nb := 0.0
	for i in 0 .. a.len - 1 {
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math_sqrt(na) * math_sqrt(nb))
}

fn tokenize(s string) []string {
	mut out := []string{}
	mut cur := ''
	for ch in s {
		if (ch >= `a` && ch <= `z`) || (ch >= `0` && ch <= `9`) {
			cur += ch.ascii_str()
		} else {
			if cur.len >= 2 { out << cur }
			cur = ''
		}
	}
	if cur.len >= 2 { out << cur }
	return out
}

fn token_overlap(q string, doc string) f64 {
	qt := tokenize(q)
	dt := tokenize(doc)
	if qt.len == 0 || dt.len == 0 {
		return 0
	}
	mut set := map[string]bool{}
	for t in dt {
		set[t] = true
	}
	mut hits := 0
	for t in qt {
		if t in set { hits++ }
	}
	return f64(hits) / f64(qt.len)
}

fn extract_tags(s string) []string {
	mut out := []string{}
	lower := s.to_lower()
	keywords := ['palace', 'semantic', 'recall', 'brokered', 'git', 'file-tree', 'ide', 'memory',
		'workspace', 'skills']
	for k in keywords {
		if lower.contains(k) { out << k }
	}
	return out
}

fn vector_hash(v []f64) string {
	mut h := 0
	for i, val in v {
		h = h ^ (int(val * 1000) << (i % 8))
	}
	return '${h:08x}'[..8]
}

fn snippet_for(query string, body string) string {
	q := query.to_lower()
	lines := body.split_into_lines()
	for line in lines {
		if line.to_lower().contains(q) {
			t := line.trim_space()
			if t.len > 120 {
				return t[..120] + '…'
			}
			return t
		}
	}
	for line in lines {
		t := line.trim_space()
		if t.len > 10 {
			if t.len > 120 {
				return t[..120] + '…'
			}
			return t
		}
	}
	if body.len > 120 {
		return body[..120] + '…'
	}
	return body
}

// ── Slice D additive Engine wrappers: memory authoring (issue #1231) ─────
// Thin typed wrappers over agent_toolkit_core.run_memory. No core behavior
// change: the private memory_add/review/todo fns stay behind run_memory;
// these only translate Engine workspace authority (active workspace root)
// into MemoryOptions and return the core MemoryReport unchanged. Search and
// palace read paths above are untouched.

// resolve_authoring_workspace maps an explicit path (or the active workspace
// root when empty) to a real workspace directory. Empty means unavailable —
// never a cwd/toolkit-root fallback, never invented memories.
fn (mut e Engine) resolve_authoring_workspace(workspace_path string) !string {
	if workspace_path != '' {
		clean := os.real_path(workspace_path)
		if clean == '' || !os.is_dir(clean) {
			return error('workspace invalid')
		}
		return clean
	}
	base := e.active_workspace_root()
	if base == '' {
		return error('no active workspace')
	}
	return base
}

// memory_add_entry records a learning, process or todo entry via the core
// memory add path. Content is stored verbatim by core — the desktop never
// invents semantic memories; only user/agent-supplied content is recorded.
pub fn (mut e Engine) memory_add_entry(workspace_path string, entry_type string, title string, content string) agent_toolkit_core.MemoryReport {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.resolve_authoring_workspace(workspace_path) or {
		return agent_toolkit_core.MemoryReport{
			ok: false
			message: 'memory add unavailable: ${err.msg()}'
		}
	}
	return agent_toolkit_core.run_memory(agent_toolkit_core.MemoryOptions{
		subcommand: 'add'
		workspace_path: root
		entry_type: entry_type
		title: title
		content: content
	})
}

// memory_search_report runs the core CLI-parity keyword search over the
// workspace knowledge files. It complements memory_semantic_recall (hybrid
// cosine over palace entries); both read real files, never fixtures.
pub fn (mut e Engine) memory_search_report(workspace_path string, query string) agent_toolkit_core.MemoryReport {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.resolve_authoring_workspace(workspace_path) or {
		return agent_toolkit_core.MemoryReport{
			ok: false
			message: 'memory search unavailable: ${err.msg()}'
		}
	}
	return agent_toolkit_core.run_memory(agent_toolkit_core.MemoryOptions{
		subcommand: 'search'
		workspace_path: root
		query: query
	})
}

// memory_review_report runs the core duplicate/stale/contradiction review.
// fix only adds merge suggestions to the report — core never auto-edits.
pub fn (mut e Engine) memory_review_report(workspace_path string, stale_after int, fix bool) agent_toolkit_core.MemoryReport {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.resolve_authoring_workspace(workspace_path) or {
		return agent_toolkit_core.MemoryReport{
			ok: false
			message: 'memory review unavailable: ${err.msg()}'
		}
	}
	return agent_toolkit_core.run_memory(agent_toolkit_core.MemoryOptions{
		subcommand: 'review'
		workspace_path: root
		stale_after: stale_after
		fix: fix
	})
}

// memory_todo_report lists pending (and optionally completed) todos via the
// core todo path.
pub fn (mut e Engine) memory_todo_report(workspace_path string, show_done bool) agent_toolkit_core.MemoryReport {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.resolve_authoring_workspace(workspace_path) or {
		return agent_toolkit_core.MemoryReport{
			ok: false
			message: 'memory todo unavailable: ${err.msg()}'
		}
	}
	return agent_toolkit_core.run_memory(agent_toolkit_core.MemoryOptions{
		subcommand: 'todo'
		workspace_path: root
		show_done: show_done
	})
}

// memory_read_file reads one knowledge .md file for the memory browser read
// pane. Containment-checked against the workspace root and restricted to
// knowledge/ markdown — never an arbitrary filesystem read.
pub fn (mut e Engine) memory_read_file(workspace_path string, rel_path string) !string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.resolve_authoring_workspace(workspace_path)!
	clean := e.open_path_validated(root, os.join_path(root, rel_path))!
	knowledge := os.join_path(root, 'knowledge')
	knowledge_prefix := knowledge.trim_right('/\\') + os.path_separator
	if clean != knowledge && !clean.starts_with(knowledge_prefix) {
		return error('memory path outside knowledge/')
	}
	if !clean.ends_with('.md') {
		return error('memory entries are markdown only')
	}
	return os.read_file(clean) or { return error('memory read failed: ${clean}') }
}

// memory_delete_file removes one knowledge .md file for the memory browser.
// Callers (viewmodel/facade) apply the dirty-tree + running-agent guards;
// the Engine validates containment and records the revision.
pub fn (mut e Engine) memory_delete_file(workspace_path string, rel_path string) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	root := e.resolve_authoring_workspace(workspace_path)!
	clean := e.open_path_validated(root, os.join_path(root, rel_path))!
	knowledge := os.join_path(root, 'knowledge')
	knowledge_prefix := knowledge.trim_right('/\\') + os.path_separator
	if clean != knowledge && !clean.starts_with(knowledge_prefix) {
		return error('memory path outside knowledge/')
	}
	if !clean.ends_with('.md') {
		return error('memory entries are markdown only')
	}
	if os.is_dir(clean) {
		return error('memory delete refuses directories')
	}
	if !os.is_file(clean) {
		return error('memory file not found')
	}
	os.rm(clean) or { return error('memory delete failed: ${err}') }
	mut repo := e.repo
	mut tx := repo.begin('memory-delete')
	tx.set('memory/deleted/${rel_path}', time.now().unix().str())
	rev := e.put_transaction(mut tx)!
	e.bus.publish(eventbus.ToolkitEvent{
		kind: .workspace_changed
		revision: rev.revision
		path: 'memory:delete:${rel_path}'
		payload: json2.encode({
			'path': rel_path
			'revision': rev.revision.str()
		})
	})
	return rev.revision
}
