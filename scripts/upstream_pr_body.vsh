#!/usr/bin/env -S v run
// upstream_pr_body.vsh — render the weekly upstream-sync PR body from apply
// summary JSON (V port of scripts/upstream_pr_body.py).
//
// Usage:
//   v run scripts/upstream_pr_body.vsh [--summary <json>]... [-o <out.md>]
import json
import os

struct Applied {
	capability    string
	source        string
	old_commit    string
	new_commit    string
	body_checksum string
}

struct Summary {
	applied []Applied
}

fn load_summary(paths []string) Summary {
	for p in paths {
		txt := os.read_file(p) or { continue }
		if dec := json.decode(Summary, txt) {
			return dec
		}
	}
	return Summary{}
}

fn short(s string, n int) string {
	return if s.len > n { s[..n] } else { s }
}

fn render(summary Summary) string {
	mut lines := ['## Summary', '',
		'Automated upstream sync via `scripts/provenance.py updates --apply`.',
		'Vendored `SKILL.md` bodies are byte-identical to upstream; only Toolkit',
		'frontmatter overlay differs. **Do not auto-merge.**', '', '## Updates', '']
	if summary.applied.len == 0 {
		lines << '_See workflow logs for details._'
	}
	for item in summary.applied {
		lines << '- `${item.capability}` / `${item.source}`: `${short(item.old_commit, 7)}` → `${short(item.new_commit, 7)}` (body `${short(item.body_checksum, 23)}…`)'
	}
	lines << ''
	lines << '## Reviewer checklist'
	lines << ''
	lines << '- [ ] Diff shows only expected upstream body/sibling changes + pin bumps'
	lines << '- [ ] License SPDX unchanged (or intentional license change reviewed)'
	lines << '- [ ] `security.*` surface still accurate (shell/network/mcp/hooks)'
	lines << '- [ ] Set `trust.tier: reviewed` and `trust.reviewed_provenance` to the new'
	lines << '      `provenance_digest` in each updated `SKILL.md` after audit'
	lines << '- [ ] `python3 scripts/provenance.py check` passes'
	lines << ''
	lines << '## Notes'
	lines << ''
	lines << '- Bot leaves `trust.tier: experimental` and drops `reviewed_provenance`.'
	lines << '- Offline CI (`validate-upstream`) must stay green without network.'
	lines << ''
	return lines.join('\n') + '\n'
}

fn main() {
	raw := os.args.clone()
	script_idx := raw.index('upstream_pr_body.vsh')
	args := if script_idx >= 0 { raw[script_idx + 1..] } else { raw[1..] }
	mut summaries := []string{}
	mut output := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		if a == '--summary' && i + 1 < args.len {
			summaries << args[i + 1]
			i += 2
		} else if (a == '-o' || a == '--output') && i + 1 < args.len {
			output = args[i + 1]
			i += 2
		} else {
			i++
		}
	}
	if summaries.len == 0 {
		summaries = ['/tmp/upstream-apply-summary.json', '/tmp/apply.json']
	}
	text := render(load_summary(summaries))
	if output != '' {
		os.write_file(output, text) or {
			eprintln('cannot write ${output}: ${err}')
			exit(1)
		}
	} else {
		print(text)
	}
}
