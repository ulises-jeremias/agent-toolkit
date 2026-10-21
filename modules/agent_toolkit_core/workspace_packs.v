module agent_toolkit_core

import os
import crypto.sha256
import crypto.rand
import yaml

const workspace_pack_count_limit = 256
const workspace_pack_file_limit = 64 * 1024

struct WorkspacePackDocument {
	name        string
	description string
	projects    []string
	notes       string
}

pub struct WorkspacePackSummary {
pub:
	path              string
	name              string
	description       string
	projects          []string
	notes             string
	revision          string
	validation_errors []string
	active            bool
	// Top-level fields the Desktop form does not edit (for example `repos`,
	// `org`, `ai`, `conventions`). They are preserved verbatim on save and
	// listed here so the UI can disclose them instead of dropping them.
	extra_fields []string
}

pub struct WorkspacePacksResponse {
pub:
	ok           bool
	workspace    string
	active_pack  string
	marker_issue string
	packs        []WorkspacePackSummary
}

pub struct WorkspacePackActivateRequest {
pub:
	workspace string
	pack_path string
}

pub struct WorkspacePackActivateResponse {
pub:
	ok          bool
	workspace   string
	active_pack string
	message     string
}

pub struct WorkspacePackSaveRequest {
pub:
	workspace   string
	pack_path   string
	revision    string
	name        string
	description string
	projects    []string
	notes       string
}

pub struct WorkspacePackSaveResponse {
pub:
	ok      bool
	pack    WorkspacePackSummary
	message string
}

// list_workspace_packs returns safe, local workspace context bundles. These
// are distinct from repository solution packs and loop --pack overrides.
pub fn list_workspace_packs(workspace string) !WorkspacePacksResponse {
	ws := find_workspace_root(workspace) or { return error('workspace not found') }
	root := os.real_path(ws)
	dir := os.join_path(root, 'packs')
	if os.is_link(dir) {
		return error('workspace packs directory is a symlink')
	}
	active_file := os.join_path(root, '.active-pack')
	mut marker_issue := ''
	mut active := ''
	if os.is_link(active_file) {
		marker_issue = 'The saved context marker is a symbolic link. Clear the selection to remove the link safely.'
	} else if os.is_file(active_file) {
		if os.file_size(active_file) > 4096 {
			marker_issue = 'The saved context marker is too large to read. Clear the selection to remove it.'
		} else {
			active = os.read_file(active_file) or {
				marker_issue = 'The saved context marker cannot be read. Clear the selection to remove it.'
				''
			}.trim_space()
		}
	} else if os.exists(active_file) {
		marker_issue = 'The saved context marker is not a regular file. Clear the selection to remove it.'
	}
	if !os.is_dir(dir) {
		return WorkspacePacksResponse{
			ok: true
			workspace: root
			active_pack: active
			marker_issue: marker_issue
			packs: []WorkspacePackSummary{}
		}
	}
	paths := workspace_pack_paths(root, dir, 0)
	if paths.len > workspace_pack_count_limit {
		return error('too many workspace packs')
	}
	mut packs := []WorkspacePackSummary{}
	for path in paths {
		file := os.join_path(root, path)
		if os.is_link(file) {
			continue
		}
		if os.file_size(file) > workspace_pack_file_limit {
			packs << WorkspacePackSummary{
				path: path
				name: os.file_name(path).all_before_last('.')
				validation_errors: ['Pack exceeds the 64 KiB review limit.']
				active: path == active
			}
			continue
		}
		text := os.read_file(file) or {
			packs << WorkspacePackSummary{
				path: path
				name: os.file_name(path).all_before_last('.')
				validation_errors: ['Pack could not be read.']
				active: path == active
			}
			continue
		}
		mut validation_errors := []string{}
		doc := yaml.decode[WorkspacePackDocument](text) or {
			validation_errors << 'Pack YAML could not be parsed: ${err.msg()}'
			WorkspacePackDocument{}
		}
		if doc.name.trim_space().len == 0 { validation_errors << "Missing required field 'name'." }
		if doc.description.trim_space().len == 0 {
			validation_errors << "Missing required field 'description'."
		}
		packs << WorkspacePackSummary{
			path: path
			name: if doc.name.len > 0 { doc.name } else { os.file_name(path).all_before_last('.') }
			description: doc.description
			projects: doc.projects
			notes: doc.notes
			revision: sha256.hexhash(text)
			validation_errors: validation_errors
			active: path == active
			extra_fields: workspace_pack_extra_fields(text)
		}
	}
	packs.sort(a.path < b.path)
	return WorkspacePacksResponse{
		ok: true
		workspace: root
		active_pack: active
		marker_issue: marker_issue
		packs: packs
	}
}

// save_workspace_pack writes a small, inert workspace context document. Existing
// files require the digest returned by list_workspace_packs so stale edits fail.
pub fn save_workspace_pack(req WorkspacePackSaveRequest) !WorkspacePackSaveResponse {
	ws := find_workspace_root(req.workspace) or { return error('workspace not found') }
	root := os.real_path(ws)
	if req.name.trim_space().len == 0 || req.name.len > 80 || workspace_pack_has_control(req.name, false) {
		return error('name must be 1–80 characters on one line')
	}
	if req.description.trim_space().len == 0 || req.description.len > 240 || workspace_pack_has_control(req.description, false) {
		return error('description must be 1–240 characters on one line')
	}
	if req.projects.len > 50 {
		return error('a pack can include at most 50 projects')
	}
	mut seen_projects := []string{}
	for project in req.projects {
		if !workspace_pack_project_ref(project) || project in seen_projects {
			return error('projects must be unique simple project names')
		}
		seen_projects << project
	}
	if req.notes.len > 8192 || workspace_pack_has_control(req.notes, true) {
		return error('notes contain unsupported control characters or exceed the 8 KiB limit')
	}
	notes := req.notes.replace('\r\n', '\n').replace('\r', '\n')
	pack_dir := os.join_path(root, 'packs')
	if os.is_link(pack_dir) {
		return error('workspace packs directory is a symlink')
	}
	os.mkdir_all(pack_dir) or { return error('workspace packs directory cannot be created') }
	mut rel := req.pack_path
	mut target := ''
	if rel.len == 0 {
		if req.revision.len != 0 {
			return error('new packs cannot include an existing revision')
		}
		slug := workspace_pack_name_slug(req.name)
		if slug.len == 0 {
			return error('name needs at least one letter or number')
		}
		rel = 'packs/${slug}.yaml'
		target = os.join_path(root, rel)
		if os.exists(target) || os.is_link(target) {
			return error('a pack with this name already exists')
		}
	} else {
		if !workspace_pack_relative_path(rel) {
			return error('workspace pack path is invalid')
		}
		target = os.join_path(root, rel)
		if !target.starts_with(pack_dir + os.path_separator) && target != pack_dir {
			return error('workspace pack path is invalid')
		}
	}
	mut lines := ['name: ${workspace_pack_yaml_quote(req.name)}',
		'description: ${workspace_pack_yaml_quote(req.description)}']
	if req.projects.len == 0 {
		lines << 'projects: []'
	} else {
		lines << 'projects:'
		for project in req.projects {
			lines << '  - ${project}'
		}
	}
	if notes.len > 0 {
		mut trailing_newlines := 0
		for index := notes.len - 1; index >= 0 && notes[index] == `\n`; index-- {
			trailing_newlines++
		}
		indicator := if trailing_newlines == 0 {
			'|-'
		} else if trailing_newlines == 1 { '|' } else { '|+' }
		lines << 'notes: ${indicator}'
		body := notes[..notes.len - trailing_newlines]
		if body.len > 0 {
			for line in body.split('\n') {
				lines << '  ${line}'
			}
		}
		for _ in 0 .. trailing_newlines - 1 {
			lines << '  '
		}
	}
	// Preserve top-level fields the Desktop form does not edit verbatim, so
	// saving a rich pack (repos/org/ai/conventions/…) never destroys them.
	// The revision check below still runs against the file as opened, so a
	// stale read cannot resurrect blocks from an outdated copy.
	mut preserved_fields := []string{}
	if req.pack_path.len > 0 && os.is_file(target) && !os.is_link(target) {
		if existing := os.read_file(target) {
			preserved_fields = workspace_pack_extra_fields(existing)
			preserved := workspace_pack_preserved_lines(existing)
			if preserved.len > 0 {
				lines << ''
				lines << preserved
			}
		}
	}
	contents := lines.join('\n') + '\n'
	if contents.len > workspace_pack_file_limit {
		return error('pack exceeds the 64 KiB review limit')
	}
	// Validate exactly what the session-context reader will consume before write.
	encoded := yaml.decode[WorkspacePackDocument](contents) or { return error('pack could not be validated after encoding') }
	if encoded.name != req.name || encoded.description != req.description || encoded.projects != req.projects || encoded.notes != notes {
		return error('pack could not be validated after encoding')
	}
	if req.pack_path.len == 0 && (os.exists(target) || os.is_link(target)) {
		return error('a pack with this name already exists')
	}
	if req.pack_path.len > 0 && (os.is_link(target) || !os.is_file(target)) {
		return error('workspace pack is not a regular file')
	}
	if os.exists(target) && os.file_size(target) > workspace_pack_file_limit {
		return error('pack exceeds the 64 KiB review limit')
	}
	// An exclusive lock serializes compare-and-replace across server processes.
	// The unique temp names avoid following a predictable attacker-created link.
	lock_path := target + '.lock'
	lock_source := workspace_pack_unique_path(pack_dir, 'lock-source')!
	os.write_file(lock_source, '${os.getpid()}\n') or { return error('pack update could not be prepared') }
	defer { os.rm(lock_source) or {} }
	os.cp(lock_source, lock_path, fail_if_exists: true) or { return error('pack update is busy; close any other editor and try again') }
	defer { os.rm(lock_path) or {} }
	if req.pack_path.len > 0 {
		listed := list_workspace_packs(root)!
		if listed.packs.filter(it.path == rel).len == 0 {
			return error('workspace pack not found: ${rel}')
		}
		if os.is_link(target) || !os.is_file(target) {
			return error('workspace pack is not a regular file')
		}
		current := os.read_file(target) or { return error('workspace pack could not be read') }
		if req.revision.len != 64 || sha256.hexhash(current) != req.revision {
			return error('workspace pack changed since it was opened; discard this edit and reload the latest version')
		}
	} else if os.exists(target) || os.is_link(target) {
		return error('a pack with this name already exists')
	}
	tmp := workspace_pack_unique_path(pack_dir, 'pack')!
	os.write_file(tmp, contents) or { return error('pack could not be written') }
	defer { os.rm(tmp) or {} }
	os.mv(tmp, target) or { return error('pack could not be saved') }
	response := list_workspace_packs(root)!
	saved := response.packs.filter(it.path == rel)
	if saved.len == 0 {
		return error('saved pack could not be reloaded')
	}
	message := if preserved_fields.len > 0 {
		'Workspace context pack saved. Fields not edited here (${preserved_fields.join(', ')}) were preserved verbatim. Review it before selecting it for future sessions.'
	} else {
		'Workspace context pack saved. Review it before selecting it for future sessions.'
	}
	return WorkspacePackSaveResponse{
		ok: true
		pack: saved[0]
		message: message
	}
}

const workspace_pack_managed_fields = ['name', 'description', 'projects', 'notes']

// workspace_pack_top_level_key returns the key of a top-level YAML mapping
// line (`key:` at column 0), or '' for content, comment and blank lines.
fn workspace_pack_top_level_key(line string) string {
	if line.len == 0 || line[0] == `#` || line[0] == ` ` || line[0] == `\t` {
		return ''
	}
	mut end := 0
	for end < line.len {
		ch := line[end]
		if (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || (ch >= 48 && ch <= 57) || ch == 95 || ch == 45 {
			end++
		} else {
			break
		}
	}
	if end == 0 || end >= line.len || line[end] != `:` {
		return ''
	}
	if end + 1 < line.len && line[end + 1] != ` ` {
		return ''
	}
	return line[..end]
}

// workspace_pack_extra_fields lists top-level fields outside the Desktop
// form model, in file order, without duplicates.
fn workspace_pack_extra_fields(text string) []string {
	mut fields := []string{}
	for line in text.split('\n') {
		key := workspace_pack_top_level_key(line)
		if key.len > 0 && key !in workspace_pack_managed_fields && key !in fields {
			fields << key
		}
	}
	return fields
}

// workspace_pack_preserved_lines returns the verbatim lines of every
// unmanaged top-level block, including the comment/blank lines that precede
// it. Managed blocks (name/description/projects/notes) are dropped because
// the caller re-emits them from the request.
fn workspace_pack_preserved_lines(text string) []string {
	mut kept := []string{}
	mut pending := []string{}
	mut in_kept_block := false
	for line in text.split('\n') {
		key := workspace_pack_top_level_key(line)
		if key.len > 0 {
			if key in workspace_pack_managed_fields {
				pending = []string{}
				in_kept_block = false
			} else {
				kept << pending
				pending = []string{}
				kept << line
				in_kept_block = true
			}
		} else if line.starts_with('#') || line.trim_space().len == 0 {
			pending << line
		} else if in_kept_block {
			kept << pending
			pending = []string{}
			kept << line
		} else {
			pending = []string{}
		}
	}
	if in_kept_block {
		kept << pending
	}
	for kept.len > 0 && kept[kept.len - 1].trim_space().len == 0 {
		kept.delete(kept.len - 1)
	}
	return kept
}

fn workspace_pack_project_ref(value string) bool {
	if value.len == 0 || value.len > 64 || !((value[0] >= 65 && value[0] <= 90) || (value[0] >= 97 && value[0] <= 122) || (value[0] >= 48 && value[0] <= 57)) {
		return false
	}
	for ch in value.bytes() {
		if !(ch >= 65 && ch <= 90) && !(ch >= 97 && ch <= 122) && !(ch >= 48 && ch <= 57) && ch != 45 && ch != 95 {
			return false
		}
	}
	return true
}

fn workspace_pack_relative_path(value string) bool {
	if !value.starts_with('packs/') || !(value.ends_with('.yaml') || value.ends_with('.yml')) {
		return false
	}
	if value.contains('\\') {
		return false
	}
	for part in value.split('/') {
		if part in ['', '.', '..'] {
			return false
		}
	}
	return true
}

fn workspace_pack_unique_path(dir string, prefix string) !string {
	for _ in 0 .. 4 {
		random := rand.bytes(16)!
		mut hex := ''
		for byte in random {
			hex += '${byte:02x}'
		}
		path := os.join_path(dir, '.${prefix}-${hex}.tmp')
		if !os.exists(path) && !os.is_link(path) {
			return path
		}
	}
	return error('could not allocate a unique temporary path')
}

fn workspace_pack_notes(text string) string {
	doc := yaml.decode[WorkspacePackDocument](text) or { return '' }
	return doc.notes
}

fn workspace_pack_has_control(value string, multiline bool) bool {
	for ch in value.bytes() {
		if ch == 127 || (ch < 32 && !(multiline && (ch == 10 || ch == 13 || ch == 9))) {
			return true
		}
	}
	return false
}

fn workspace_pack_name_slug(value string) string {
	lower := value.to_lower()
	mut out := ''
	mut dash := false
	for i, ch in lower.bytes() {
		if (ch >= 97 && ch <= 122) || (ch >= 48 && ch <= 57) {
			if dash && out.len > 0 {
				out += '-'
			}
			out += lower[i..i + 1]
			dash = false
		} else {
			dash = true
		}
	}
	return out
}

fn workspace_pack_yaml_quote(value string) string {
	return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
}

// activate_workspace_pack switches the future session context marker without
// copying files or executing pack contents. An empty path clears the marker.
pub fn activate_workspace_pack(req WorkspacePackActivateRequest) !WorkspacePackActivateResponse {
	ws := find_workspace_root(req.workspace) or { return error('workspace not found') }
	root := os.real_path(ws)
	marker := os.join_path(root, '.active-pack')
	if req.pack_path.len > 0 {
		if os.is_link(marker) {
			return error('active pack marker is a symlink; clear it before selecting another pack')
		}
		packs := list_workspace_packs(root)!
		selected := packs.packs.filter(it.path == req.pack_path)
		if selected.len == 0 {
			return error('workspace pack not found: ${req.pack_path}')
		}
		if selected[0].validation_errors.len > 0 {
			return error('workspace pack is invalid: ${selected[0].validation_errors.join(' ')}')
		}
	}
	if req.pack_path.len == 0 {
		if os.exists(marker) || os.is_link(marker) {
			if !os.is_link(marker) && os.is_dir(marker) {
				os.rmdir(marker) or {
					return error('active pack marker is a non-empty directory; move its contents before selecting a pack')
				}
			} else {
				os.rm(marker) or { return error('active pack marker cannot be cleared') }
			}
		}
		return WorkspacePackActivateResponse{
			ok: true
			workspace: root
			message: 'Active workspace pack cleared. Future context no longer uses a pack overlay.'
		}
	}
	tmp := marker + '.${os.getpid()}.tmp'
	if os.exists(tmp) || os.is_link(tmp) {
		return error('active pack update is busy')
	}
	os.write_file(tmp, req.pack_path + '\n') or { return error('active pack marker cannot be written') }
	os.mv(tmp, marker) or {
		os.rm(tmp) or {}
		return error('active pack marker cannot be saved')
	}
	return WorkspacePackActivateResponse{
		ok: true
		workspace: root
		active_pack: req.pack_path
		message: 'Active workspace pack set to ${req.pack_path}. Its context applies to future workspace sessions; no files were copied and no capabilities were installed or run.'
	}
}

pub struct ContextFragment {
pub:
	id         string
	kind       string
	source     string
	sha256     string
	bytes      int
	est_tokens int
	mode       string
	detail     string
}

pub struct EffectiveContextResponse {
pub:
	ok               bool
	workspace        string
	active_pack      string
	fragments        []ContextFragment
	total_est_tokens int
	notes            []string
}

fn context_fragment(id string, kind string, source string, text string, detail string) ContextFragment {
	return ContextFragment{
		id: id
		kind: kind
		source: source
		sha256: sha256.hexhash(text)
		bytes: text.len
		est_tokens: (text.len + 3) / 4
		mode: 'inline'
		detail: detail
	}
}

// effective_context assembles the ordered fragment list a future session in
// this workspace would draw from: workspace AGENTS.md, the active pack,
// the active persona, then a knowledge summary (counts only — memory inject
// clips records separately). It is a pure read: selecting a pack never
// mutates the context of sessions that are already running.
pub fn effective_context(workspace string) !EffectiveContextResponse {
	root := find_workspace_root(workspace) or {
		return error('Workspace is unavailable or has no AGENTS.md.')
	}
	mut fragments := []ContextFragment{}
	agents_path := os.join_path(root, 'AGENTS.md')
	if os.is_file(agents_path) {
		text := os.read_file(agents_path) or { '' }
		fragments << context_fragment('agents', 'agents', 'AGENTS.md', text, 'Workspace rules and routing.')
	}
	listed := list_workspace_packs(workspace)!
	active := listed.active_pack
	if active.len > 0 {
		mut found := false
		for pack in listed.packs {
			if pack.path == active {
				found = true
				text := os.read_file(os.join_path(root, active)) or { '' }
				mut detail := 'Projects: ${pack.projects.join(', ')}.'
				if pack.notes.len > 0 {
					detail += ' Notes: ${pack.notes}'
				}
				if pack.extra_fields.len > 0 {
					detail += ' Preserved fields not inlined here: ${pack.extra_fields.join(', ')}.'
				}
				fragments << context_fragment('pack', 'pack', pack.path, text, detail)
			}
		}
		if !found {
			fragments << ContextFragment{
				id: 'pack'
				kind: 'pack'
				source: active
				mode: 'missing'
				detail: 'The active pack marker points at a file that does not exist.'
			}
		}
	}
	persona_name := read_strip(os.join_path(root, '.active-persona'))
	if persona_name.len > 0 {
		persona_file := persona_path(root, persona_name)
		if os.is_file(persona_file) {
			text := os.read_file(persona_file) or { '' }
			fragments << context_fragment('persona', 'persona', 'personas/${persona_name}.md', text, 'Active persona for this workspace.')
		} else {
			fragments << ContextFragment{
				id: 'persona'
				kind: 'persona'
				source: 'personas/${persona_name}.md'
				mode: 'missing'
				detail: 'The active persona marker points at a file that does not exist.'
			}
		}
	}
	knowledge := os.join_path(root, 'knowledge')
	if os.is_dir(knowledge) {
		ks := knowledge_summary(knowledge)
		fragments << ContextFragment{
			id: 'knowledge'
			kind: 'knowledge'
			source: 'knowledge/'
			bytes: approx_size(knowledge)
			mode: 'summary'
			detail: 'Knowledge summaries only (learnings=${ks.learnings}, todos=${ks.todos}, processes=${ks.processes}); memory injection clips individual records separately.'
		}
	}
	mut total := 0
	for fragment in fragments {
		total += fragment.est_tokens
	}
	return EffectiveContextResponse{
		ok: true
		workspace: root
		active_pack: active
		fragments: fragments
		total_est_tokens: total
		notes: [
			'Token counts are provider-agnostic estimates (characters / 4), not a tokenizer result.',
			'This selection applies to future sessions only; running sessions keep the context they started with.',
			'A context pack shapes prompts; it is not a security boundary and selecting one installs or runs nothing.',
		]
	}
}

fn workspace_pack_paths(root string, dir string, depth int) []string {
	if depth > 4 || os.is_link(dir) {
		return []string{}
	}
	entries := os.ls(dir) or { return []string{} }
	mut paths := []string{}
	for entry in entries {
		path := os.join_path(dir, entry)
		if os.is_link(path) {
			continue
		}
		if os.is_dir(path) {
			paths << workspace_pack_paths(root, path, depth + 1)
		} else if entry.ends_with('.yaml') || entry.ends_with('.yml') {
			paths << pack_rel_path(root, path)
		}
		if paths.len > workspace_pack_count_limit {
			return paths
		}
	}
	paths.sort()
	return paths
}
