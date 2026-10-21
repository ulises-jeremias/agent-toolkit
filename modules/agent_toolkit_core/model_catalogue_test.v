module agent_toolkit_core

import os
import time

fn test_live_models_supported_only_for_listable_runners() {
	assert live_models_supported('opencode')
	assert live_models_supported('codex')
	assert live_models_supported('cursor')
	assert !live_models_supported('claude')
	assert !live_models_supported('copilot')
	assert !live_models_supported('skeleton')
	assert !live_models_supported('nope')
}

fn test_parse_opencode_models_plain_lines() {
	text := 'anthropic/claude-sonnet-4-5\nopenai/gpt-5\n\nnot a model line\nanthropic/claude-sonnet-4-5\n'
	models := parse_live_models('opencode', text) or {
		assert false, err.msg()
		return
	}
	assert models.len == 2
	assert models[0].model == 'anthropic/claude-sonnet-4-5'
	assert models[0].runner == 'opencode'
	assert models[1].model == 'openai/gpt-5'
}

fn test_parse_opencode_models_strips_ansi() {
	text := '\x1b[32mopenai/gpt-5\x1b[0m\n'
	models := parse_live_models('opencode', text) or {
		assert false, err.msg()
		return
	}
	assert models.len == 1
	assert models[0].model == 'openai/gpt-5'
}

fn test_parse_opencode_models_empty_is_error() {
	parse_live_models('opencode', '\n\n') or { return }
	assert false, 'expected error for empty catalogue'
}

fn test_parse_cursor_models_with_names() {
	text := 'Available models\n\ngpt-5 - GPT-5\ncomposer-2\nTip: pass --model to choose\n'
	models := parse_live_models('cursor', text) or {
		assert false, err.msg()
		return
	}
	assert models.len == 2
	assert models[0].model == 'gpt-5'
	assert models[0].name == 'GPT-5'
	assert models[1].model == 'composer-2'
	assert models[1].name == ''
}

fn test_parse_codex_models_json_filters_visibility() {
	text := '{"models":[{"slug":"gpt-5-codex","display_name":"GPT-5 Codex","visibility":"list"},{"slug":"hidden-1","display_name":"Hidden","visibility":"hide"},{"slug":"gpt-5","display_name":"gpt-5"}]}'
	models := parse_live_models('codex', text) or {
		assert false, err.msg()
		return
	}
	assert models.len == 2
	assert models[0].model == 'gpt-5-codex'
	assert models[0].name == 'GPT-5 Codex'
	// display_name equal to slug yields no separate name.
	assert models[1].model == 'gpt-5'
	assert models[1].name == ''
}

fn test_parse_codex_models_bad_json_is_error() {
	parse_live_models('codex', 'not json') or { return }
	assert false, 'expected error for bad JSON'
}

fn test_parse_live_models_unsupported_runner_is_error() {
	parse_live_models('claude', 'whatever') or { return }
	assert false, 'expected error for unsupported runner'
}

fn test_static_models_for_runner_dedupes_profiles() {
	models := static_models_for_runner('claude')
	assert models.len > 0
	mut seen := map[string]bool{}
	for m in models {
		assert m.runner == 'claude'
		assert !(m.model in seen)
		seen[m.model] = true
	}
}

fn test_list_live_models_static_source_for_unlistable_runner() {
	resp := list_live_models_typed('claude')
	assert resp.source == 'static'
	assert resp.models.len > 0
}

fn test_model_cache_roundtrip_and_expiry() {
	runner := 'cachetest'
	path := model_catalogue_cache_path(runner)
	defer {
		os.rm(path) or {}
	}
	now := time.now().unix()
	models := [LiveModelInfo{
		runner: runner
		model: 'm-1'
	}]
	write_model_cache(runner, models, now)
	cached := read_model_cache(runner, now) or {
		assert false, 'expected fresh cache hit'
		return
	}
	assert cached.len == 1
	assert cached[0].model == 'm-1'
	if _ := read_model_cache(runner, now + model_catalogue_ttl_seconds + 1) {
		assert false, 'expected stale cache miss'
	}
}

fn test_model_available_for_runner_static_and_unknown() {
	// Static profile models validate without any live probe.
	assert model_available_for_runner('claude', 'sonnet')
	// Unknown models are rejected for a runner without a live catalogue.
	assert !model_available_for_runner('claude', 'definitely-not-a-model-xyz')
	assert model_available_for_runner('claude', '')
}
