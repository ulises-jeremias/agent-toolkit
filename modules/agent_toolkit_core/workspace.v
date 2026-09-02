module agent_toolkit_core

import x.json2
import os
import time

const workspace_subs = ['init', 'context', 'sync', 'use-persona', 'handoff', 'history', 'personas',
	'load', 'profiles', 'validate', 'budget']

const workspace_missing = 'Error: workspace not found.
Set AGENT_TOOLKIT_WORKSPACE or run from inside a workspace directory.'

// WorkspaceOptions configures the workspace command family (#520).
pub struct WorkspaceOptions {
pub:
	subcommand     string
	dir            string
	name           string
	workspace_path string
	explain        bool
	json_out       bool
	arg            string // persona, pack path, history count, validate surface
	profile        string
	pack           string
}

// WorkspaceReport is the domain result for workspace subcommands.
pub struct WorkspaceReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

// run_workspace implements init/context/sync and remaining family commands.
pub fn run_workspace(opts WorkspaceOptions) WorkspaceReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return WorkspaceReport{
			ok: true
			message: workspace_help_text()
			data: {
				'subcommand': 'help'
			}
		}
	}
	return match sub {
		'init' { workspace_init(opts) }
		'context' { workspace_context(opts) }
		'sync' { workspace_sync(opts) }
		'use-persona' { workspace_use_persona(opts) }
		'handoff' { workspace_handoff(opts) }
		'history' { workspace_history(opts) }
		'personas' { workspace_personas(opts) }
		'load' { workspace_load(opts) }
		'profiles' { workspace_profiles(opts) }
		'validate' { workspace_validate(opts) }
		'budget' { workspace_budget(opts) }
		else {
			WorkspaceReport{
				ok: false
				message: "Unknown workspace subcommand: ${sub}\nRun 'agent-toolkit workspace --help' for usage."
				data: {
					'subcommand': sub
				}
			}
		}
	}
}

// workspace_result maps WorkspaceReport to CommandResult.
pub fn workspace_result(report WorkspaceReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = ''
	}
	return CommandResult{
		command: 'workspace'
		ok: report.ok
		message: report.message
		data: data
	}
}

// workspace_help_text is the family usage (Python cli/workspace.py module docstring).
pub fn workspace_help_text() string {
	return 'workspace — AI workspace scaffolding, session context, and persona management.

Usage:
    agent-toolkit workspace <subcommand> [args]

Subcommands:
    init [--dir PATH] [--name NAME]        Scaffold a new harness workspace
    context [--workspace PATH]             Output a session state snapshot
    sync [--workspace PATH]                Sync loop escalations into todos
    use-persona <name>                     Activate a work mode persona
    handoff <name>                         Transition to another persona (validates rules)
    history [count]                        Show recent persona transitions
    personas                               List available personas
    load <pack.yaml>                       Load a context pack
    load --profile <name>                  Load a composable profile (pack + persona)
    profiles                               List available profiles
    validate [surface]                     Validate workspace schema integrity
    budget [--pack NAME] [--profile NAME]  Analyze context footprint
    budget --json [--pack NAME] [--profile NAME]  Machine-readable output

Options:
    --help    Show this help message
'
}

fn workspace_init(opts WorkspaceOptions) WorkspaceReport {
	mut target := if opts.dir.len > 0 { opts.dir } else { os.getwd() }
	if opts.name.len > 0 {
		target = os.join_path(target, opts.name)
	}
	os.mkdir_all(target) or {
		return WorkspaceReport{
			ok: false
			message: 'failed to create workspace: ${err}'
		}
	}
	mut created := []string{}
	mut skipped := []string{}
	files := {
		'AGENTS.md':                      workspace_agents_md
		'.gitignore':                     workspace_gitignore
		'knowledge/README.md':            workspace_knowledge_readme
		'knowledge/learnings/general.md': workspace_learnings_general
		'knowledge/todos/pending.md':     workspace_todos_pending
		'packs/README.md':                workspace_packs_readme
		'personas/implementer.md':        workspace_persona_implementer
		'personas/reviewer.md':           workspace_persona_reviewer
		'personas/researcher.md':         workspace_persona_researcher
		'personas/architect.md':          workspace_persona_architect
	}
	mut keys := files.keys()
	keys.sort()
	for rel in keys {
		path := os.join_path(target, rel)
		if os.exists(path) {
			skipped << rel
			continue
		}
		os.mkdir_all(os.dir(path)) or {
			return WorkspaceReport{
				ok: false
				message: 'mkdir failed: ${err}'
			}
		}
		os.write_file(path, files[rel]) or {
			return WorkspaceReport{
				ok: false
				message: 'write failed: ${err}'
			}
		}
		created << rel
	}
	for d in ['projects', 'repos'] {
		os.mkdir_all(os.join_path(target, d)) or {}
		gitkeep := os.join_path(target, d, '.gitkeep')
		if !os.exists(gitkeep) {
			os.write_file(gitkeep, '') or {}
			created << '${d}/.gitkeep'
		}
	}
	mut lines := []string{}
	lines << ''
	lines << 'Workspace initialized: ${target}'
	lines << ''
	for rel in created {
		lines << '  ++  ${rel}'
	}
	for rel in skipped {
		lines << '  skip  ${rel} (already exists)'
	}
	lines << ''
	lines << 'Next steps:'
	lines << '  cd ${target}'
	lines << '  agent-toolkit workspace context'
	lines << '  agent-toolkit project clone owner/my-repo'
	lines << ''
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'init'
			'path':       target
			'created':    '${created.len}'
		}
	}
}

fn missing_workspace(sub string) WorkspaceReport {
	return WorkspaceReport{
		ok: false
		message: workspace_missing
		data: {
			'subcommand': sub
		}
	}
}

fn workspace_context(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace('context') }
	now := time.utc()
	knowledge := os.join_path(ws, 'knowledge')
	projects_dir := os.join_path(ws, 'projects')
	loops_dir := os.join_path(ws, 'loops')
	active_pack_file := os.join_path(ws, '.active-pack')
	active_persona_file := os.join_path(ws, '.active-persona')
	agents_md := os.join_path(ws, 'AGENTS.md')
	spec := if os.is_file(agents_md) { file_digest(agents_md) } else { '' }
	ks := knowledge_summary(knowledge)
	pack_ref := read_strip(active_pack_file)
	persona_name := read_strip(active_persona_file)
	mut data := {
		'subcommand': 'context'
		'workspace':  ws
		'timestamp':  now.format_rfc3339()
		'learnings':  '${ks.learnings}'
		'todos':      '${ks.todos}'
		'processes':  '${ks.processes}'
		'pack':       pack_ref
		'persona':    persona_name
		'spec':       if spec.len > 0 { 'AGENTS.md@${spec}' } else { '' }
	}
	if opts.json_out {
		mut lines := []string{}
		lines << '{'
		lines << '  "workspace": "${workspace_json_escape(ws)}",'
		lines << '  "timestamp": "${workspace_json_escape(now.format_rfc3339())}",'
		lines << '  "sources": {'
		if pack_ref.len > 0 {
			psz := approx_size(resolve_pack_abs(ws, pack_ref))
			lines << '    "pack": {"path": "${workspace_json_escape(pack_ref)}", "size_bytes": ${psz}},'
		} else {
			lines << '    "pack": null,'
		}
		if persona_name.len > 0 {
			psz := approx_size(os.join_path(ws, 'personas', '${persona_name}.md'))
			lines << '    "persona": {"name": "${workspace_json_escape(persona_name)}", "size_bytes": ${psz}},'
		} else {
			lines << '    "persona": null,'
		}
		lines << '    "knowledge": {"learnings": ${ks.learnings}, "todos": ${ks.todos}, "processes": ${ks.processes}}'
		lines << '  }'
		if spec.len > 0 {
			lines << '  ,"spec": "AGENTS.md@${spec}"'
		}
		lines << '}'
		return WorkspaceReport{
			ok: true
			message: lines.join('\n')
			data: data
		}
	}
	mut lines := []string{}
	lines << ''
	lines << '=== AI Workspace — Session Context ==='
	lines << ''
	rfc := now.format_rfc3339()
	date_s := if rfc.len >= 16 { '${rfc[..10]} ${rfc[11..16]} UTC' } else { rfc }
	lines << 'Date      : ${date_s}'
	lines << 'Workspace : ${ws}'
	lines << ''
	branch := git_branch(ws)
	if branch.len > 0 {
		lines << 'Branch    : ${branch}'
		lines << ''
	}
	lines << '── Projects ──────────────────────────────────────────────'
	proj_n := 0
	mut pn := 0
	if os.is_dir(projects_dir) {
		entries := os.ls(projects_dir) or { []string{} }
		mut names := entries.clone()
		names.sort()
		for name in names {
			p := os.join_path(projects_dir, name)
			if os.is_link(p) {
				target := os.readlink(p) or { '' }
				status := if os.exists(os.real_path(p)) { 'ok' } else { 'broken' }
				lines << '  [${status}]  ${name} -> ${target}'
				pn++
			}
		}
		if pn == 0 {
			lines << '  (no projects indexed — run: agent-toolkit project clone owner/repo)'
		}
	} else {
		lines << '  (projects/ directory not found)'
	}
	_ = proj_n
	lines << ''
	lines << '── Pending Todos ──────────────────────────────────────────'
	todos_path := os.join_path(knowledge, 'todos', 'pending.md')
	if os.is_file(todos_path) {
		content := os.read_file(todos_path) or { '' }
		mut unchecked := []string{}
		for line in content.split_into_lines() {
			if line.starts_with('- [ ]') {
				unchecked << line
			}
		}
		if unchecked.len == 0 {
			lines << '  (no pending todos)'
		} else {
			limit := if unchecked.len < 10 { unchecked.len } else { 10 }
			for i in 0 .. limit {
				lines << '  ${unchecked[i]}'
			}
			if unchecked.len > 10 {
				lines << '  ... and ${unchecked.len - 10} more'
			}
		}
	} else {
		lines << '  (no todos file)'
	}
	lines << ''
	lines << '── Recent Learnings ───────────────────────────────────────'
	learnings_path := os.join_path(knowledge, 'learnings', 'general.md')
	if os.is_file(learnings_path) {
		content := os.read_file(learnings_path) or { '' }
		mut rows := []string{}
		for line in content.split_into_lines() {
			if line.starts_with('| ') && line.len > 6 && line[2].is_digit() {
				rows << line
			}
		}
		if rows.len == 0 {
			lines << '  (no learnings recorded yet)'
		} else {
			limit := if rows.len < 3 { rows.len } else { 3 }
			for i in 0 .. limit {
				lines << '  ${rows[i]}'
			}
		}
	} else {
		lines << '  (no learnings file)'
	}
	lines << ''
	if os.is_dir(loops_dir) {
		lines << '── Loop Status ────────────────────────────────────────────'
		entries := os.ls(loops_dir) or { []string{} }
		mut loop_names := []string{}
		for e in entries {
			if os.is_dir(os.join_path(loops_dir, e)) {
				loop_names << e
			}
		}
		loop_names.sort()
		if loop_names.len == 0 {
			lines << '  (no loops configured)'
		} else {
			for loop_name in loop_names {
				state_file := os.join_path(loops_dir, loop_name, 'STATE.md')
				mut last_run := '(no STATE.md)'
				if os.is_file(state_file) {
					content := os.read_file(state_file) or { '' }
					for line in content.split_into_lines() {
						d := first_iso_date(line)
						if d.len > 0 {
							last_run = d
							break
						}
					}
				}
				lines << '  ${loop_name} last: ${last_run}'
			}
		}
		lines << ''
	}
	if pack_ref.len > 0 {
		lines << '── Active Pack ────────────────────────────────────────────'
		lines << '  ${pack_ref}'
		notes := pack_notes(ws, pack_ref)
		if notes.len > 0 {
			lines << ''
			for line in notes.split_into_lines() {
				lines << '  ${line}'
			}
		}
		lines << ''
	}
	if persona_name.len > 0 {
		lines << '── Active Persona ─────────────────────────────────────────'
		lines << '  Persona: ${persona_name}'
		lines << ''
		meta := load_persona_meta(ws, persona_name)
		if meta.ok {
			lines << format_persona_constraints(persona_name, meta)
		}
		lines << ''
	}
	skills_text := read_strip(os.join_path(ws, '.active-skills'))
	if skills_text.len > 0 {
		lines << '── Active Skills ─────────────────────────────────────────'
		for s in skills_text.split_into_lines() {
			if s.trim_space().len > 0 {
				lines << '  - ${s.trim_space()}'
			}
		}
		lines << ''
	}
	loops_text := read_strip(os.join_path(ws, '.active-loops'))
	if loops_text.len > 0 {
		lines << '── Active Loops ──────────────────────────────────────────'
		for ln in loops_text.split_into_lines() {
			if ln.trim_space().len > 0 {
				lines << '  - ${ln.trim_space()}'
			}
		}
		lines << ''
	}
	if spec.len > 0 {
		lines << 'Spec      : AGENTS.md@${spec}'
		lines << ''
	}
	if opts.explain {
		lines << context_explain(ws, pack_ref, persona_name, knowledge, agents_md, ks)
	}
	lines << '──────────────────────────────────────────────────────────'
	lines << ''
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: data
	}
}

fn workspace_sync(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	loops_dir := os.join_path(ws, 'loops')
	todos_path := os.join_path(ws, 'knowledge', 'todos', 'pending.md')
	if !os.is_dir(loops_dir) {
		return WorkspaceReport{
			ok: true
			message: 'No loops/ directory found — nothing to sync.'
			data: {
				'subcommand': 'sync'
				'added':      '0'
			}
		}
	}
	today := time.utc().format_rfc3339()[..10]
	todos_content := if os.is_file(todos_path) { os.read_file(todos_path) or { '' } } else { '' }
	mut new_todos := []string{}
	entries := os.ls(loops_dir) or { []string{} }
	mut names := entries.clone()
	names.sort()
	for loop_name in names {
		loop_dir := os.join_path(loops_dir, loop_name)
		if !os.is_dir(loop_dir) {
			continue
		}
		for candidate in ['report.md', 'STATE.md', 'request.md'] {
			report := os.join_path(loop_dir, candidate)
			if !os.is_file(report) {
				continue
			}
			content := os.read_file(report) or { continue }
			for line in content.split_into_lines() {
				low := line.to_lower()
				if !low.contains('escalat') && !low.contains('action required') && !low.contains('todo:') && !low.contains('follow-up:') {
					continue
				}
				mut clean := line.trim_space().trim_left('#')
				clean = clean.trim_space().trim_left('-').trim_space().trim_left('>').trim_space()
				if clean.len < 10 {
					continue
				}
				todo_line := '- [ ] ${today} - [loop:${loop_name}] ${clean}'
				if todos_content.contains(todo_line) || todo_line in new_todos {
					continue
				}
				new_todos << todo_line
			}
		}
	}
	if new_todos.len == 0 {
		return WorkspaceReport{
			ok: true
			message: 'No escalations found in loop reports.'
			data: {
				'subcommand': 'sync'
				'added':      '0'
			}
		}
	}
	os.mkdir_all(os.dir(todos_path)) or {}
	marker := '<!-- Add pending items with date added -->'
	mut new_content := ''
	if todos_content.contains(marker) {
		idx := todos_content.index(marker) or { -1 }
		if idx >= 0 {
			end := idx + marker.len
			insert := '\n' + new_todos.join('\n')
			new_content = todos_content[..end] + insert + todos_content[end..]
		}
	} else {
		new_content = todos_content + '\n' + new_todos.join('\n') + '\n'
	}
	os.write_file(todos_path, new_content) or {
		return WorkspaceReport{
			ok: false
			message: 'failed to write todos: ${err}'
		}
	}
	mut lines := []string{}
	lines << 'Synced ${new_todos.len} escalation(s) into knowledge/todos/pending.md'
	for t in new_todos {
		lines << '  ${t}'
	}
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'sync'
			'added':      '${new_todos.len}'
		}
	}
}

fn workspace_use_persona(opts WorkspaceOptions) WorkspaceReport {
	if opts.arg.len == 0 {
		return WorkspaceReport{
			ok: false
			message: 'Usage: agent-toolkit workspace use-persona <name>'
		}
	}
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	persona := opts.arg
	path := persona_path(ws, persona)
	if !os.is_file(path) {
		list := workspace_personas(opts)
		return WorkspaceReport{
			ok: false
			message: 'Persona not found: ${persona}\n${list.message}'
		}
	}
	active := os.join_path(ws, '.active-persona')
	from_persona := read_strip(active)
	ts := time.utc().format_rfc3339()
	if from_persona.len > 0 && from_persona != persona {
		append_persona_history(ws, '${ts} transition: ${from_persona} → ${persona}')
	} else if from_persona.len == 0 {
		append_persona_history(ws, '${ts} activate: → ${persona}')
	}
	os.write_file(active, persona + '\n') or {
		return WorkspaceReport{
			ok: false
			message: 'failed to write persona: ${err}'
		}
	}
	return WorkspaceReport{
		ok: true
		message: 'Activated persona: ${persona}'
		data: {
			'subcommand': 'use-persona'
			'persona':    persona
		}
	}
}

fn workspace_handoff(opts WorkspaceOptions) WorkspaceReport {
	if opts.arg.len == 0 {
		return WorkspaceReport{
			ok: false
			message: 'Usage: agent-toolkit workspace handoff <name>'
		}
	}
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	to_persona := opts.arg
	active := os.join_path(ws, '.active-persona')
	if !os.is_file(active) {
		return WorkspaceReport{
			ok: false
			message: "No active persona to handoff from. Use 'workspace use-persona <name>' first."
		}
	}
	from_persona := read_strip(active)
	if !os.is_file(persona_path(ws, to_persona)) {
		list := workspace_personas(opts)
		return WorkspaceReport{
			ok: false
			message: 'Target persona not found: ${to_persona}\n${list.message}'
		}
	}
	meta := load_persona_meta(ws, from_persona)
	if meta.handoff_to.len > 0 && to_persona !in meta.handoff_to {
		mut allowed := meta.handoff_to.clone()
		allowed.sort()
		return WorkspaceReport{
			ok: false
			message: "Invalid handoff from '${from_persona}' to '${to_persona}'. Allowed targets: ${allowed.join(', ')}"
		}
	}
	ts := time.utc().format_rfc3339()
	append_persona_history(ws, '${ts} handoff: ${from_persona} → ${to_persona}')
	os.write_file(active, to_persona + '\n') or {
		return WorkspaceReport{
			ok: false
			message: 'failed to write persona: ${err}'
		}
	}
	return WorkspaceReport{
		ok: true
		message: 'Handoff: ${from_persona} → ${to_persona}'
		data: {
			'subcommand': 'handoff'
			'persona':    to_persona
		}
	}
}

fn workspace_history(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	mut count := 10
	if opts.arg.len > 0 {
		count = opts.arg.int()
		if count <= 0 {
			count = 10
		}
	}
	history_file := os.join_path(ws, '.persona-history')
	if !os.is_file(history_file) {
		if opts.json_out {
			return WorkspaceReport{
				ok: true
				message: json2.encode([]string{}, escape_unicode: true)
				data: {
					'subcommand': 'history'
					'count':      '0'
				}
			}
		}
		return WorkspaceReport{
			ok: true
			message: 'No persona transitions recorded yet.'
			data: {
				'subcommand': 'history'
			}
		}
	}
	lines := os.read_file(history_file) or { '' }
	all := lines.split_into_lines().filter(it.len > 0)
	start := if all.len > count { all.len - count } else { 0 }
	recent := all[start..]
	if opts.json_out {
		return WorkspaceReport{
			ok: true
			message: json2.encode(recent, escape_unicode: true)
			data: {
				'subcommand': 'history'
				'count':      '${recent.len}'
			}
		}
	}
	mut out := []string{}
	out << 'Recent persona transitions (last ${recent.len}):'
	out << ''
	for line in recent {
		out << '  ${line}'
	}
	return WorkspaceReport{
		ok: true
		message: out.join('\n')
		data: {
			'subcommand': 'history'
			'count':      '${recent.len}'
		}
	}
}

fn workspace_personas(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	dir := os.join_path(ws, 'personas')
	if opts.json_out {
		if !os.is_dir(dir) {
			return WorkspaceReport{
				ok: true
				message: json2.encode([]string{}, escape_unicode: true)
				data: {
					'subcommand': 'personas'
					'count':      '0'
				}
			}
		}
		entries := os.ls(dir) or { []string{} }
		mut names := []string{}
		for e in entries {
			if e.ends_with('.md') {
				names << e.all_before_last('.md')
			}
		}
		names.sort()
		if names.len == 0 {
			return WorkspaceReport{
				ok: true
				message: json2.encode([]string{}, escape_unicode: true)
				data: {
					'subcommand': 'personas'
					'count':      '0'
				}
			}
		}
		mut items := []string{}
		for name in names {
			meta := load_persona_meta(ws, name)
			// build JSON object manually to ensure proper escaping
			mut allow_json := '['
			for i, a in meta.allow {
				if i > 0 {
					allow_json += ','
				}
				allow_json += '"${workspace_json_escape(a)}"'
			}
			allow_json += ']'
			mut deny_json := '['
			for i, d in meta.deny {
				if i > 0 {
					deny_json += ','
				}
				deny_json += '"${workspace_json_escape(d)}"'
			}
			deny_json += ']'
			mut handoffs_json := '['
			for i, h in meta.handoff_to {
				if i > 0 {
					handoffs_json += ','
				}
				handoffs_json += '"${workspace_json_escape(h)}"'
			}
			handoffs_json += ']'
			fmt_json := '"${workspace_json_escape(meta.output_format)}"'
			items << '{"name":"${workspace_json_escape(name)}","allow":${allow_json},"deny":${deny_json},"format":${fmt_json},"handoffs":${handoffs_json}}'
		}
		json_msg := '[' + items.join(',') + ']'
		return WorkspaceReport{
			ok: true
			message: json_msg
			data: {
				'subcommand': 'personas'
				'count':      '${names.len}'
			}
		}
	}
	mut lines := []string{}
	lines << '── Available Personas ─────────────────────────────────────'
	if !os.is_dir(dir) {
		lines << '  (no personas directory)'
		lines << ''
		return WorkspaceReport{
			ok: true
			message: lines.join('\n')
			data: {
				'subcommand': 'personas'
			}
		}
	}
	entries := os.ls(dir) or { []string{} }
	mut names := []string{}
	for e in entries {
		if e.ends_with('.md') {
			names << e.all_before_last('.md')
		}
	}
	names.sort()
	if names.len == 0 {
		lines << '  (no personas defined)'
	} else {
		for name in names {
			meta := load_persona_meta(ws, name)
			allow_s := if meta.allow.len > 0 { meta.allow.join(', ') } else { '-' }
			deny_s := if meta.deny.len > 0 { meta.deny.join(', ') } else { '-' }
			fmt_s := if meta.output_format.len > 0 { meta.output_format } else { '-' }
			lines << '  ${name} allow=[${allow_s}] deny=[${deny_s}] format=${fmt_s}'
		}
	}
	lines << ''
	lines << 'Usage: agent-toolkit workspace use-persona <name>'
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'personas'
			'count':      '${names.len}'
		}
	}
}

fn workspace_load(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	if opts.profile.len > 0 {
		return workspace_load_profile(ws, opts.profile)
	}
	if opts.arg.len == 0 {
		return WorkspaceReport{
			ok: false
			message: 'Usage: agent-toolkit workspace load <pack-path> | --profile <name>'
		}
	}
	return workspace_load_pack(ws, opts.arg)
}

fn workspace_load_pack(ws string, pack_arg string) WorkspaceReport {
	pack_path := resolve_pack_file(ws, pack_arg) or {
		mut msg := 'Pack not found: ${pack_arg}'
		packs_dir := os.join_path(ws, 'packs')
		if os.is_dir(packs_dir) {
			avail := list_yaml_rel(ws, packs_dir)
			if avail.len > 0 {
				msg += '\n\nAvailable packs:\n'
				for item in avail {
					msg += '  ${item}\n'
				}
			}
		}
		return WorkspaceReport{
			ok: false
			message: msg
		}
	}
	rel := pack_rel_path(ws, pack_path)
	os.write_file(os.join_path(ws, '.active-pack'), rel + '\n') or {
		return WorkspaceReport{
			ok: false
			message: 'failed to write pack: ${err}'
		}
	}
	text := os.read_file(pack_path) or { '' }
	desc := yaml_string_field(text, 'description')
	mut lines := []string{}
	lines << 'Loaded pack: ${rel}'
	if desc.len > 0 {
		lines << '  ${desc}'
	}
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'load'
			'pack':       rel
		}
	}
}

fn workspace_load_profile(ws string, profile_name string) WorkspaceReport {
	profile_path := os.join_path(ws, 'profiles', '${profile_name}.yaml')
	if !os.is_file(profile_path) {
		return WorkspaceReport{
			ok: false
			message: 'Profile not found: ${profile_name}\nLooked in: ${profile_path}'
		}
	}
	text := os.read_file(profile_path) or { '' }
	os.write_file(os.join_path(ws, '.active-profile'), profile_name + '\n') or {}
	mut lines := []string{}
	lines << 'Profile loaded: ${profile_name}'
	desc := yaml_string_field(text, 'description')
	if desc.len > 0 {
		lines << '  ${desc}'
	}
	pack_ref := yaml_string_field(text, 'pack')
	if pack_ref.len > 0 {
		pack_path := resolve_pack_file(ws, pack_ref) or {
			lines << "  (pack '${pack_ref}' not found — skipped)"
			return WorkspaceReport{
				ok: true
				message: lines.join('\n')
				data: {
					'subcommand': 'load'
					'profile':    profile_name
				}
			}
		}
		rel := pack_rel_path(ws, pack_path)
		os.write_file(os.join_path(ws, '.active-pack'), rel + '\n') or {}
		lines << '  Pack: ${rel}'
	}
	persona := yaml_string_field(text, 'persona')
	if persona.len > 0 {
		if !os.is_file(persona_path(ws, persona)) {
			lines << "  (persona '${persona}' not found — skipped)"
		} else {
			active := os.join_path(ws, '.active-persona')
			from_persona := read_strip(active)
			ts := time.utc().format_rfc3339()
			if from_persona.len > 0 && from_persona != persona {
				append_persona_history(ws, '${ts} profile: ${from_persona} → ${persona}')
			} else if from_persona.len == 0 {
				append_persona_history(ws, '${ts} profile: → ${persona}')
			}
			os.write_file(active, persona + '\n') or {}
			lines << '  Persona: ${persona}'
		}
	}
	skills := yaml_string_list(text, 'skills')
	if skills.len > 0 {
		os.write_file(os.join_path(ws, '.active-skills'), skills.join('\n') + '\n') or {}
		lines << '  Skills: ${skills.join(', ')}'
	}
	loops := yaml_string_list(text, 'loops')
	if loops.len > 0 {
		os.write_file(os.join_path(ws, '.active-loops'), loops.join('\n') + '\n') or {}
		lines << '  Loops: ${loops.join(', ')}'
	}
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'load'
			'profile':    profile_name
		}
	}
}

fn workspace_profiles(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	dir := os.join_path(ws, 'profiles')
	mut lines := []string{}
	lines << '── Available Profiles ─────────────────────────────────────'
	if !os.is_dir(dir) {
		lines << '  (no profiles/ directory)'
		lines << ''
		return WorkspaceReport{
			ok: true
			message: lines.join('\n')
			data: {
				'subcommand': 'profiles'
			}
		}
	}
	entries := os.ls(dir) or { []string{} }
	mut names := []string{}
	for e in entries {
		if e.ends_with('.yaml') {
			names << e
		}
	}
	names.sort()
	if names.len == 0 {
		lines << '  (no profiles defined)'
	} else {
		for e in names {
			path := os.join_path(dir, e)
			text := os.read_file(path) or { '' }
			name := yaml_string_field(text, 'name')
			shown := if name.len > 0 { name } else { e.all_before_last('.yaml') }
			pack := yaml_string_field(text, 'pack')
			persona := yaml_string_field(text, 'persona')
			pack_s := if pack.len > 0 { pack } else { '-' }
			persona_s := if persona.len > 0 { persona } else { '-' }
			lines << '  ${shown} pack=${pack_s} persona=${persona_s}'
			desc := yaml_string_field(text, 'description')
			if desc.len > 0 {
				lines << '    ${desc}'
			}
		}
	}
	lines << ''
	lines << 'Usage: agent-toolkit workspace load --profile <name>'
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'profiles'
			'count':      '${names.len}'
		}
	}
}

fn workspace_validate(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	surface := if opts.arg.len > 0 { opts.arg } else { 'all' }
	valid := ['all', 'packs', 'loops', 'personas', 'profiles', 'knowledge', 'jobs']
	if surface !in valid {
		return WorkspaceReport{
			ok: false
			message: 'Unknown surface: ${surface}\nValid surfaces: all, packs, loops, personas, profiles, knowledge, jobs'
		}
	}
	surfaces := if surface == 'all' {
		['packs', 'loops', 'personas', 'profiles', 'knowledge', 'jobs']
	} else {
		[surface]
	}
	mut lines := []string{}
	lines << ''
	lines << 'Context Validation'
	lines << '------------------'
	mut all_errors := []string{}
	for name in surfaces {
		lines << 'Validating ${name}/ ...'
		errs := match name {
			'packs' { validate_packs(ws) }
			'loops' { validate_loops(ws) }
			'personas' { validate_personas(ws) }
			'profiles' { validate_profiles(ws) }
			'knowledge' { validate_knowledge(ws) }
			'jobs' { validate_jobs(ws) }
			else { []string{} }
		}
		if errs.len > 0 {
			for err in errs {
				lines << '  ✗  ${err}'
			}
			all_errors << errs
		} else {
			lines << '  ✓  ${name}/ OK'
		}
	}
	lines << ''
	if all_errors.len > 0 {
		lines << '  ${all_errors.len} violation(s) found.'
		return WorkspaceReport{
			ok: false
			message: lines.join('\n')
			data: {
				'subcommand': 'validate'
				'errors':     '${all_errors.len}'
			}
		}
	}
	lines << '  All context files valid.'
	lines << ''
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: {
			'subcommand': 'validate'
			'errors':     '0'
		}
	}
}

fn workspace_budget(opts WorkspaceOptions) WorkspaceReport {
	ws := find_workspace_root(opts.workspace_path) or { return missing_workspace(opts.subcommand) }
	mut sections := []BudgetSection{}
	agents := os.join_path(ws, 'AGENTS.md')
	if os.is_file(agents) {
		sections << budget_section('agents', 'AGENTS.md', agents)
	}
	knowledge := os.join_path(ws, 'knowledge')
	if os.is_dir(knowledge) {
		sections << budget_section('knowledge', 'knowledge/', knowledge)
	}
	pack_ref := if opts.pack.len > 0 {
		opts.pack
	} else {
		read_strip(os.join_path(ws, '.active-pack'))
	}
	if pack_ref.len > 0 {
		p := resolve_pack_abs(ws, pack_ref)
		if os.exists(p) {
			sections << budget_section('pack', 'pack ${pack_ref}', p)
		}
	}
	persona := if opts.profile.len > 0 {
		yaml_string_field(os.read_file(os.join_path(ws, 'profiles', '${opts.profile}.yaml')) or { '' }, 'persona')
	} else {
		read_strip(os.join_path(ws, '.active-persona'))
	}
	if persona.len > 0 {
		pp := persona_path(ws, persona)
		if os.is_file(pp) {
			sections << budget_section('persona', 'persona ${persona}', pp)
		}
	}
	mut total := 0
	for s in sections {
		total += s.chars
	}
	tokens := total / 4
	risk := if tokens > 40000 {
		'HIGH'
	} else if tokens > 20000 {
		'MEDIUM'
	} else {
		'LOW'
	}
	target := if opts.profile.len > 0 {
		'profile:${opts.profile}'
	} else if opts.pack.len > 0 {
		'pack:${opts.pack}'
	} else {
		'workspace'
	}
	mut data := {
		'subcommand':       'budget'
		'workspace':        ws
		'target':           target
		'total_chars':      '${total}'
		'estimated_tokens': '${tokens}'
		'risk':             risk
	}
	if opts.json_out {
		mut lines := []string{}
		lines << '{'
		lines << '  "workspace": "${workspace_json_escape(ws)}",'
		lines << '  "target": "${workspace_json_escape(target)}",'
		lines << '  "total_chars": ${total},'
		lines << '  "estimated_tokens": ${tokens},'
		lines << '  "risk": "${risk}",'
		lines << '  "sections": ['
		for i, s in sections {
			comma := if i + 1 < sections.len { ',' } else { '' }
			lines << '    {"kind": "${s.kind}", "label": "${workspace_json_escape(s.label)}", "chars": ${s.chars}, "estimated_tokens": ${s.tokens}, "path": "${workspace_json_escape(s.path)}"}${comma}'
		}
		lines << '  ],'
		lines << '  "warnings": [],'
		lines << '  "suggestions": []'
		lines << '}'
		return WorkspaceReport{
			ok: true
			message: lines.join('\n')
			data: data
		}
	}
	mut lines := []string{}
	lines << ''
	lines << 'Context Budget Analysis'
	lines << '-----------------------'
	lines << ''
	lines << '  Workspace : ${ws}'
	lines << '  Target    : ${target}'
	lines << '  Footprint : ${total} chars (~${tokens} tokens)'
	lines << '  Risk      : ${risk}'
	lines << ''
	if sections.len > 0 {
		lines << '  Breakdown:'
		lines << ''
		for s in sections {
			lines << '    ${s.label}  ${s.chars} chars  ~${s.tokens} tokens'
		}
		lines << ''
	}
	return WorkspaceReport{
		ok: true
		message: lines.join('\n')
		data: data
	}
}

struct KnowledgeCounts {
	learnings int
	todos     int
	processes int
}

struct PersonaMeta {
	ok            bool
	allow         []string
	deny          []string
	output_format string
	handoff_to    []string
}

struct BudgetSection {
	kind   string
	label  string
	chars  int
	tokens int
	path   string
}

fn knowledge_summary(knowledge string) KnowledgeCounts {
	return KnowledgeCounts{
		learnings: count_files(os.join_path(knowledge, 'learnings'))
		todos: count_files(os.join_path(knowledge, 'todos'))
		processes: count_files(os.join_path(knowledge, 'processes'))
	}
}

fn count_files(dir string) int {
	if !os.is_dir(dir) {
		return 0
	}
	mut n := 0
	entries := os.ls(dir) or { return 0 }
	for e in entries {
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			n += count_files(p)
		} else {
			n++
		}
	}
	return n
}

fn approx_size(path string) int {
	if os.is_file(path) {
		return int(os.file_size(path))
	}
	if !os.is_dir(path) {
		return 0
	}
	mut total := 0
	entries := os.ls(path) or { return 0 }
	for e in entries {
		total += approx_size(os.join_path(path, e))
	}
	return total
}

fn budget_section(kind string, label string, path string) BudgetSection {
	chars := approx_size(path)
	return BudgetSection{
		kind: kind
		label: label
		chars: chars
		tokens: chars / 4
		path: path
	}
}

fn read_strip(path string) string {
	if !os.is_file(path) {
		return ''
	}
	return os.read_file(path) or { '' }.trim_space()
}

fn persona_path(ws string, name string) string {
	return os.join_path(ws, 'personas', '${name}.md')
}

fn append_persona_history(ws string, line string) {
	path := os.join_path(ws, '.persona-history')
	prev := if os.is_file(path) { os.read_file(path) or { '' } } else { '' }
	os.write_file(path, prev + line + '\n') or {}
}

fn extract_frontmatter(content string) string {
	lines := content.split_into_lines()
	if lines.len == 0 || lines[0].trim_space() != '---' {
		return ''
	}
	for i := 1; i < lines.len; i++ {
		if lines[i].trim_space() == '---' {
			return lines[1..i].join('\n')
		}
	}
	return ''
}

fn load_persona_meta(ws string, name string) PersonaMeta {
	path := persona_path(ws, name)
	if !os.is_file(path) {
		return PersonaMeta{}
	}
	text := os.read_file(path) or { return PersonaMeta{} }
	fm := extract_frontmatter(text)
	if fm.len == 0 {
		return PersonaMeta{}
	}
	return PersonaMeta{
		ok: true
		allow: yaml_string_list(fm, 'allow')
		deny: yaml_string_list(fm, 'deny')
		output_format: yaml_string_field(fm, 'output_format')
		handoff_to: yaml_to_fields(fm)
	}
}

fn yaml_to_fields(text string) []string {
	mut out := []string{}
	mut in_handoffs := false
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('handoffs:') {
			in_handoffs = true
			continue
		}
		if in_handoffs && t.len > 0 && !line.starts_with(' ') && !line.starts_with('\t') && !t.starts_with('-') {
			break
		}
		if in_handoffs && t.starts_with('to:') {
			v := t.all_after('to:').trim_space().trim('"')
			if v.len > 0 {
				out << v
			}
		}
	}
	return out
}

fn yaml_string_field(text string, key string) string {
	prefix := '${key}:'
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with(prefix) {
			v := t.all_after(prefix).trim_space()
			if v == '|' || v == '>' {
				continue
			}
			return v.trim('"').trim("'")
		}
	}
	return ''
}

fn yaml_string_list(text string, key string) []string {
	mut out := []string{}
	mut in_list := false
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('${key}:') {
			rest := t.all_after('${key}:').trim_space()
			in_list = true
			if rest.len > 0 && rest != '|' {
				return out
			}
			continue
		}
		if in_list {
			if t.starts_with('- ') {
				out << t[2..].trim_space().trim('"')
				continue
			}
			if t.len > 0 && !line.starts_with(' ') && !line.starts_with('\t') {
				break
			}
		}
	}
	return out
}

fn format_persona_constraints(name string, meta PersonaMeta) string {
	mut lines := []string{}
	lines << '  <persona-constraints>'
	lines << '    persona: ${name}'
	if meta.allow.len > 0 {
		lines << '    allow: [${meta.allow.join(', ')}]'
	}
	if meta.deny.len > 0 {
		lines << '    deny: [${meta.deny.join(', ')}]'
	}
	if meta.output_format.len > 0 {
		lines << '    output_format: ${meta.output_format}'
	}
	if meta.handoff_to.len > 0 {
		lines << '    handoffs:'
		for to in meta.handoff_to {
			lines << '        to: ${to}'
		}
	}
	lines << '  </persona-constraints>'
	return lines.join('\n')
}

fn pack_notes(ws string, pack_ref string) string {
	p := resolve_pack_abs(ws, pack_ref)
	if !os.is_file(p) {
		return ''
	}
	return yaml_string_field(os.read_file(p) or { '' }, 'notes')
}

fn resolve_pack_abs(ws string, pack_ref string) string {
	if os.is_abs_path(pack_ref) {
		return pack_ref
	}
	return os.join_path(ws, pack_ref)
}

fn resolve_pack_file(ws string, pack_arg string) ?string {
	if os.is_abs_path(pack_arg) {
		if os.is_file(pack_arg) {
			return pack_arg
		}
		return none
	}
	for rel in [pack_arg, os.join_path('packs', pack_arg), os.join_path('packs', '${pack_arg}.yaml')] {
		p := os.join_path(ws, rel)
		if os.is_file(p) {
			return p
		}
	}
	return none
}

fn pack_rel_path(ws string, pack_path string) string {
	if pack_path.starts_with(ws + os.path_separator) {
		return pack_path[ws.len + 1..]
	}
	return pack_path
}

fn list_yaml_rel(ws string, dir string) []string {
	mut out := []string{}
	entries := os.ls(dir) or { return out }
	for e in entries {
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			out << list_yaml_rel(ws, p)
		} else if e.ends_with('.yaml') {
			out << pack_rel_path(ws, p)
		}
	}
	out.sort()
	return out
}

fn validate_packs(ws string) []string {
	mut errors := []string{}
	dir := os.join_path(ws, 'packs')
	if !os.is_dir(dir) {
		return errors
	}
	for rel in list_yaml_rel(ws, dir) {
		text := os.read_file(os.join_path(ws, rel)) or {
			errors << '${os.file_name(rel)}: unreadable'
			continue
		}
		name := os.file_name(rel)
		if yaml_string_field(text, 'name').len == 0 {
			errors << "${name}: missing required field 'name'"
		}
		if yaml_string_field(text, 'description').len == 0 {
			errors << "${name}: missing required field 'description'"
		}
	}
	return errors
}

fn validate_loops(ws string) []string {
	mut errors := []string{}
	dir := os.join_path(ws, 'loops')
	if !os.is_dir(dir) {
		return errors
	}
	entries := os.ls(dir) or { return errors }
	for e in entries {
		loop_dir := os.join_path(dir, e)
		if !os.is_dir(loop_dir) {
			continue
		}
		loop_md := os.join_path(loop_dir, 'LOOP.md')
		if !os.is_file(loop_md) {
			continue
		}
		fm := extract_frontmatter(os.read_file(loop_md) or { '' })
		if fm.len == 0 {
			errors << '${e}/LOOP.md: missing or invalid frontmatter'
			continue
		}
		for field in ['name', 'tier', 'cadence', 'request'] {
			if yaml_string_field(fm, field).len == 0 {
				errors << "${e}/LOOP.md: missing required field '${field}'"
			}
		}
	}
	return errors
}

fn validate_personas(ws string) []string {
	mut errors := []string{}
	dir := os.join_path(ws, 'personas')
	if !os.is_dir(dir) {
		return errors
	}
	entries := os.ls(dir) or { return errors }
	for e in entries {
		if !e.ends_with('.md') {
			continue
		}
		fm := extract_frontmatter(os.read_file(os.join_path(dir, e)) or { '' })
		if fm.len == 0 {
			errors << '${e}: missing or invalid YAML frontmatter'
		}
	}
	return errors
}

fn validate_profiles(ws string) []string {
	mut errors := []string{}
	dir := os.join_path(ws, 'profiles')
	if !os.is_dir(dir) {
		return errors
	}
	entries := os.ls(dir) or { return errors }
	allowed := ['name', 'description', 'pack', 'persona', 'skills', 'loops']
	for e in entries {
		if !e.ends_with('.yaml') {
			continue
		}
		text := os.read_file(os.join_path(dir, e)) or {
			errors << '${e}: unreadable'
			continue
		}
		pack_ref := yaml_string_field(text, 'pack')
		if pack_ref.len > 0 {
			resolve_pack_file(ws, pack_ref) or {
				errors << "${e}: referenced pack '${pack_ref}' not found"
			}
		}
		persona := yaml_string_field(text, 'persona')
		if persona.len > 0 && !os.is_file(persona_path(ws, persona)) {
			errors << "${e}: referenced persona '${persona}' not found"
		}
		for line in text.split_into_lines() {
			t := line.trim_space()
			if t.len == 0 || t.starts_with('#') || t.starts_with('-') {
				continue
			}
			if t.contains(':') && !line.starts_with(' ') && !line.starts_with('\t') {
				key := t.all_before(':')
				if key.len > 0 && key !in allowed {
					errors << "${e}: unknown profile key '${key}'"
				}
			}
		}
	}
	return errors
}

fn validate_knowledge(ws string) []string {
	mut errors := []string{}
	knowledge := os.join_path(ws, 'knowledge')
	if !os.is_dir(knowledge) {
		errors << 'knowledge/: directory not found'
		return errors
	}
	for sub in ['learnings', 'todos', 'processes'] {
		if !os.is_dir(os.join_path(knowledge, sub)) {
			errors << 'knowledge/${sub}/: required directory missing'
		}
	}
	return errors
}

fn validate_jobs(ws string) []string {
	mut errors := []string{}
	dir := os.join_path(ws, 'templates', 'jobs')
	if !os.is_dir(dir) {
		return errors
	}
	entries := os.ls(dir) or { return errors }
	for e in entries {
		if !e.ends_with('.yaml') {
			continue
		}
		text := os.read_file(os.join_path(dir, e)) or {
			errors << '${e}: unreadable'
			continue
		}
		for field in ['name', 'request'] {
			if yaml_string_field(text, field).len == 0 {
				errors << "${e}: missing required field '${field}'"
			}
		}
	}
	return errors
}

fn context_explain(ws string, pack_ref string, persona_name string, knowledge string, agents_md string, ks KnowledgeCounts) string {
	mut lines := []string{}
	lines << ''
	lines << '── Composition Sources ────────────────────────────────────'
	if pack_ref.len > 0 {
		p := resolve_pack_abs(ws, pack_ref)
		status := if os.exists(p) { 'found' } else { 'missing' }
		sz := approx_size(p)
		lines << '  pack      : [${status}] ${pack_ref} (${sz} B)'
	} else {
		lines << '  pack      : (none active)'
	}
	if persona_name.len > 0 {
		p := persona_path(ws, persona_name)
		status := if os.is_file(p) { 'found' } else { 'missing' }
		sz := approx_size(p)
		lines << '  persona   : [${status}] ${persona_name} (${sz} B)'
	} else {
		lines << '  persona   : (none active)'
	}
	kstatus := if os.is_dir(knowledge) { 'present' } else { 'missing' }
	ksz := approx_size(knowledge)
	lines << '  knowledge : ${kstatus} (${ksz} B) (learnings=${ks.learnings}, todos=${ks.todos}, processes=${ks.processes})'
	if os.is_file(agents_md) {
		lines << '  AGENTS.md : found (${approx_size(agents_md)} B)'
	} else {
		lines << '  AGENTS.md : (none)'
	}
	lines << ''
	lines << '  Budget analysis: see #335'
	lines << ''
	return lines.join('\n')
}

fn git_branch(ws string) string {
	ps := new_process_service()
	res := ps.run(RunOptions{
		argv: ['git', '-C', ws, 'rev-parse', '--abbrev-ref', 'HEAD']
		timeout: 5 * time.second
	}) or { return '' }
	if res.exit_code != 0 {
		return ''
	}
	return res.stdout.trim_space()
}

fn first_iso_date(line string) string {
	// YYYY-MM-DD
	for i := 0; i + 10 <= line.len; i++ {
		if line[i].is_digit() && line[i + 4] == `-` && line[i + 7] == `-` {
			cand := line[i..i + 10]
			if cand[0].is_digit() && cand[1].is_digit() && cand[2].is_digit() && cand[3].is_digit() && cand[5].is_digit() && cand[6].is_digit() && cand[8].is_digit() && cand[9].is_digit() {
				return cand
			}
		}
	}
	return ''
}

fn workspace_json_escape(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
}
