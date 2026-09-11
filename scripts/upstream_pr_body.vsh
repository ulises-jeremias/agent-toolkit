#!/usr/bin/env -S v run
// Render the weekly upstream-sync PR body from apply summary JSON.
//
// Usage: ./scripts/upstream_pr_body.vsh [--summary PATH]... [-o OUTPUT]
//   (from repo root or any subdir; first readable summary wins,
//   stdout by default)

import os
import x.json2

struct UpdateItem {
	capability    string
	source        string
	old_commit    string
	new_commit    string
	body_checksum string
}

struct Summary {
	applied []UpdateItem
}

// first_n mirrors Python's `str(x or '')[:n]` — never panics on short input.
fn first_n(s string, n int) string {
	if s.len <= n {
		return s
	}
	return s[..n]
}

fn load_summary(paths []string) Summary {
	for p in paths {
		if !os.is_file(p) {
			continue
		}
		text := os.read_file(p) or { continue }
		// A corrupt summary is skipped like the retired .py did
		// (JSONDecodeError → next candidate). x.json2: `json` is deprecated.
		data := json2.decode[Summary](text) or { continue }
		return data
	}
	return Summary{}
}

fn render(summary Summary) string {
	mut lines := [
		'## Summary',
		'',
		'Automated upstream sync via `scripts/provenance.py updates --apply`.',
		'Vendored `SKILL.md` bodies are byte-identical to upstream; only Toolkit',
		'frontmatter overlay differs. **Do not auto-merge.**',
		'',
		'## Updates',
		'',
	]
	if summary.applied.len == 0 {
		lines << '_See workflow logs for details._'
	}
	for item in summary.applied {
		lines << '- `${item.capability}` / `${item.source}`: ' + '`${first_n(item.old_commit, 7)}` → ' + '`${first_n(item.new_commit, 7)}` ' + '(body `${first_n(item.body_checksum, 23)}…`)'
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
	mut summaries := []string{}
	mut output := ''
	mut args := os.args.clone()
	// os.args[0] is the script path under `v run` — only parse real flags.
	if args.len > 0 && args[0].ends_with('.vsh') {
		args = args[1..].clone()
	}
	mut i := 0
	for i < args.len {
		match args[i] {
			'--summary' {
				if i + 1 < args.len {
					summaries << args[i + 1]
					i += 2
				} else {
					i++
				}
			}
			'-o', '--output' {
				if i + 1 < args.len {
					output = args[i + 1]
					i += 2
				} else {
					i++
				}
			}
			else {
				i++
			}
		}
	}
	if summaries.len == 0 {
		summaries = ['/tmp/upstream-apply-summary.json', '/tmp/apply.json']
	}
	text := render(load_summary(summaries))
	if output.len > 0 {
		os.write_file(output, text) or {
			eprintln('cannot write ${output}: ${err}')
			exit(1)
		}
	} else {
		// print() would append a second newline — render already ends with one.
		os.stdout().write_string(text) or {
			eprintln('cannot write stdout: ${err}')
			exit(1)
		}
	}
}
