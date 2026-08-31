module agent_toolkit_core

import json
import os
import time

pub struct InsightsOptions {
pub:
	tool       string // opencode | cursor | claude | windsurf | all | copilot | codex (default: all)
	days       int    // 0 = no limit, else last N days (opencode, claude, windsurf)
	output     string // path to save HTML report (optional)
	json_mode  bool   // --json: output structured JSON
	no_llm     bool   // --no-llm: skip LLM analysis, raw stats only
}

pub struct InsightsReport {
pub mut:
	ok      bool
	message string
	data    map[string]string
}

// known_tools mirrors bin/tool-insights KNOWN_TOOLS plus alias "all"
// and future runners that report "no data" when no local store exists.
const known_insights_tools = ['opencode', 'cursor', 'claude', 'windsurf', 'all', 'copilot', 'codex', 'pi', 'muse']

pub fn insights_help_text() string {
	return 'insights — AI tool usage analytics (V re-port, thin wrapper over bin/tool-insights).

Usage:
  agent-toolkit insights [TOOL] [--days N] [--output PATH] [--json] [--no-llm]

TOOL can be one of:
  opencode   — OpenCode sessions (~/.local/share/opencode/opencode.db)
  cursor     — Cursor agent transcripts (~/.cursor/projects/)
  claude     — Claude Code JSONL sessions (~/.claude/projects/)
  windsurf   — Windsurf session data (~/.codeium/windsurf/ or ~/.windsurf/)
  copilot    — GitHub Copilot usage (no local store yet — reports "no data")
  codex      — Codex sessions (no local store yet — reports "no data")
  all        — Aggregate report across all available tools (default)

Options:
  --days N     Limit to last N days (opencode, claude, windsurf only)
  --output PATH  Save HTML report to PATH (else Markdown to stdout / HTML to ~/.claude/usage-data/)
  --json       Structured CommandResult JSON (tool, days, output, report paths)
  --no-llm    Skip LLM analysis; output raw JSON stats only (no ANTHROPIC_API_KEY needed)

Examples:
  agent-toolkit insights
  agent-toolkit insights opencode --days 30
  agent-toolkit insights claude --days 7 --output ~/claude-week.html
  agent-toolkit insights all --no-llm --json
'
}

fn find_tool_insights() string {
	// 1. toolkit checkout: <root>/bin/tool-insights (when running from source)
	if tr := find_toolkit_root() {
		if tr.path != 'embedded' {
			cand := os.join_path(tr.path, 'bin', 'tool-insights')
			if os.is_file(cand) {
				return cand
			}
			// also check repo root bin (legacy)
			cand2 := os.join_path(tr.path, '..', 'bin', 'tool-insights')
			if os.is_file(cand2) {
				return os.real_path(cand2)
			}
		}
	}
	// 2. installed location: ~/.ai-workspace/bin/tool-insights (harness)
	home := os.home_dir()
	cands := [
		os.join_path(home, '.ai-workspace', 'bin', 'tool-insights'),
		os.join_path(home, 'bin', 'tool-insights'),
		'/usr/local/bin/tool-insights',
	]
	for c in cands {
		if os.is_file(c) {
			return c
		}
	}
	// 3. PATH lookup
	if p := os.find_abs_path_of_executable('tool-insights') {
		if p.len > 0 {
			return p
		}
	}
	return ''
}

pub fn run_insights(opts InsightsOptions) InsightsReport {
	tool := if opts.tool.len > 0 { opts.tool.to_lower() } else { 'all' }
	if tool !in known_insights_tools {
		return InsightsReport{
			ok:      false
			message: 'Unknown insights tool `${tool}`. Valid: ${known_insights_tools.join(", ")}'
			data:    {
				'subcommand': 'insights'
				'tool':       tool
			}
		}
	}
	// tools with no local store yet — report "no data" without invoking Python
	if tool in ['copilot', 'codex', 'pi', 'muse'] {
		msg := 'No local usage data for `${tool}` yet. Supported with local stores: opencode, cursor, claude, windsurf, all. `${tool}` will report "no data" until a collector is added.'
		if opts.json_mode {
			return InsightsReport{
				ok:      true
				message: '{"tool":"${tool}","status":"no_data","message":${json.encode(msg)}}'
				data:    {
					'subcommand': 'insights'
					'tool':       tool
					'status':     'no_data'
				}
			}
		}
		return InsightsReport{
			ok:      true
			message: msg
			data:    {
				'subcommand': 'insights'
				'tool':       tool
				'status':     'no_data'
			}
		}
	}
	script := find_tool_insights()
	if script.len == 0 {
		return InsightsReport{
			ok:      false
			message: 'tool-insights not found. Expected at <toolkit>/bin/tool-insights or ~/.ai-workspace/bin/tool-insights. Install via `uv tool install agent-toolkit-cli` or check `docs/v/insights-migration.md`.'
			data:    {
				'subcommand': 'insights'
				'tool':       tool
			}
		}
	}
	mut argv := ['python3', script]
	// tool position: tool-insights expects positional TOOL(s)
	if tool != 'all' {
		argv << tool
	} else {
		// explicitly pass "all" so the script's default (all 4) is explicit in logs
		argv << 'all'
	}
	if opts.days > 0 {
		argv << '--days'
		argv << opts.days.str()
	}
	if opts.output.len > 0 {
		argv << '--output'
		argv << opts.output
	}
	if opts.no_llm {
		argv << '--no-llm'
	}
	// Always pass --json when caller wants structured output? tool-insights doesn't have --json,
	// but we can capture its stdout and wrap in our JSON.
	// For now, we rely on tool-insights' stdout/stderr and wrap it.
	ps := new_process_service()
	// Run with 120s timeout (LLM analysis can take a while)
	res := ps.run(RunOptions{
		argv:    argv
		timeout: 120 * time.second
	}) or {
		return InsightsReport{
			ok:      false
			message: 'failed to run tool-insights: ${err.msg()}'
			data:    {
				'subcommand': 'insights'
				'tool':       tool
			}
		}
	}
	if res.timed_out {
		return InsightsReport{
			ok:      false
			message: 'tool-insights timed out after 120s (tool=${tool})'
			data:    {
				'subcommand': 'insights'
				'tool':       tool
			}
		}
	}
	// tool-insights writes reports to ~/.claude/usage-data/ and prints paths; capture that
	mut out := ''
	if res.stdout.len > 0 {
		out += res.stdout.trim_space()
	}
	if res.stderr.len > 0 {
		if out.len > 0 {
			out += '\n'
		}
		out += res.stderr.trim_space()
	}
	if out.len == 0 {
		out = '(no output from tool-insights)'
	}
	if res.exit_code != 0 {
		return InsightsReport{
			ok:      false
			message: out
			data:    {
				'subcommand': 'insights'
				'tool':       tool
				'exit_code':  res.exit_code.str()
			}
		}
	}
	if opts.json_mode {
		// Wrap the text output in JSON for --json callers
		wrapped := json.encode({
			'tool':   tool
			'days':   opts.days.str()
			'output': opts.output
			'report': out
		})
		return InsightsReport{
			ok:      true
			message: wrapped
			data:    {
				'subcommand': 'insights'
				'tool':       tool
				'json':       wrapped
				'__raw_json': wrapped
			}
		}
	}
	return InsightsReport{
		ok:      true
		message: out
		data:    {
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
		ok:      report.ok
		message: report.message
		data:    data
	}
}
