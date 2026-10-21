module agent_toolkit_core

import os
import time
import json2

// Live model catalogue (Pack A task 5, ADR-040): the static
// swarm_model_profiles() map goes stale silently — a model retired by a
// provider only failed at spawn time. Runners whose CLI can list its own
// models are probed live (argv only, no shell), cached on disk for 60 s,
// and any failure falls back to the static profiles. Runners without a
// list command report source 'static' honestly instead of pretending.

pub struct LiveModelInfo {
pub:
	runner string
	model  string
	name   string
}

pub struct LiveModelsResponse {
pub:
	ok     bool
	runner string
	// 'live' | 'static' | 'unavailable'
	source string
	models []LiveModelInfo
	detail string
}

const model_catalogue_ttl_seconds = i64(60)
const model_probe_timeout_ms = 10_000
const model_probe_max_bytes = 4 * 1024 * 1024
const model_name_max = 80
const model_id_max = 120

// model_probe_args is the per-runner catalogue command. Runners absent
// here (claude, copilot, muse, skeleton) have no verified list command.
fn model_probe_args(runner string) []string {
	return match runner {
		'opencode' { ['models'] }
		'codex' { ['debug', 'models'] }
		'cursor' { ['models'] }
		else { []string{} }
	}
}

pub fn live_models_supported(runner string) bool {
	return model_probe_args(runner).len > 0
}

fn static_models_for_runner(runner string) []LiveModelInfo {
	mut seen := map[string]bool{}
	mut out := []LiveModelInfo{}
	for m in list_models() {
		if m.runner != runner || m.model in seen {
			continue
		}
		seen[m.model] = true
		out << LiveModelInfo{
			runner: runner
			model: m.model
		}
	}
	return out
}

// model_catalogue_cache_path is the per-runner on-disk cache file.
fn model_catalogue_cache_path(runner string) string {
	return os.join_path(os.cache_dir(), 'agent-toolkit', 'model-catalogue-${runner}.json')
}

pub struct ModelCatalogueCacheEntry {
pub:
	runner     string
	fetched_at i64
	models     []LiveModelInfo
}

fn read_model_cache(runner string, now i64) ?[]LiveModelInfo {
	text := os.read_file(model_catalogue_cache_path(runner)) or { return none }
	entry := json2.decode[ModelCatalogueCacheEntry](text) or { return none }
	if entry.runner != runner || entry.models.len == 0 {
		return none
	}
	if now - entry.fetched_at > model_catalogue_ttl_seconds || entry.fetched_at > now {
		return none
	}
	return entry.models
}

fn write_model_cache(runner string, models []LiveModelInfo, now i64) {
	path := model_catalogue_cache_path(runner)
	os.mkdir_all(os.dir(path)) or { return }
	entry := ModelCatalogueCacheEntry{
		runner: runner
		fetched_at: now
		models: models
	}
	os.write_file(path, json2.encode(entry)) or { return }
}

// strip_ansi removes CSI escape sequences a CLI may emit on a terminal.
fn strip_ansi(text string) string {
	mut out := []u8{cap: text.len}
	mut i := 0
	for i < text.len {
		if text[i] == 0x1b && i + 1 < text.len && text[i + 1] == `[` {
			i += 2
			for i < text.len && !(text[i] >= 0x40 && text[i] <= 0x7e) {
				i++
			}
			i++
			continue
		}
		out << text[i]
		i++
	}
	return out.bytestr()
}

// valid_model_id accepts only model-shaped tokens: one whitespace-free
// token of printable ASCII, bounded length. Catalogue lines are
// untrusted CLI output; anything else is dropped, never shown.
fn valid_model_id(id string) bool {
	if id.len == 0 || id.len > model_id_max {
		return false
	}
	for i in 0 .. id.len {
		c := int(id[i])
		if c <= 32 || c > 126 {
			return false
		}
	}
	return true
}

fn shown_model_name(raw string, id string) string {
	clean := raw.trim_space()
	mut out := []u8{cap: clean.len}
	for i in 0 .. clean.len {
		c := int(clean[i])
		if c >= 32 && c != 127 {
			out << clean[i]
		}
	}
	name := out.bytestr().trim_space()
	if name.len == 0 || name == id || name.len > model_name_max {
		return ''
	}
	return name
}

fn unique_live_models(models []LiveModelInfo) []LiveModelInfo {
	mut seen := map[string]bool{}
	mut out := []LiveModelInfo{}
	for m in models {
		if m.model in seen {
			continue
		}
		seen[m.model] = true
		out << m
	}
	return out
}

// parse_live_models is the pure per-runner catalogue parser (tested
// without spawning any CLI).
pub fn parse_live_models(runner string, text string) ![]LiveModelInfo {
	clean := strip_ansi(text)
	return match runner {
		'opencode' { parse_plain_model_lines(runner, clean) }
		'cursor' { parse_cursor_model_lines(runner, clean) }
		'codex' { parse_codex_models_json(runner, clean) }
		else { error('runner has no live model catalogue: ${runner}') }
	}
}

fn parse_plain_model_lines(runner string, text string) ![]LiveModelInfo {
	mut out := []LiveModelInfo{}
	for line in text.split('\n') {
		id := line.trim_space()
		if valid_model_id(id) {
			out << LiveModelInfo{
				runner: runner
				model: id
			}
		}
	}
	if out.len == 0 {
		return error('no models in catalogue output')
	}
	return unique_live_models(out)
}

fn parse_cursor_model_lines(runner string, text string) ![]LiveModelInfo {
	mut out := []LiveModelInfo{}
	for line in text.split('\n') {
		trimmed := line.trim_space()
		if trimmed.len == 0 {
			continue
		}
		// A model line is its id alone, or `id - name`. Headings and
		// tips are sentences and fail the id check on the first token.
		mut id := trimmed
		mut name := ''
		if idx := trimmed.index(' - ') {
			id = trimmed[..idx].trim_space()
			name = shown_model_name(trimmed[idx + 3..], id)
		}
		if valid_model_id(id) {
			out << LiveModelInfo{
				runner: runner
				model: id
				name: name
			}
		}
	}
	if out.len == 0 {
		return error('no models in catalogue output')
	}
	return unique_live_models(out)
}

pub struct CodexCatalogueFile {
pub:
	models []CodexCatalogueModel
}

pub struct CodexCatalogueModel {
pub:
	slug         string
	display_name string
	visibility   string
}

fn parse_codex_models_json(runner string, text string) ![]LiveModelInfo {
	file := json2.decode[CodexCatalogueFile](text) or {
		return error('could not parse codex model catalogue')
	}
	mut out := []LiveModelInfo{}
	for m in file.models {
		// Only models the CLI itself lists for picking.
		if m.visibility.len > 0 && m.visibility != 'list' {
			continue
		}
		if valid_model_id(m.slug) {
			out << LiveModelInfo{
				runner: runner
				model: m.slug
				name: shown_model_name(m.display_name, m.slug)
			}
		}
	}
	if out.len == 0 {
		return error('no models in catalogue output')
	}
	return unique_live_models(out)
}

// probe_live_models runs the runner's catalogue command without a
// shell, draining stdout while the child runs so a long catalogue
// cannot block on a full pipe.
fn probe_live_models(runner string) ![]LiveModelInfo {
	bin := runner_bins[runner] or { return error('unknown runner: ${runner}') }
	resolved := resolve_bin(bin, os.home_dir())
	if resolved.len == 0 {
		return error('${bin} not found on PATH')
	}
	mut proc := os.new_process(resolved)
	proc.set_args(model_probe_args(runner))
	proc.set_redirect_stdio()
	proc.run()
	mut out := ''
	deadline := time.now().add(model_probe_timeout_ms * time.millisecond)
	for proc.is_alive() {
		if proc.is_pending(.stdout) {
			out += proc.stdout_read()
		}
		if out.len > model_probe_max_bytes {
			proc.signal_kill()
			proc.close()
			return error('model catalogue output too large')
		}
		if time.now() > deadline {
			proc.signal_kill()
			proc.close()
			return error('model catalogue probe timed out')
		}
		time.sleep(5 * time.millisecond)
	}
	proc.wait()
	out += proc.stdout_slurp()
	if proc.code != 0 {
		proc.close()
		return error('model catalogue probe failed (exit ${proc.code})')
	}
	proc.close()
	return parse_live_models(runner, out)
}

// list_live_models_typed returns the runner's models: fresh cache or
// live probe when supported, static profiles otherwise. Never errors —
// failure degrades to source 'static' (or 'unavailable' when the
// runner has no static models either).
pub fn list_live_models_typed(runner string) LiveModelsResponse {
	if !live_models_supported(runner) {
		models := static_models_for_runner(runner)
		return LiveModelsResponse{
			ok: models.len > 0
			runner: runner
			source: 'static'
			models: models
			detail: 'runner has no live model catalogue; showing built-in profiles'
		}
	}
	now := time.now().unix()
	if cached := read_model_cache(runner, now) {
		return LiveModelsResponse{
			ok: true
			runner: runner
			source: 'live'
			models: cached
			detail: 'cached live catalogue (60s)'
		}
	}
	models := probe_live_models(runner) or {
		fallback := static_models_for_runner(runner)
		return LiveModelsResponse{
			ok: fallback.len > 0
			runner: runner
			source: if fallback.len > 0 { 'static' } else { 'unavailable' }
			models: fallback
			detail: 'live catalogue unavailable (${err.msg()}); showing built-in profiles'
		}
	}
	write_model_cache(runner, models, now)
	return LiveModelsResponse{
		ok: true
		runner: runner
		source: 'live'
		models: models
	}
}

// model_available_for_runner is the session-start validation: a model
// is accepted when the static profiles or the live catalogue list it,
// so a model picked from the live catalogue never fails at spawn for
// being absent from the static map.
pub fn model_available_for_runner(runner string, model string) bool {
	if model.len == 0 {
		return true
	}
	for m in list_models() {
		if m.runner == runner && m.model == model {
			return true
		}
	}
	resp := list_live_models_typed(runner)
	if resp.source != 'live' {
		return false
	}
	for m in resp.models {
		if m.model == model {
			return true
		}
	}
	return false
}
