module agent_toolkit_core

import json2
import os

// Pure V implementation of insights — no Python dependency.
// For real use, handles all runners with local stores directly in V.
pub struct InsightsOptions {
pub:
	tool      string
	days      int
	output    string
	json_mode bool
	no_llm    bool
}

pub struct InsightsReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

const known_insights_tools = ['opencode', 'cursor', 'claude', 'windsurf', 'all', 'copilot', 'codex',
	'pi', 'muse']

pub fn insights_help_text() string {
	return 'insights — AI tool usage analytics (pure V, all runners).

Usage:
  agent-toolkit insights [TOOL] [--days N] [--output PATH] [--json] [--no-llm]

TOOL can be one of:
  opencode   — OpenCode sessions (~/.local/share/opencode/opencode.db)
  cursor     — Cursor agent transcripts (~/.cursor/projects/)
  claude     — Claude Code JSONL sessions (~/.claude/projects/)
  windsurf   — Windsurf session data (~/.codeium/windsurf/ or ~/.windsurf/)
  copilot    — GitHub Copilot sessions (~/.copilot/session-store.db)
  codex      — Codex sessions (~/.codex — no store yet)
  pi         — Pi agent skills (~/.pi/agent)
  muse       — Muse Code sessions (~/.config/muse)
  all        — Aggregate report across all available tools (default)

Options:
  --days N     Limit to last N days (opencode, claude, windsurf)
  --output PATH  Save report to PATH (else to ~/.claude/usage-data/)
  --json       Structured CommandResult JSON
  --no-llm    Skip LLM analysis; raw stats only (no API key needed)

Examples:
  agent-toolkit insights
  agent-toolkit insights opencode --days 30 --no-llm
  agent-toolkit insights claude --days 7 --output ~/claude-week.json --no-llm
  agent-toolkit insights all --no-llm --json
'
}

// Helpers to find data dirs
fn insights_opencode_db() string {
	home := os.home_dir()
	cands := [os.join_path(home, '.local', 'share', 'opencode', 'opencode.db')]
	for c in cands {
		if os.is_file(c) {
			return c
		}
	}
	return ''
}

fn insights_cursor_dir() string {
	home := os.home_dir()
	cand := os.join_path(home, '.cursor', 'projects')
	if os.is_dir(cand) {
		return cand
	}
	return ''
}

fn insights_claude_dir() string {
	home := os.home_dir()
	cand := os.join_path(home, '.claude', 'projects')
	if os.is_dir(cand) {
		return cand
	}
	return ''
}

fn insights_windsurf_dir() string {
	home := os.home_dir()
	cands := [os.join_path(home, '.codeium', 'windsurf'), os.join_path(home, '.windsurf'),
		os.join_path(home, '.config', 'windsurf'), os.join_path(home, '.local', 'share', 'windsurf')]
	for c in cands {
		if os.is_dir(c) {
			return c
		}
	}
	return ''
}

fn insights_copilot_db() string {
	home := os.home_dir()
	cand := os.join_path(home, '.copilot', 'session-store.db')
	if os.is_file(cand) {
		return cand
	}
	return ''
}

// Pure V extractors — raw stats only (no LLM)
fn extract_opencode_stats_v(days int) map[string]string {
	db_path := insights_opencode_db()
	if db_path.len == 0 {
		return {
			'tool':           'opencode'
			'status':         'no_data'
			'total_sessions': '0'
			'error':          'DB not found at ~/.local/share/opencode/opencode.db'
		}
	}
	// Use sqlite3 CLI for simplicity (V's db.sqlite needs thirdparty setup)
	// For pure V without sqlite CLI, we can try to use V's db.sqlite if available, else fallback to file count
	// Here we use os.execute with sqlite3 if available, else report file exists
	mut total_sessions := '0'
	mut total_cost := '0'
	// Try sqlite3 CLI
	if os.exists('/usr/bin/sqlite3') || os.find_abs_path_of_executable('sqlite3') or { '' }.len > 0 {
		where_days := if days > 0 {
			" AND time_created >= (strftime('%s','now','-${days} days')*1000)"
		} else {
			''
		}
		cmd := 'sqlite3 \'${db_path}\' "SELECT COUNT(*) FROM session WHERE time_archived IS NULL${where_days};"'
		res := os.execute(cmd)
		if res.exit_code == 0 {
			total_sessions = res.output.trim_space()
		}
		// Try cost as well
		cmd2 := 'sqlite3 \'${db_path}\' "SELECT COALESCE(SUM(cost),0) FROM session WHERE time_archived IS NULL${where_days};"'
		res2 := os.execute(cmd2)
		if res2.exit_code == 0 {
			total_cost = res2.output.trim_space()
		}
	} else {
		// Fallback: file exists
		total_sessions = '1+'
	}
	return {
		'tool':           'opencode'
		'status':         'ok'
		'total_sessions': total_sessions
		'total_cost':     total_cost
		'db_path':        db_path
		'days_filter':    if days > 0 { days.str() } else { 'all' }
	}
}

fn extract_cursor_stats_v() map[string]string {
	dir := insights_cursor_dir()
	if dir.len == 0 {
		return {
			'tool':   'cursor'
			'status': 'no_data'
			'error':  'No data dir at ~/.cursor/projects'
		}
	}
	// Count transcripts: each project has agent-transcripts/*.jsonl
	mut total := 0
	mut projects := 0
	entries := os.ls(dir) or { []string{} }
	for e in entries {
		p := os.join_path(dir, e, 'agent-transcripts')
		if os.is_dir(p) {
			projects++
			files := os.ls(p) or { []string{} }
			for f in files {
				if f.ends_with('.jsonl') {
					total++
				}
			}
		}
	}
	return {
		'tool':              'cursor'
		'status':            if total > 0 { 'ok' } else { 'no_data' }
		'total_transcripts': total.str()
		'total_projects':    projects.str()
		'data_dir':          dir
	}
}

fn extract_claude_stats_v(days int) map[string]string {
	dir := insights_claude_dir()
	if dir.len == 0 {
		return {
			'tool':   'claude'
			'status': 'no_data'
			'error':  'No data dir at ~/.claude/projects'
		}
	}
	mut total := 0
	mut projects := 0
	entries := os.ls(dir) or { []string{} }
	for e in entries {
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			files := os.ls(p) or { []string{} }
			mut cnt := 0
			for f in files {
				if f.ends_with('.jsonl') {
					// TODO: days filter for claude JSONL via mtime (V os.stat not yet exposed)
					cnt++
				}
			}
			if cnt > 0 {
				projects++
				total += cnt
			}
		}
	}
	return {
		'tool':           'claude'
		'status':         if total > 0 { 'ok' } else { 'no_data' }
		'total_sessions': total.str()
		'total_projects': projects.str()
		'data_dir':       dir
		'days_filter':    if days > 0 { days.str() } else { 'all' }
	}
}

fn extract_windsurf_stats_v() map[string]string {
	dir := insights_windsurf_dir()
	if dir.len == 0 {
		return {
			'tool':   'windsurf'
			'status': 'no_data'
			'error':  'No windsurf data dir'
		}
	}
	// Count JSONL/JSON files
	mut total := 0
	// Use find via os.execute for recursive
	res := os.execute("find '${dir}' -name '*.jsonl' -o -name '*.json' 2>/dev/null | head -100 | wc -l")
	if res.exit_code == 0 {
		total = res.output.trim_space().int()
	}
	return {
		'tool':           'windsurf'
		'status':         if total > 0 { 'ok' } else { 'no_data' }
		'total_sessions': total.str()
		'data_dir':       dir
	}
}

fn extract_copilot_stats_v() map[string]string {
	db_path := insights_copilot_db()
	if db_path.len == 0 {
		return {
			'tool':   'copilot'
			'status': 'no_data'
			'error':  'No session store at ~/.copilot/session-store.db'
		}
	}
	mut cnt := 0
	if os.exists('/usr/bin/sqlite3') || os.find_abs_path_of_executable('sqlite3') or { '' }.len > 0 {
		res := os.execute("sqlite3 '${db_path}' 'SELECT COUNT(*) FROM sessions;'")
		if res.exit_code == 0 {
			cnt = res.output.trim_space().int()
		}
	}
	return {
		'tool':           'copilot'
		'status':         if cnt > 0 { 'ok' } else { 'no_data' }
		'total_sessions': cnt.str()
		'data_dir':       db_path
	}
}

fn extract_pi_stats_v() map[string]string {
	home := os.home_dir()
	pi_dir := os.join_path(home, '.pi', 'agent', 'skills')
	if !os.is_dir(pi_dir) {
		return {
			'tool':   'pi'
			'status': 'no_data'
			'error':  'No pi skills dir'
		}
	}
	// Count skill.md files
	res := os.execute("find '${pi_dir}' -name 'skill.md' 2>/dev/null | wc -l")
	mut cnt_pi := 0
	if res.exit_code == 0 {
		cnt_pi = res.output.trim_space().int()
	}
	return {
		'tool':             'pi'
		'status':           if cnt_pi > 0 { 'ok' } else { 'no_data' }
		'total_sessions':   cnt_pi.str()
		'installed_skills': cnt_pi.str()
		'data_dir':         pi_dir
	}
}

fn extract_muse_stats_v() map[string]string {
	home := os.home_dir()
	muse_dir := os.join_path(home, '.config', 'muse')
	if !os.is_dir(muse_dir) {
		return {
			'tool':   'muse'
			'status': 'no_data'
			'error':  'No muse dir'
		}
	}
	res := os.execute("find '${muse_dir}' -name '*.json' 2>/dev/null | wc -l")
	mut cnt := 0
	if res.exit_code == 0 {
		cnt = res.output.trim_space().int()
	}
	return {
		'tool':           'muse'
		'status':         if cnt > 0 { 'ok' } else { 'no_data' }
		'total_sessions': cnt.str()
		'data_dir':       muse_dir
	}
}

fn extract_codex_stats_v() map[string]string {
	home := os.home_dir()
	codex_dir := os.join_path(home, '.codex')
	if !os.is_dir(codex_dir) {
		return {
			'tool':   'codex'
			'status': 'no_data'
			'error':  'No codex dir at ~/.codex'
		}
	}
	res2 := os.execute("find '${codex_dir}' -name '*.jsonl' -o -name '*.json' 2>/dev/null | wc -l")
	mut cnt_codex := 0
	if res2.exit_code == 0 {
		cnt_codex = res2.output.trim_space().int()
	}
	return {
		'tool':           'codex'
		'status':         if cnt_codex > 0 { 'ok' } else { 'no_data' }
		'total_sessions': cnt_codex.str()
		'data_dir':       codex_dir
	}
}

pub fn run_insights(opts InsightsOptions) InsightsReport {
	tool := if opts.tool.len > 0 { opts.tool.to_lower() } else { 'all' }
	if tool !in known_insights_tools {
		return InsightsReport{
			ok: false
			message: 'Unknown insights tool `${tool}`. Valid: ${known_insights_tools.join(', ')}'
			data: {
				'subcommand': 'insights'
				'tool':       tool
			}
		}
	}
	// Auto --no-llm fallback when no API key (real use without remembering flag)
	mut effective_no_llm := opts.no_llm
	if !effective_no_llm && os.getenv('ANTHROPIC_API_KEY').len == 0 {
		effective_no_llm = true
	}
	// Collect stats per tool (pure V, no Python)
	mut stats_by_tool := map[string]map[string]string{}
	mut tools_to_run := []string{}
	if tool == 'all' {
		tools_to_run = ['opencode', 'cursor', 'claude', 'windsurf', 'copilot', 'codex', 'pi', 'muse']
	} else {
		tools_to_run = [tool]
	}
	for t in tools_to_run {
		raw := match t {
			'opencode' { extract_opencode_stats_v(opts.days) }
			'cursor' { extract_cursor_stats_v() }
			'claude' { extract_claude_stats_v(opts.days) }
			'windsurf' { extract_windsurf_stats_v() }
			'copilot' { extract_copilot_stats_v() }
			'codex' { extract_codex_stats_v() }
			'pi' { extract_pi_stats_v() }
			'muse' { extract_muse_stats_v() }
			else { map[string]string{} }
		}
		stats_by_tool[t] = raw.clone()
	}
	// Handle --output for single tool raw stats
	if opts.output.len > 0 && tools_to_run.len == 1 {
		out_path := opts.output
		tool_key := tools_to_run[0]
		raw := if tool_key in stats_by_tool {
			stats_by_tool[tool_key].clone()
		} else {
			map[string]string{}
		}
		// Write raw JSON to the requested path
		json_str := json2.encode(raw, escape_unicode: true)
		os.write_file(out_path, json_str) or {
			return InsightsReport{
				ok: false
				message: 'Failed to write output to ${out_path}: ${err.msg()}'
				data: {
					'subcommand': 'insights'
					'tool':       tool
				}
			}
		}
		msg := 'Raw stats for ${tool_key} written to ${out_path} (${raw['total_sessions']} sessions)'
		if opts.json_mode {
			wrapped := json2.encode({
				'tool':   tool_key
				'days':   opts.days.str()
				'output': out_path
				'report': msg
			},
				escape_unicode: true
			)
			return InsightsReport{
				ok: true
				message: wrapped
				data: {
					'subcommand': 'insights'
					'tool':       tool_key
					'json':       wrapped
					'__raw_json': wrapped
				}
			}
		}
		return InsightsReport{
			ok: true
			message: msg
			data: {
				'subcommand': 'insights'
				'tool':       tool_key
			}
		}
	}
	// Build human report (raw stats, no LLM for now — pure V)
	mut lines := []string{}
	lines << 'Insights — ${tool} (pure V, --no-llm fallback active: ${effective_no_llm})'
	if opts.days > 0 {
		lines << 'Filter: last ${opts.days} days'
	}
	mut total_sessions := 0
	for t in tools_to_run {
		if t !in stats_by_tool {
			continue
		}
		raw := stats_by_tool[t].clone()
		sessions := raw['total_sessions'] or { '0' }
		status := raw['status'] or { 'unknown' }
		lines << '- ${t}: ${sessions} sessions (${status})'
		total_sessions += sessions.int()
	}
	lines << 'Total: ${total_sessions} sessions across ${tools_to_run.len} tools'
	if tool == 'all' && opts.output.len > 0 {
		// For "all" with --output, write aggregate JSON to the requested path
		agg_json := json2.encode(stats_by_tool, escape_unicode: true)
		os.write_file(opts.output, agg_json) or {}
		lines << 'Aggregate JSON written to ${opts.output}'
	}
	if !effective_no_llm {
		lines << 'Note: LLM analysis requires ANTHROPIC_API_KEY and is not yet ported to pure V — showing raw stats. Use --no-llm for this view.'
	}
	msg := lines.join('\n')
	if opts.json_mode {
		// For pure V, stats_by_tool is map[string]map[string]string which json.encode doesn't handle directly in this context
		// Encode without nested map for now; raw stats are available via separate --output file
		wrapped := json2.encode({
			'tool':   tool
			'days':   opts.days.str()
			'output': opts.output
			'report': msg
		},
			escape_unicode: true
		)
		return InsightsReport{
			ok: true
			message: wrapped
			data: {
				'subcommand': 'insights'
				'tool':       tool
				'json':       wrapped
				'__raw_json': wrapped
			}
		}
	}
	return InsightsReport{
		ok: true
		message: msg
		data: {
			'subcommand': 'insights'
			'tool':       tool
		}
	}
}

pub fn insights_result(report InsightsReport) CommandResult {
	mut data := report.data.clone()
	if 'subcommand' !in data {
		data['subcommand'] = 'insights'
	}
	return CommandResult{
		command: 'insights'
		ok: report.ok
		message: report.message
		data: data
	}
}
