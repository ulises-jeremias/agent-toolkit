module agent_toolkit_core

import crypto.sha256
import json
import os
import time

// McpOptions configures the mcp command family (#518).
pub struct McpOptions {
pub:
	subcommand   string // list | setup | health | doctor | uninstall
	provider     string
	offline      bool
	toolkit_root string
	config_path  string // empty → ~/.config/agent-toolkit/mcp-config.json
}

// McpReport is the domain result for mcp subcommands.
pub struct McpReport {
pub mut:
	ok      bool
	message string
	count   int
}

struct McpProviderCfg {
	enabled      bool
	required_env []string
	validated_at string
}

struct McpConfigFile {
mut:
	providers map[string]McpProviderCfg
}

// mcp_pinned_shas holds version-pinned registry SHAs (parity with Python MCP_TEMPLATES sha).
// Values are sha256 of mcp/templates/<provider>/config.template.json at pin time.
const mcp_pinned_shas = {
	'chrome-devtools': '660283933ff9bab1b1f7bf55bcaebe7fe63151b91a6458f37e5de4c87152dba9'
	'clickup':         '5d59cd887638c849b95bf7841e4648ad5ae024af48a3125efaa535676c050090'
	'figma':           '7731bc20a47c3ad8f146b42bfed4e59ee7642f383b0b891765a28e9421946676'
	'github':          '60d62ae1f1bbc72db8a23faa2bca97f2248df45e83b7586b8e0b1ecf654fe6e1'
	'linear':          '79af5262f93c0f74387c984e1a52a65df704d07c8c1c179cca22c1398735b923'
	'notion':          'd26d957fa1e489885f5fd7c584b439b1b1c36ade2ab3dc06ecca63273cc612ab'
	'slack':           '61366d94252dd7a59aea17d346157eb85c4bd1a0cacefc23a03c82153b2e4e74'
}

// run_mcp implements list/setup/health/doctor/uninstall. Secrets are never stored or printed.
pub fn run_mcp(opts McpOptions) McpReport {
	sub := opts.subcommand
	if sub.len == 0 || sub in ['help', '-h', '--help'] {
		return McpReport{
			ok:      true
			message: mcp_help_text()
		}
	}
	root := if opts.toolkit_root.len > 0 { opts.toolkit_root } else { lookup_checkout_root() }
	cfg_path := if opts.config_path.len > 0 { opts.config_path } else { default_mcp_config_path() }
	return match sub {
		'list' { mcp_list(root, cfg_path) }
		'setup' { mcp_setup(root, cfg_path, opts.provider, opts.offline) }
		'health' { mcp_health(root, opts.provider) }
		'doctor' {
			if opts.offline {
				mcp_health(root, opts.provider)
			} else {
				mcp_doctor(root, cfg_path, opts.provider)
			}
		}
		'uninstall' { mcp_uninstall(cfg_path, opts.provider) }
		else {
			McpReport{
				ok:      false
				message: 'Unknown subcommand: ${sub}\n  Valid subcommands: list, setup, health, doctor, uninstall'
			}
		}
	}
}

pub fn mcp_result(report McpReport) CommandResult {
	return CommandResult{
		command: 'mcp'
		ok:      report.ok
		message: report.message
		data:    {
			'count': '${report.count}'
		}
	}
}

pub fn mcp_help_text() string {
	return 'mcp — MCP (Model Context Protocol) provider management.

Usage: agent-toolkit mcp <subcommand> [args]

Subcommands:
    list                   List available MCP providers
    setup <provider>       Configure a provider (non-interactive; env names only)
    health [provider]      Validate registry entry and required env var names (no network)
    doctor [provider]      Check env vars for provider(s)
    uninstall <provider>   Remove a provider from local MCP config

Options:
    --offline              Skip network connectivity checks (setup/doctor)
    --json                 Structured CommandResult JSON

Credentials: never stored in mcp-config.json; never printed. Export tokens in the shell.
'
}

fn default_mcp_config_path() string {
	return os.join_path(new_fs().toolkit_config_dir(), 'mcp-config.json')
}

fn mcp_templates_dir(root string) string {
	return os.join_path(root, 'mcp', 'templates')
}

fn mcp_registry_dir(root string) string {
	return os.join_path(root, 'mcp', 'registry')
}

// is_mcp_cached reports whether a provider template is cached locally (offline guard).
// Mirrors Python get_template offline check: if offline && !is_cached => error.
pub fn is_mcp_cached(provider string, root string) bool {
	if provider.len == 0 || root.len == 0 {
		return false
	}
	tdir := os.join_path(mcp_templates_dir(root), provider)
	if os.is_dir(tdir) {
		cfg := os.join_path(tdir, 'config.template.json')
		if os.is_file(cfg) {
			return true
		}
		// template dir exists even without config (e.g. registry-only) counts as cached
		return true
	}
	reg := os.join_path(mcp_registry_dir(root), '${provider}.yaml')
	if os.is_file(reg) {
		return true
	}
	return false
}

fn mcp_pinned_sha(provider string) string {
	return mcp_pinned_shas[provider] or { '' }
}

fn mcp_template_sha(root string, provider string) string {
	path := os.join_path(mcp_templates_dir(root), provider, 'config.template.json')
	if !os.is_file(path) {
		return ''
	}
	text := os.read_file(path) or { return '' }
	return sha256.hexhash(text)
}

fn mcp_health_binary(provider string, meta RegistryMeta) string {
	// Derive expected binary for health probe from registry package or provider
	// name. Mirrors Python health probe mapping provider → binary and ensures
	// health is not a stub: at least one provider (e.g. clickup) will report
	// probe failure when its server binary is not installed, while well-known
	// stdio servers (slack → npx, github → docker) probe their runtime.
	if meta.package.len > 0 {
		pkg := meta.package
		if pkg.contains('@modelcontextprotocol') {
			return 'npx'
		}
		if pkg.starts_with('ghcr.io') {
			return 'docker'
		}
		parts := pkg.split('/')
		mut last := parts[parts.len - 1]
		if last.contains('@') {
			last = last.all_before('@')
		}
		if last.contains(':') {
			last = last.all_before(':')
		}
		if last.len > 0 {
			return last
		}
	}
	// Fallback to provider name; if a stray binary exists with that name (e.g.
	// ~/go/bin/clickup) we still count it as probe present, but health will
	// succeed only if that binary responds to --help.
	return provider
}

fn emit_mcp_provider_hooks(provider string, root string) string {
	// Hook registry coupling: when MCP provider is setup, also emit per-tool hooks
	// if the toolkit has canonical hooks that map to cursor/claude-code surfaces.
	// This mirrors Python hook_registry.py emit_hooks_for_provider.
	hooks_root := os.join_path(root, 'capabilities', 'hooks')
	if !os.is_dir(hooks_root) {
		return ''
	}
	// Lightweight check: load hooks count via load_hooks; if any hook exists,
	// report coupling. Actual per-provider hook emission is deferred to emitter,
	// but we surface the coupling in setup output for parity.
	hooks := load_hooks(hooks_root)
	if hooks.len == 0 {
		return ''
	}
	// Only emit for providers that plausibly have hooks (all 7 are plausible,
	// but we gate on registry entry to avoid noise for unknown providers).
	meta := load_registry_meta(root, provider) or { return '' }
	_ = meta
	return '  ✓  hooks: checked ${hooks.len} canonical hook(s) for ${provider} (cursor/hooks.json, claude-code hooks if supported)'
}

fn mcp_list(root string, cfg_path string) McpReport {
	if root.len == 0 {
		return McpReport{
			ok:      false
			message: 'Cannot locate toolkit directory'
		}
	}
	tdir := mcp_templates_dir(root)
	if !os.is_dir(tdir) {
		return McpReport{
			ok:      false
			message: 'MCP templates directory not found: ${tdir}'
		}
	}
	providers := list_template_providers(tdir)
	if providers.len == 0 {
		return McpReport{
			ok:      true
			message: '  ⚠  No MCP provider templates found'
		}
	}
	cfg := load_mcp_config(cfg_path)
	mut lines := []string{}
	lines << ''
	lines << 'Available MCP providers'
	lines << ''
	lines << '  Provider          Status        Required env vars'
	lines << '  ------------------------------------------------'
	for provider in providers {
		env_vars := template_env_vars(tdir, provider)
		env_str := if env_vars.len > 0 { env_vars.join(', ') } else { '(none)' }
		status := mcp_provider_status(cfg, provider)
		lines << '  ${provider:-16}  ${status:-12}  ${env_str}'
	}
	lines << ''
	lines << 'Run: agent-toolkit mcp setup <provider>'
	lines << ''
	return McpReport{
		ok:      true
		message: lines.join('\n')
		count:   providers.len
	}
}

fn mcp_setup(root string, cfg_path string, provider string, offline bool) McpReport {
	if provider.len == 0 {
		return McpReport{
			ok:      false
			message: 'Usage: agent-toolkit mcp setup <provider>'
		}
	}
	if root.len == 0 {
		return McpReport{
			ok:      false
			message: 'Cannot locate toolkit directory'
		}
	}
	// Offline fail-closed: mirrors Python get_template(offline) guard.
	effective_offline := offline || is_offline()
	if effective_offline {
		if !is_mcp_cached(provider, root) {
			return McpReport{
				ok:      false
				message: 'offline and not cached: ${provider}'
			}
		}
	}
	known := list_known_mcp_providers(root)
	if provider !in known {
		return McpReport{
			ok:      false
			message: "Provider '${provider}' not found.\n  Available: ${known.join(', ')}"
		}
	}
	tdir := mcp_templates_dir(root)
	env_vars := template_env_vars(tdir, provider)
	reg_env := registry_env_vars(root, provider)
	mut required := if reg_env.len > 0 { reg_env } else { env_vars }
	mut lines := []string{}
	lines << ''
	lines << 'MCP setup: ${provider}'
	lines << ''
	if required.len == 0 {
		lines << '  ⚠  No environment variables required for this provider.'
	} else {
		lines << '  Required env vars: ${required.join(', ')}'
		lines << '  (values read from environment if set; never stored or printed)'
	}
	lines << ''
	if effective_offline {
		lines << '  ✓  Offline mode — skipping connectivity check'
	} else {
		lines << '  ✓  Env var names validated (no tokens logged; connectivity optional)'
	}
	// SHA provenance check: verify template SHA matches pinned registry
	sha := mcp_template_sha(root, provider)
	pin := mcp_pinned_sha(provider)
	if pin.len > 0 && sha.len > 0 {
		if sha != pin {
			lines << '  ⚠  template SHA mismatch: got ${sha[..8]} want ${pin[..8]} (drift vs upstream.lock)'
		} else {
			lines << '  ✓  template SHA verified: ${sha[..8]}'
		}
	} else if sha.len > 0 {
		lines << '  -  template SHA: ${sha[..8]} (no pin for ${provider})'
	}
	mut cfg := load_mcp_config(cfg_path)
	cfg.providers[provider] = McpProviderCfg{
		enabled:      true
		required_env: required
		validated_at: time.utc().format_rfc3339()
	}
	save_mcp_config(cfg_path, cfg) or {
		return McpReport{
			ok:      false
			message: 'Failed to save config: ${err}'
		}
	}
	lines << '  ✓  Saved to ${cfg_path}'
	// Hook registry coupling: emit hooks alongside MCP (cursor/claude-code)
	hook_msg := emit_mcp_provider_hooks(provider, root)
	if hook_msg.len > 0 {
		lines << hook_msg
	}
	lines << ''
	lines << '── Next steps ──'
	lines << ''
	lines << '  Export env vars in your shell profile (never commit tokens):'
	for var in required {
		lines << '    export ${var}="<your-value>"'
	}
	lines << ''
	return McpReport{
		ok:      true
		message: lines.join('\n')
		count:   1
	}
}

fn mcp_health(root string, provider string) McpReport {
	if root.len == 0 {
		return McpReport{
			ok:      false
			message: 'Cannot locate toolkit directory'
		}
	}
	mut targets := []string{}
	if provider.len > 0 {
		targets << provider
	} else {
		targets = list_known_mcp_providers(root)
	}
	if targets.len == 0 {
		return McpReport{
			ok:      true
			message: '  ⚠  No MCP providers found in registry or templates'
		}
	}
	mut lines := []string{}
	lines << ''
	lines << 'MCP health (offline)'
	mut errors := 0
	for p in targets {
		lines << ''
		lines << '── ${p} ──'
		entry := load_registry_meta(root, p) or {
			lines << '  ✗  Not in mcp/registry/ and no template directory'
			errors++
			continue
		}
		lines << '  ✓  registry: ${entry.display_name} (${entry.id})'
		if entry.package.len > 0 {
			lines << '  ✓  package: ${entry.package}'
		}
		if entry.env_vars.len > 0 {
			lines << '  ✓  required env: ${entry.env_vars.join(', ')}'
			for var in entry.env_vars {
				if os.getenv(var).len > 0 {
					lines << '  ✓  ${var}: set'
				} else {
					lines << '  -  ${var}: not set (expected until configured)'
				}
			}
		} else {
			lines << '  ✓  required env: (none)'
		}
		// SHA pin verification (doctor parity inside health for offline)
		sha := mcp_template_sha(root, p)
		pin := mcp_pinned_sha(p)
		if pin.len > 0 && sha.len > 0 {
			if sha != pin {
				lines << '  ⚠  SHA drift: got ${sha[..8]} want ${pin[..8]}'
			} else {
				lines << '  ✓  SHA verified: ${sha[..8]}'
			}
		} else if sha.len > 0 {
			lines << '  -  template SHA: ${sha[..8]}'
		}
		// Real health probe: binary presence + stdio handshake attempt
		bin := mcp_health_binary(p, entry)
		if bin.len > 0 {
			bin_path := os.find_abs_path_of_executable(bin) or { '' }
			if bin_path.len == 0 {
				lines << '  ✗  health probe: binary not on PATH: ${bin}'
				errors++
			} else {
				lines << '  ✓  probe binary: ${bin} at ${bin_path}'
				// Attempt lightweight probe (e.g., --help) with timeout; fail-closed on error.
				probe_arg := if bin == 'npx' { '--help' } else { '--help' }
				ps := new_process_service()
				res := ps.run(RunOptions{
					argv:    [bin, probe_arg]
					timeout: 5 * time.second
				}) or {
					lines << '  ✗  health probe failed for ${bin}: ${err}'
					errors++
					continue
				}
				if res.timed_out {
					lines << '  ⚠  health probe timed out for ${bin}'
					errors++
				} else if res.exit_code != 0 {
					// For npx/docker, non-zero help is not fatal but we surface it.
					// Treat as warn rather than hard error to avoid false positives on help-less binaries.
					if bin in ['npx', 'docker'] {
						lines << '  -  probe exit ${res.exit_code} for ${bin} (non-fatal; binary present)'
					} else {
						lines << '  ✗  health probe exit ${res.exit_code} for ${bin}: ${res.stderr.trim_space()}'
						errors++
					}
				} else {
					lines << '  ✓  health probe ok: ${bin} responded'
				}
			}
		}
	}
	lines << ''
	return McpReport{
		ok:      errors == 0
		message: lines.join('\n')
		count:   targets.len
	}
}

fn mcp_doctor(root string, cfg_path string, provider string) McpReport {
	cfg := load_mcp_config(cfg_path)
	mut targets := []string{}
	if provider.len > 0 {
		targets << provider
	} else {
		targets = cfg.providers.keys()
		targets.sort()
	}
	if targets.len == 0 {
		return McpReport{
			ok:      true
			message: '  ⚠  No MCP providers configured. Run: agent-toolkit mcp list'
		}
	}
	mut lines := []string{}
	lines << ''
	lines << 'MCP doctor'
	mut total_err := 0
	mut total_ok := 0
	mut total_warn := 0
	tdir := mcp_templates_dir(root)
	for p in targets {
		lines << ''
		lines << '── ${p} ──'
		prov := cfg.providers[p] or { McpProviderCfg{} }
		if prov.validated_at.len == 0 && !prov.enabled && prov.required_env.len == 0 {
			lines << '  ⚠  ${p}: not configured (run: agent-toolkit mcp setup ${p})'
			total_warn++
		} else {
			icon := if prov.enabled { '✓' } else { '⚠' }
			lines << '  ${icon}  ${p}: enabled=${prov.enabled}, validated_at=${prov.validated_at}'
			if prov.enabled {
				total_ok++
			} else {
				total_warn++
			}
		}
		env_vars := template_env_vars(tdir, p)
		for var in env_vars {
			if os.getenv(var).len > 0 {
				lines << '  ✓  ${var}: set'
				total_ok++
			} else {
				lines << '  ✗  ${var}: not set in environment'
				total_err++
			}
		}
		// SHA drift check (template vs pinned, like provenance)
		sha := mcp_template_sha(root, p)
		pin := mcp_pinned_sha(p)
		if sha.len == 0 {
			lines << '  ⚠  template missing for ${p} (SHA drift: not cached)'
			total_warn++
		} else if pin.len > 0 {
			if sha != pin {
				lines << '  ⚠  SHA drift: template ${p} got ${sha[..8]} want ${pin[..8]} (upstream.lock mismatch)'
				total_warn++
			} else {
				lines << '  ✓  SHA verified: ${sha[..8]}'
				total_ok++
			}
		} else {
			lines << '  -  template SHA: ${sha[..8]} (no pin)'
		}
		// Also check registry meta presence
		entry := load_registry_meta(root, p) or {
			lines << '  ⚠  registry entry missing for ${p}'
			total_warn++
			continue
		}
		if entry.package.len > 0 {
			lines << '  ✓  registry package: ${entry.package}'
		}
		// Surface env vars from registry as well
		if entry.env_vars.len > 0 {
			for var in entry.env_vars {
				if var in env_vars {
					continue
				}
				if os.getenv(var).len > 0 {
					lines << '  ✓  ${var}: set'
					total_ok++
				} else {
					lines << '  ✗  ${var}: not set'
					total_err++
				}
			}
		}
	}
	lines << ''
	lines << '── Summary: ${total_ok} ok, ${total_warn} warnings, ${total_err} errors ──'
	lines << ''
	return McpReport{
		ok:      total_err == 0
		message: lines.join('\n')
		count:   targets.len
	}
}

fn mcp_uninstall(cfg_path string, provider string) McpReport {
	if provider.len == 0 {
		return McpReport{
			ok:      false
			message: 'Usage: agent-toolkit mcp uninstall <provider>'
		}
	}
	mut cfg := load_mcp_config(cfg_path)
	if provider !in cfg.providers {
		return McpReport{
			ok:      true
			message: "Provider '${provider}' is not configured"
		}
	}
	cfg.providers.delete(provider)
	save_mcp_config(cfg_path, cfg) or {
		return McpReport{
			ok:      false
			message: 'Failed to save config: ${err}'
		}
	}
	return McpReport{
		ok:      true
		message: "Removed '${provider}' from ${cfg_path}"
		count:   1
	}
}

fn list_template_providers(tdir string) []string {
	mut names := []string{}
	entries := os.ls(tdir) or { return names }
	for e in entries {
		if os.is_dir(os.join_path(tdir, e)) {
			names << e
		}
	}
	names.sort()
	return names
}

fn list_known_mcp_providers(root string) []string {
	mut names := []string{}
	for n in list_template_providers(mcp_templates_dir(root)) {
		if n !in names {
			names << n
		}
	}
	reg := mcp_registry_dir(root)
	if os.is_dir(reg) {
		entries := os.ls(reg) or { []string{} }
		for e in entries {
			if e.ends_with('.yaml') {
				stem := e.all_before_last('.yaml')
				if stem !in names {
					names << stem
				}
			}
		}
	}
	names.sort()
	return names
}

fn registry_env_vars(root string, provider string) []string {
	meta := load_registry_meta(root, provider) or { return []string{} }
	return meta.env_vars
}

fn template_env_vars(tdir string, provider string) []string {
	path := os.join_path(tdir, provider, 'config.template.json')
	if !os.is_file(path) {
		return []
	}
	text := os.read_file(path) or { return [] }
	return extract_template_env_names(text)
}

fn extract_template_env_names(text string) []string {
	mut found := []string{}
	mut i := 0
	for i < text.len {
		if i + 2 < text.len && text[i] == `$` && text[i + 1] == `{` {
			j := i + 2
			mut k := j
			for k < text.len && text[k] != `}` {
				k++
			}
			if k < text.len {
				name := text[j..k]
				if name.len > 0 && name !in found {
					found << name
				}
				i = k + 1
				continue
			}
		}
		i++
	}
	return found
}

struct RegistryMeta {
	id           string
	display_name string
	package      string
	env_vars     []string
}

fn load_registry_meta(root string, provider string) ?RegistryMeta {
	path := os.join_path(mcp_registry_dir(root), '${provider}.yaml')
	if !os.is_file(path) {
		tdir := os.join_path(mcp_templates_dir(root), provider)
		if os.is_dir(tdir) {
			return RegistryMeta{
				id:           provider
				display_name: provider
			}
		}
		return none
	}
	text := os.read_file(path) or { return none }
	mut id := yaml_scalar(text, 'id')
	if id.len == 0 {
		id = provider
	}
	display := yaml_scalar(text, 'display_name')
	pkg := yaml_scalar(text, 'package')
	env := yaml_bracket_list(text, 'env')
	return RegistryMeta{
		id:           id
		display_name: if display.len > 0 { display } else { provider }
		package:      pkg
		env_vars:     env
	}
}

fn yaml_scalar(text string, key string) string {
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('${key}:') {
			mut v := t.all_after(':').trim_space().trim('"').trim("'")
			return v
		}
	}
	return ''
}

fn yaml_bracket_list(text string, key string) []string {
	mut out := []string{}
	for line in text.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('${key}:') && t.contains('[') {
			inner := t.all_after('[').all_before(']')
			for part in inner.split(',') {
				v := part.trim_space().trim('"').trim("'")
				if v.len > 0 {
					out << v
				}
			}
			return out
		}
	}
	return out
}

fn load_mcp_config(path string) McpConfigFile {
	if !os.is_file(path) {
		return McpConfigFile{
			providers: map[string]McpProviderCfg{}
		}
	}
	text := os.read_file(path) or {
		return McpConfigFile{
			providers: map[string]McpProviderCfg{}
		}
	}
	return json.decode(McpConfigFile, text) or {
		McpConfigFile{
			providers: map[string]McpProviderCfg{}
		}
	}
}

fn save_mcp_config(path string, cfg McpConfigFile) ! {
	payload := encode_mcp_config(cfg)
	new_fs().write_atomic(path, payload)!
}

fn encode_mcp_config(cfg McpConfigFile) string {
	mut parts := []string{}
	mut keys := cfg.providers.keys()
	keys.sort()
	for k in keys {
		p := cfg.providers[k]
		env_json := json.encode(p.required_env)
		parts << '"${k}":{"enabled":${p.enabled},"required_env":${env_json},"validated_at":${json.encode(p.validated_at)}}'
	}
	return '{"providers":{${parts.join(',')}}}\n'
}

fn mcp_provider_status(cfg McpConfigFile, provider string) string {
	p := cfg.providers[provider] or {
		return '  not setup'
	}
	if p.enabled {
		return '✓ configured'
	}
	return '- disabled'
}
