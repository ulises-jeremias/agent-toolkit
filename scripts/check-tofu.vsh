#!/usr/bin/env -S v run
// check-tofu.vsh — tofu detector for desktop golden fixtures (#1111).
//
// Two deterministic guards (no OCR heuristics):
//
// 1. Bundled-fonts proof: the app must have booted with the EMBEDDED fonts
//   (`fonts: dir=...assets/fonts` in tests/golden-app.log). System fallback
//   fonts change glyph metrics and are the actual tofu vector for the CJK and
//   Arabic chrome — a capture without this line proves nothing.
// 2. Fixture sanity: all 26 fixtures (paper + ink) must exist and exceed a
//   minimum byte size, catching black/empty/truncated captures.
//
// Usage: ./scripts/check-tofu.vsh   (from repo root or any subdir)
// Exit status is non-zero with a diagnostic on the first failure.

import os

const min_bytes = 20 * 1024

fn repo_root() string {
	mut d := os.dir(@FILE)
	// scripts/ -> repo root
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn fixture_list() []string {
	mut paper := []string{}
	for i in 0 .. 10 {
		num := if i < 10 { '0${i}' } else { '${i}' }
		paper << 'tests/golden/panel-${num}.png'
	}
	paper << 'tests/golden/panel-products.png'
	paper << 'tests/golden/panel-insights.png'
	paper << 'tests/golden/panel-onboarding.png'
	mut all := paper.clone()
	for p in paper {
		all << 'tests/golden/ink/' + os.file_name(p)
	}
	return all
}

fn fail(msg string) int {
	println('TOFU FAIL: ${msg}')
	return 1
}

fn main() {
	root := repo_root()
	log := os.join_path(root, 'tests', 'golden-app.log')
	// NOTE: message still names golden.sh until the Phase C migration renames it.
	app_log := os.read_file(log) or { exit(fail('app log missing: ${log} (run scripts/golden.sh first)')) }
	mut font_lines := []string{}
	for line in app_log.split_into_lines() {
		if line.contains('fonts: dir=') {
			font_lines << line
		}
	}
	if font_lines.len == 0 {
		exit(fail('no "fonts: dir=" line in app log — capture did not prove bundled fonts'))
	}
	last := font_lines.last()
	// `fonts: dir=<path> ...` — first whitespace-separated field after the key.
	after := last.split('fonts: dir=')[1]
	fields := after.split(' ')
	if fields.len == 0 || !fields[0].trim_right('/').ends_with('assets/fonts') {
		exit(fail('fonts not bundled: ${last[..if last.len > 160 { 160 } else { last.len }]}'))
	}
	println('tofu fonts OK — ${last[..if last.len > 120 { 120 } else { last.len }]}')
	mut missing := []string{}
	mut tiny := []string{}
	for rel in fixture_list() {
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
		exit(fail('${missing.len} fixtures missing: ${missing[..if missing.len > 5 { 5 } else { missing.len }]}'))
	}
	if tiny.len > 0 {
		exit(fail('${tiny.len} fixtures suspiciously small: ${tiny[..if tiny.len > 5 { 5 } else { tiny.len }]}'))
	}
	println('tofu fixtures OK — ${fixture_list().len} present, all >= ${min_bytes}B')
	println('TOFU PASS')
}
