module agent_toolkit_core

import os
import time

// MemoryOptions configures the memory command family (#521).
pub struct MemoryOptions {
pub:
	subcommand     string
	workspace_path string
	entry_type     string // learning | process | todo
	title          string
	content        string
	query          string
	stale_after    int
	fix            bool
	show_done      bool
}

// MemoryReport is the domain result for memory subcommands.
pub struct MemoryReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

// run_memory implements add/search/inject/review/todo (Python cli/memory.py).
pub fn run_memory(opts MemoryOptions) MemoryReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return MemoryReport{
			ok:      true
			message: memory_help_text()
			data:    {
				'subcommand': 'help'
			}
		}
	}
	ws := find_workspace_root(opts.workspace_path) or {
		return MemoryReport{
			ok:      false
			message: workspace_missing
			data:    {
				'subcommand': sub
			}
		}
	}
	knowledge := os.join_path(ws, 'knowledge')
	return match sub {
		'add' { memory_add(ws, knowledge, opts) }
		'search' { memory_search(knowledge, opts) }
		'inject' { memory_inject(knowledge) }
		'review' { memory_review(ws, knowledge, opts) }
		'todo' { memory_todo(knowledge, opts) }
		else {
			MemoryReport{
				ok:      false
				message: "Unknown memory subcommand: ${sub}\nRun 'agent-toolkit memory --help' for usage."
				data:    {
					'subcommand': sub
				}
			}
		}
	}
}

// memory_result maps MemoryReport to CommandResult.
pub fn memory_result(report MemoryReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'memory'
		ok:      report.ok
		message: report.message
		data:    data
	}
}

// memory_help_text matches Python cli/memory.py module docstring.
pub fn memory_help_text() string {
	return 'memory — Persistent knowledge base management.

Usage:
    agent-toolkit memory <subcommand> [args]

Subcommands:
    add --type <type> [--title TITLE] [--workspace PATH] "content"
                       Add a learning, process, or todo entry
    search "query"     Case-insensitive search across all knowledge files
    inject             Output full knowledge base for AI session injection
    review [--fix] [--stale-after N]
                       Detect duplicates, stale/orphan refs, and contradictions
    todo [--done]       List unchecked todos (--done includes completed)

Types for add:
    learning   Factual session learning (knowledge/learnings/general.md)
    process    How-to procedure (knowledge/processes/<topic>.md)
    todo       Follow-up item (knowledge/todos/pending.md)

Options:
    --workspace PATH   Override workspace root
    --json             Structured CommandResult JSON
    --help             Show this help message
'
}

fn memory_add(ws string, knowledge string, opts MemoryOptions) MemoryReport {
	typ := opts.entry_type
	content := opts.content
	if typ.len == 0 || content.len == 0 {
		return MemoryReport{
			ok:      false
			message: 'Usage: agent-toolkit memory add --type <type> "content"\nTypes: learning, process, todo'
		}
	}
	today := time.utc().format_rfc3339()[..10]
	match typ {
		'learning' {
			path := os.join_path(knowledge, 'learnings', 'general.md')
			if !os.is_file(path) {
				os.mkdir_all(os.dir(path)) or {}
				os.write_file(path, '# General Learnings\n\n| Date | Learning | Context |\n|------|----------|---------|') or {
					return memory_write_err(err)
				}
			}
			row := '| ${today} | ${content} | Session |'
			prepend_table_row(path, '| Date | Learning | Context |', row) or {
				return memory_write_err(err)
			}
			rel := pack_rel_path(ws, path)
			return MemoryReport{
				ok:      true
				message: 'Added learning to ${rel}'
				data:    {
					'subcommand': 'add'
					'type':       'learning'
				}
			}
		}
		'process' {
			topic := process_slug(if opts.title.len > 0 { opts.title } else { 'general' })
			path := os.join_path(knowledge, 'processes', '${topic}.md')
			if !os.is_file(path) {
				os.mkdir_all(os.dir(path)) or {}
				heading := if opts.title.len > 0 { opts.title } else { topic }
				os.write_file(path, '# Process: ${heading}\n\n<!-- How-to procedures -->\n') or {
					return memory_write_err(err)
				}
			}
			prev := os.read_file(path) or { '' }
			os.write_file(path, prev + '\n## ${today}\n\n${content}\n') or {
				return memory_write_err(err)
			}
			rel := pack_rel_path(ws, path)
			return MemoryReport{
				ok:      true
				message: 'Added process to ${rel}'
				data:    {
					'subcommand': 'add'
					'type':       'process'
				}
			}
		}
		'todo' {
			path := os.join_path(knowledge, 'todos', 'pending.md')
			if !os.is_file(path) {
				os.mkdir_all(os.dir(path)) or {}
				os.write_file(path, '# Pending Todos\n\n<!-- Add pending items with date added -->\n') or {
					return memory_write_err(err)
				}
			}
			marker := '<!-- Add pending items with date added -->'
			entry := '- [ ] ${today} - ${content}\n'
			prepend_after_marker(path, marker, entry) or { return memory_write_err(err) }
			rel := pack_rel_path(ws, path)
			return MemoryReport{
				ok:      true
				message: 'Added todo to ${rel}'
				data:    {
					'subcommand': 'add'
					'type':       'todo'
				}
			}
		}
		else {
			return MemoryReport{
				ok:      false
				message: 'Unknown type: ${typ}\nValid types: learning, process, todo'
			}
		}
	}
}

fn memory_write_err(err IError) MemoryReport {
	return MemoryReport{
		ok:      false
		message: 'write failed: ${err}'
	}
}

fn memory_search(knowledge string, opts MemoryOptions) MemoryReport {
	query := if opts.query.len > 0 { opts.query } else { opts.content }
	if query.len == 0 {
		return MemoryReport{
			ok:      false
			message: 'Usage: agent-toolkit memory search "query"'
		}
	}
	mut lines := []string{}
	lines << ''
	lines << '=== Searching: ${query} ==='
	lines << ''
	if !os.is_dir(knowledge) {
		lines << '  (knowledge/ directory not found)'
		lines << ''
		return MemoryReport{
			ok:      true
			message: lines.join('\n')
			data:    {
				'subcommand': 'search'
				'hits':       '0'
			}
		}
	}
	q := query.to_lower()
	mut hits := 0
	files := list_md_files(knowledge)
	for md in files {
		content := os.read_file(md) or { continue }
		file_lines := content.split_into_lines()
		mut matched := []int{}
		for i, line in file_lines {
			if line.to_lower().contains(q) {
				matched << i
			}
		}
		if matched.len == 0 {
			continue
		}
		hits++
		rel := pack_rel_path(os.dir(knowledge), md)
		lines << '  ${rel}:'
		limit := if matched.len < 5 { matched.len } else { 5 }
		for mi in 0 .. limit {
			lineno := matched[mi]
			ctx_start := if lineno > 0 { lineno - 1 } else { 0 }
			ctx_end := if lineno + 1 < file_lines.len { lineno + 1 } else { lineno }
			for ci in ctx_start .. ctx_end + 1 {
				text := file_lines[ci].trim_space()
				lines << '  ${ci + 1}: ${text}'
			}
		}
		if matched.len > 5 {
			lines << '    ... and ${matched.len - 5} more matches'
		}
		lines << ''
	}
	if hits == 0 {
		lines << '  (no results found)'
	}
	lines << ''
	return MemoryReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'search'
			'hits':       '${hits}'
		}
	}
}

fn memory_inject(knowledge string) MemoryReport {
	mut lines := []string{}
	lines << '<!-- agent-toolkit memory inject -->'
	lines << ''
	lines << '## Knowledge Base Summary'
	lines << ''
	mut has_output := false
	todos_path := os.join_path(knowledge, 'todos', 'pending.md')
	if os.is_file(todos_path) {
		content := os.read_file(todos_path) or { '' }
		mut unchecked := []string{}
		for line in content.split_into_lines() {
			if line.starts_with('- [ ]') {
				unchecked << line
			}
		}
		if unchecked.len > 0 {
			lines << '### Pending Todos'
			lines << ''
			limit := if unchecked.len < 15 { unchecked.len } else { 15 }
			for i in 0 .. limit {
				lines << unchecked[i]
			}
			lines << ''
			has_output = true
		}
	}
	learnings_path := os.join_path(knowledge, 'learnings', 'general.md')
	if os.is_file(learnings_path) {
		content := os.read_file(learnings_path) or { '' }
		mut rows := []string{}
		for line in content.split_into_lines() {
			if line.starts_with('| ') && line.len > 6 && line[2].is_digit() {
				rows << line
			}
		}
		if rows.len > 0 {
			lines << '### Recent Learnings'
			lines << ''
			lines << '| Date | Learning | Context |'
			lines << '|------|----------|---------|'
			limit := if rows.len < 10 { rows.len } else { 10 }
			for i in 0 .. limit {
				lines << rows[i]
			}
			lines << ''
			has_output = true
		}
	}
	procs_dir := os.join_path(knowledge, 'processes')
	if os.is_dir(procs_dir) {
		entries := os.ls(procs_dir) or { []string{} }
		mut names := []string{}
		for e in entries {
			if e.ends_with('.md') {
				names << e.all_before_last('.md')
			}
		}
		names.sort()
		if names.len > 0 {
			lines << '### Known Processes'
			lines << ''
			for name in names {
				lines << '- `knowledge/processes/${name}.md`'
			}
			lines << ''
			has_output = true
		}
	}
	if !has_output {
		lines << '(knowledge base is empty)'
	}
	lines << '<!-- end agent-toolkit memory inject -->'
	msg := lines.join('\n')
	// context_budget clip 2000 parity (Python clip budget=2000 tokens ~ 8000 chars; V devcompanion clips 2000 chars)
	clipped := if msg.len > 2000 { msg[..2000] } else { msg }
	return MemoryReport{
		ok:      true
		message: clipped
		data:    {
			'subcommand': 'inject'
		}
	}
}

struct MemEntry {
	path    string
	line_no int
	text    string
	dated   string
}

fn memory_review(ws string, knowledge string, opts MemoryOptions) MemoryReport {
	stale_after := if opts.stale_after > 0 { opts.stale_after } else { 90 }
	entries := collect_mem_entries(knowledge)
	dupes := find_duplicates(entries)
	contras := find_contradictions(entries)
	stale, orphans := find_stale_orphans(entries, ws, stale_after)
	mut lines := []string{}
	lines << ''
	lines << '=== Memory Review ==='
	lines << ''
	lines << 'Scanned ${entries.len} entries under ${knowledge} (stale-after=${stale_after}d)'
	lines << ''
	mut issue_count := 0
	lines << 'Duplicates (similarity ≥ 80%):'
	if dupes.len == 0 {
		lines << '  (none)'
	} else {
		limit := if dupes.len < 20 { dupes.len } else { 20 }
		for i in 0 .. limit {
			d := dupes[i]
			issue_count++
			pct := int(d.ratio * 100)
			lines << '  • ${pct}%  ${os.file_name(d.left.path)}:${d.left.line_no} ↔ ${os.file_name(d.right.path)}:${d.right.line_no}'
			lines << '      A: ${clip(d.left.text, 100)}'
			lines << '      B: ${clip(d.right.text, 100)}'
			if opts.fix {
				lines << '      suggestion: merge into one entry and delete the weaker duplicate (${os.file_name(d.right.path)}:${d.right.line_no})'
			}
		}
	}
	lines << ''
	lines << "Contradictions (use X vs don't use X):"
	if contras.len == 0 {
		lines << '  (none)'
	} else {
		mut seen := map[string]bool{}
		for c in contras {
			sig := '${c.user.line_no}:${c.avoider.line_no}:${c.key}'
			if sig in seen {
				continue
			}
			seen[sig] = true
			issue_count++
			lines << '  • subject `${c.key}`'
			lines << '      use:     ${os.file_name(c.user.path)}:${c.user.line_no} — ${clip(c.user.text, 100)}'
			lines << '      avoid:   ${os.file_name(c.avoider.path)}:${c.avoider.line_no} — ${clip(c.avoider.text, 100)}'
			if opts.fix {
				lines << '      suggestion: reconcile guidance; keep a single current recommendation'
			}
		}
	}
	lines << ''
	lines << 'Stale (older than ${stale_after}d AND missing refs):'
	if stale.len == 0 {
		lines << '  (none)'
	} else {
		limit := if stale.len < 20 { stale.len } else { 20 }
		for i in 0 .. limit {
			issue_count++
			s := stale[i]
			lines << '  • ${os.file_name(s.entry.path)}:${s.entry.line_no} — ${s.detail}'
			lines << '      ${clip(s.entry.text, 100)}'
			if opts.fix {
				lines << '      suggestion: update the entry or remove obsolete guidance'
			}
		}
	}
	lines << ''
	lines << 'Orphaned references (path no longer exists):'
	if orphans.len == 0 {
		lines << '  (none)'
	} else {
		mut seen := map[string]bool{}
		limit := if orphans.len < 30 { orphans.len } else { 30 }
		for i in 0 .. limit {
			o := orphans[i]
			sig := '${o.entry.path}:${o.entry.line_no}:${o.detail}'
			if sig in seen {
				continue
			}
			seen[sig] = true
			issue_count++
			lines << '  • ${os.file_name(o.entry.path)}:${o.entry.line_no} — ${o.detail}'
			if opts.fix {
				lines << '      suggestion: fix the path or delete the orphaned note'
			}
		}
	}
	lines << ''
	if issue_count == 0 {
		lines << 'Knowledge base looks clean — no issues found.'
		return MemoryReport{
			ok:      true
			message: lines.join('\n')
			data:    {
				'subcommand': 'review'
				'issues':     '0'
			}
		}
	}
	lines << 'Found ${issue_count} issue(s).'
	if !opts.fix {
		lines << 'Re-run with --fix for merge/update suggestions.'
	}
	return MemoryReport{
		ok:      false
		message: lines.join('\n')
		data:    {
			'subcommand': 'review'
			'issues':     '${issue_count}'
		}
	}
}

fn memory_todo(knowledge string, opts MemoryOptions) MemoryReport {
	path := os.join_path(knowledge, 'todos', 'pending.md')
	if !os.is_file(path) {
		return MemoryReport{
			ok:      true
			message: '(no todos file found)'
			data:    {
				'subcommand': 'todo'
			}
		}
	}
	content := os.read_file(path) or { '' }
	mut unchecked := []string{}
	mut done := []string{}
	for line in content.split_into_lines() {
		if line.starts_with('- [ ]') {
			unchecked << line
		} else if line.starts_with('- [x]') || line.starts_with('- [X]') {
			done << line
		}
	}
	if unchecked.len == 0 && done.len == 0 {
		return MemoryReport{
			ok:      true
			message: '(no todos found)'
			data:    {
				'subcommand': 'todo'
			}
		}
	}
	mut lines := []string{}
	if unchecked.len > 0 {
		lines << ''
		lines << 'Pending Todos:'
		lines << ''
		for item in unchecked {
			lines << '  ${item}'
		}
		lines << ''
	}
	if opts.show_done && done.len > 0 {
		lines << ''
		lines << 'Completed Todos:'
		lines << ''
		for item in done {
			lines << '  ${item}'
		}
		lines << ''
	} else if unchecked.len == 0 {
		lines << '(no pending todos)'
	}
	return MemoryReport{
		ok:      true
		message: lines.join('\n')
		data:    {
			'subcommand': 'todo'
			'pending':    '${unchecked.len}'
		}
	}
}

fn prepend_after_marker(path string, marker string, entry string) ! {
	content := os.read_file(path) or { '' }
	if !content.contains(marker) {
		os.write_file(path, content + '\n' + entry)!
		return
	}
	idx := content.index(marker) or { -1 }
	if idx < 0 {
		os.write_file(path, content + '\n' + entry)!
		return
	}
	end := idx + marker.len
	os.write_file(path, content[..end] + '\n' + entry + content[end..])!
}

fn prepend_table_row(path string, header_row string, new_row string) ! {
	content := os.read_file(path) or { '' }
	if !content.contains(header_row) {
		os.write_file(path, content + '\n' + new_row + '\n')!
		return
	}
	idx := content.index(header_row) or { -1 }
	if idx < 0 {
		os.write_file(path, content + '\n' + new_row + '\n')!
		return
	}
	start := idx + header_row.len
	rest := content[start..]
	mut skip := 0
	if rest.starts_with('\n') {
		skip = 1
		line := rest[1..].all_before('\n')
		if line.contains('---') {
			skip = 1 + line.len
			if skip < rest.len && rest[skip] == `\n` {
				skip++
			}
		}
	}
	insert_at := start + skip
	os.write_file(path, content[..insert_at] + '\n' + new_row + content[insert_at..])!
}

fn process_slug(s string) string {
	mut out := []u8{}
	low := s.to_lower()
	mut prev_dash := false
	for c in low {
		if (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) {
			out << c
			prev_dash = false
		} else if !prev_dash {
			out << `-`
			prev_dash = true
		}
	}
	mut slug := out.bytestr().trim('-')
	if slug.len == 0 {
		return 'general'
	}
	return slug
}

fn list_md_files(dir string) []string {
	mut out := []string{}
	if !os.is_dir(dir) {
		return out
	}
	entries := os.ls(dir) or { return out }
	mut names := entries.clone()
	names.sort()
	for e in names {
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			out << list_md_files(p)
		} else if e.ends_with('.md') {
			out << p
		}
	}
	return out
}

fn collect_mem_entries(knowledge string) []MemEntry {
	mut entries := []MemEntry{}
	for md in list_md_files(knowledge) {
		content := os.read_file(md) or { continue }
		file_lines := content.split_into_lines()
		for i, line in file_lines {
			stripped := line.trim_space()
			if stripped.len == 0 || stripped.starts_with('#') || stripped.starts_with('<!--') {
				continue
			}
			if stripped.starts_with('| Date |') || stripped.starts_with('|------') {
				continue
			}
			if is_table_sep(stripped) {
				continue
			}
			if stripped.starts_with('|') || stripped.starts_with('- ') || stripped.len >= 24 {
				mut text := stripped
				if stripped.starts_with('|') {
					cells := stripped.trim('|').split('|').map(it.trim_space()).filter(it.len > 0)
					text = cells.join(' — ')
				}
				entries << MemEntry{
					path:    md
					line_no: i + 1
					text:    text
					dated:   first_iso_date(stripped)
				}
			}
		}
	}
	return entries
}

fn is_table_sep(s string) bool {
	if !s.starts_with('|') || !s.ends_with('|') {
		return false
	}
	for c in s {
		if c !in [`|`, `-`, `:`, ` `] {
			return false
		}
	}
	return true
}

struct DupeHit {
	left  MemEntry
	right MemEntry
	ratio f64
}

struct ContraHit {
	user    MemEntry
	avoider MemEntry
	key     string
}

struct ReviewNote {
	entry  MemEntry
	detail string
}

fn find_duplicates(entries []MemEntry) []DupeHit {
	mut dupes := []DupeHit{}
	for i, left in entries {
		for j := i + 1; j < entries.len; j++ {
			right := entries[j]
			ratio := text_similarity(left.text, right.text)
			if ratio >= 0.8 {
				dupes << DupeHit{left, right, ratio}
			}
		}
	}
	return dupes
}

fn find_contradictions(entries []MemEntry) []ContraHit {
	mut use_map := map[string][]MemEntry{}
	mut avoid_map := map[string][]MemEntry{}
	for entry in entries {
		low := entry.text.to_lower()
		extract_use_keys(low, entry, mut use_map, mut avoid_map)
	}
	mut hits := []ContraHit{}
	for key, avoiders in avoid_map {
		users := use_map[key]
		for user in users {
			for avoider in avoiders {
				hits << ContraHit{user, avoider, key}
			}
		}
	}
	return hits
}

fn extract_use_keys(low string, entry MemEntry, mut use_map map[string][]MemEntry, mut avoid_map map[string][]MemEntry) {
	for neg in ['do not use ', "don't use ", 'dont use ', 'never use ', 'avoid use ', 'never call ',
		'do not call ', "don't call "] {
		if low.contains(neg) {
			key := token_after(low, neg)
			if key.len > 0 {
				avoid_map[key] << entry
			}
		}
	}
	for pos in ['always use ', 'should use ', 'prefer ', ' use '] {
		if low.contains(pos) {
			idx := low.index(pos) or { continue }
			start := if idx >= 12 { idx - 12 } else { 0 }
			window := low[start..idx]
			if window.contains("don't") || window.contains('dont') || window.contains('do not')
				|| window.contains('never') || window.contains('avoid') {
				continue
			}
			key := token_after(low, pos)
			if key.len > 0 {
				use_map[key] << entry
			}
		}
	}
}

fn token_after(low string, prefix string) string {
	idx := low.index(prefix) or { return '' }
	rest := low[idx + prefix.len..].trim_space()
	mut tok := []u8{}
	for c in rest {
		if (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c in [`_`, `.`, `/`, `-`] {
			tok << c
		} else {
			break
		}
	}
	return tok.bytestr()
}

fn find_stale_orphans(entries []MemEntry, ws string, stale_after int) ([]ReviewNote, []ReviewNote) {
	mut stale := []ReviewNote{}
	mut orphans := []ReviewNote{}
	cutoff := time.utc().add(-stale_after * 24 * time.hour).format_rfc3339()[..10]
	for entry in entries {
		refs := extract_path_refs(entry.text)
		mut missing := []string{}
		for ref in refs {
			target := resolve_mem_ref(ref, ws)
			if !os.exists(target) {
				missing << ref
			}
		}
		mut dated := entry.dated
		if dated.len == 0 {
			mtime := os.file_last_mod_unix(entry.path)
			if mtime > 0 {
				dated = time.unix(i64(mtime)).format_rfc3339()[..10]
			}
		}
		for ref in missing {
			orphans << ReviewNote{entry, 'missing path `${ref}`'}
		}
		if missing.len > 0 && dated.len > 0 && dated < cutoff {
			stale << ReviewNote{entry, 'last seen ${dated} (>${stale_after}d) and refs missing: ' +
				missing.map('`${it}`').join(', ')}
		}
	}
	return stale, orphans
}

fn extract_path_refs(text string) []string {
	mut out := []string{}
	mut seen := map[string]bool{}
	// backtick paths
	mut i := 0
	chars := text.runes()
	s := text
	for i < s.len {
		if s[i] == `\`` {
			j := i + 1
			mut k := j
			for k < s.len && s[k] != `\`` {
				k++
			}
			if k < s.len {
				raw := s[j..k]
				if !raw.contains('://') && (raw.contains('/') || raw.starts_with('.') || raw.starts_with('~')) {
					if raw !in seen {
						seen[raw] = true
						out << raw
					}
				}
				i = k + 1
				continue
			}
		}
		i++
	}
	_ = chars
	return out
}

fn resolve_mem_ref(ref string, ws string) string {
	if ref.starts_with('~/') {
		return os.join_path(os.home_dir(), ref[2..])
	}
	if os.is_abs_path(ref) {
		return ref
	}
	return os.join_path(ws, ref)
}

fn text_similarity(a string, b string) f64 {
	an := normalize_mem(a)
	bn := normalize_mem(b)
	if an.len == 0 || bn.len == 0 {
		return 0.0
	}
	if an == bn {
		return 1.0
	}
	ag := bigrams(an)
	bg := bigrams(bn)
	if ag.len == 0 || bg.len == 0 {
		return 0.0
	}
	mut inter := 0
	mut bgc := map[string]int{}
	for g in bg {
		bgc[g] = bgc[g] + 1
	}
	for g in ag {
		if bgc[g] > 0 {
			inter++
			bgc[g] = bgc[g] - 1
		}
	}
	return (2.0 * f64(inter)) / f64(ag.len + bg.len)
}

fn normalize_mem(s string) string {
	return s.to_lower().split(' ').filter(it.len > 0).join(' ')
}

fn bigrams(s string) []string {
	if s.len < 2 {
		return []
	}
	mut out := []string{}
	for i := 0; i + 1 < s.len; i++ {
		out << s[i..i + 2]
	}
	return out
}

fn clip(s string, n int) string {
	if s.len <= n {
		return s
	}
	return s[..n]
}
