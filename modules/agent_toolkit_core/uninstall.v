module agent_toolkit_core

import os

// uninstall_tool_targets maps CLI tool names to receipt target ids (Python uninstall.py).
pub const uninstall_tool_targets = {
	'claude-code': 'claude-code'
	'cursor':      'cursor'
	'opencode':    'opencode'
	'copilot':     'copilot'
	'windsurf':    'windsurf'
	'pi':          'pi'
	'muse-code':   'muse-code'
}

// UninstallOptions configures receipt-based uninstall / rollback.
pub struct UninstallOptions {
pub:
	tools       []string
	dry_run     bool
	receipt_dir string // empty → default_receipt_dir()
}

// UninstallReport summarizes uninstall outcomes.
pub struct UninstallReport {
pub mut:
	ok              bool
	message         string
	tools_processed int
	files_removed   int
	skipped         int
	failures        []string
}

// run_uninstall removes toolkit-owned (`created`) artifacts from install receipts.
// Skips `merged` ownership. Deletes the receipt file when not dry_run.
pub fn run_uninstall(opts UninstallOptions) UninstallReport {
	dir := if opts.receipt_dir.len > 0 { opts.receipt_dir } else { default_receipt_dir() }
	mut tools := opts.tools.clone()
	if tools.len == 0 {
		tools = discover_uninstall_tools(dir)
	}
	mut report := UninstallReport{
		ok: true
	}
	if tools.len == 0 {
		report.ok = false
		report.message = 'No install receipts found. Nothing to uninstall.'
		return report
	}
	mut lines := []string{}
	lines << 'agent-toolkit uninstall'
	if opts.dry_run {
		lines << '  [info]  DRY RUN — no files will be deleted'
	}
	for tool in tools {
		target := uninstall_tool_targets[tool] or {
			report.ok = false
			report.failures << tool
			lines << '  ✗  Unknown tool: ${tool}'
			continue
		}
		tool_ok, tool_lines, removed, skipped := uninstall_one_tool(tool, target, dir, opts.dry_run)
		lines << tool_lines
		report.tools_processed++
		report.files_removed += removed
		report.skipped += skipped
		if !tool_ok {
			report.ok = false
			report.failures << tool
		}
	}
	report.message = lines.join('\n')
	return report
}

// discover_uninstall_tools finds tools with profiles receipts under receipt_dir.
pub fn discover_uninstall_tools(receipt_dir string) []string {
	dir := if receipt_dir.len > 0 { receipt_dir } else { default_receipt_dir() }
	mut found := []string{}
	if !os.is_dir(dir) {
		return found
	}
	suffix := '-${profiles_product}.json'
	entries := os.ls(dir) or { return found }
	for e in entries.sorted() {
		if !e.ends_with(suffix) {
			continue
		}
		target := e[..e.len - suffix.len]
		for tool, receipt_target in uninstall_tool_targets {
			if receipt_target == target && tool !in found {
				found << tool
			}
		}
	}
	found.sort()
	return found
}

fn uninstall_one_tool(tool string, target string, receipt_dir string, dry_run bool) (bool, string, int, int) {
	mut lines := []string{}
	receipt := load_install_receipt(target, profiles_product, receipt_dir) or {
		lines << '  -  No receipt for ${tool} — nothing to uninstall'
		return true, lines.join('\n'), 0, 0
	}
	lines << '  [info]  Uninstalling ${tool} (${receipt.artifacts.len} artifact(s) from receipt)'
	mut removed := 0
	mut skipped := 0
	for entry in receipt.artifacts {
		if entry.ownership != 'created' {
			lines << '  -  Skipping non-owned file (${entry.ownership}): ${entry.path}'
			skipped++
			continue
		}
		if receipt_path_escapes(entry.path) {
			lines << '  ✗  Refused path escape: ${entry.path}'
			return false, lines.join('\n'), removed, skipped
		}
		if !os.exists(entry.path) {
			lines << '  -  Already absent: ${entry.path}'
			skipped++
			continue
		}
		if dry_run {
			lines << '  [dry]   Would remove: ${entry.path}'
			removed++
			continue
		}
		os.rm(entry.path) or {
			lines << '  ✗  Failed to remove ${entry.path}: ${err}'
			return false, lines.join('\n'), removed, skipped
		}
		lines << '  ✓  Removed: ${entry.path}'
		removed++
	}
	if !dry_run {
		receipt_path := os.join_path(receipt_dir, receipt_filename(target, profiles_product))
		if os.is_file(receipt_path) {
			os.rm(receipt_path) or {
				lines << '  ✗  Failed to remove receipt: ${err}'
				return false, lines.join('\n'), removed, skipped
			}
			lines << '  ✓  Removed receipt: ${receipt_path}'
		}
	}
	lines << '  [info]  ${tool}: processed ${removed} owned file(s)'
	return true, lines.join('\n'), removed, skipped
}

// uninstall_result maps a report to CommandResult.
pub fn uninstall_result(report UninstallReport) CommandResult {
	return CommandResult{
		command: 'uninstall'
		ok:      report.ok
		message: report.message
		data:    {
			'tools_processed': '${report.tools_processed}'
			'files_removed':   '${report.files_removed}'
			'skipped':         '${report.skipped}'
			'failures':        report.failures.join(',')
			'dry_run':         if report.message.contains('DRY RUN') { 'true' } else { 'false' }
		}
	}
}
