#!/usr/bin/env -S v run
// check-tofu.vsh — tofu detector for desktop golden fixtures, #1111 (V port
// of scripts/check-tofu.py).
//
// Two deterministic guards (no OCR heuristics):
//
// 1. Bundled-fonts proof: the app must have booted with the EMBEDDED fonts
//   (``fonts: dir=...assets/fonts`` in tests/golden-app.log). System fallback
//   fonts change glyph metrics and are the actual tofu vector for the CJK and
//   Arabic chrome — a capture without this line proves nothing.
// 2. Fixture sanity: all 26 fixtures (paper + ink) must exist and exceed a
//   minimum byte size, catching black/empty/truncated captures.
//
// Usage: v run scripts/check-tofu.vsh
// Exit status is non-zero with a diagnostic on the first failure.
import os

const min_bytes = 20 * 1024

fn paper_fixtures() []string {
	mut out := []string{}
	for i in 0 .. 10 {
		out << 'tests/golden/panel-${i:02d}.png'
	}
	out << 'tests/golden/panel-products.png'
	out << 'tests/golden/panel-insights.png'
	out << 'tests/golden/panel-onboarding.png'
	return out
}

fn fail(msg string) int {
	println('TOFU FAIL: ${msg}')
	return 1
}

fn run() int {
	root := os.dir(os.dir(os.real_path(@FILE)))
	log := os.join_path(root, 'tests', 'golden-app.log')
	app_log := os.read_file(log) or {
		return fail('app log missing: ${log} (run scripts/golden.vsh first)')
	}
	mut font_lines := []string{}
	for line in app_log.split('\n') {
		if line.contains('fonts: dir=') {
			font_lines << line
		}
	}
	if font_lines.len == 0 {
		return fail('no "fonts: dir=" line in app log — capture did not prove bundled fonts')
	}
	mut bundled := false
	for line in font_lines {
		after := line.all_after('fonts: dir=').split(' ')[0].trim_right('/')
		if after.ends_with('assets/fonts') {
			bundled = true
			break
		}
	}
	if !bundled {
		last := font_lines.last()
		return fail('fonts not bundled: ${last[..if last.len > 160 { 160 } else { last.len }]}')
	}
	last := font_lines.last()
	println("tofu fonts OK — ${last[..if last.len > 120 { 120 } else { last.len }]}")
	paper := paper_fixtures()
	mut ink := []string{}
	for p in paper {
		ink << 'tests/golden/ink/' + os.base(p)
	}
	mut missing := []string{}
	mut tiny := []string{}
	mut all := paper.clone()
	all << ink
	for rel in all {
		path := os.join_path(root, rel)
		if !os.is_file(path) {
			missing << rel
			continue
		}
		size := os.file_size(path)
		if size < min_bytes {
			tiny << '${rel} (${size}B)'
		}
	}
	if missing.len > 0 {
		return fail('${missing.len} fixtures missing: ${missing[..if missing.len > 5 { 5 } else { missing.len }]}')
	}
	if tiny.len > 0 {
		return fail('${tiny.len} fixtures suspiciously small: ${tiny[..if tiny.len > 5 { 5 } else { tiny.len }]}')
	}
	println('tofu fixtures OK — ${paper.len + ink.len} present, all >= ${min_bytes}B')
	println('TOFU PASS')
	return 0
}

fn main() {
	exit(run())
}
