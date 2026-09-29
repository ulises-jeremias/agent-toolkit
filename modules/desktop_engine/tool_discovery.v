module desktop_engine

// #1129 — tool discovery / PATH transparency for the Desktop process.
//
// The desktop process can only truthfully report what ITS OWN environment
// contains. This module is the single authoritative detector for coding-agent
// tool discovery: one probe per canonical tool, returning the resolved
// executable path, configuration-sentinel evidence, an optional bounded
// version, and a truthful reason when a tool is missing.
//
// Truth planes stay separate:
//   supported by Agent Toolkit = catalog truth (targets_registry)
//   configured                 = configuration truth (config sentinels)
//   binary found this session  = environment/discovery truth (this module)
//   currently running          = runtime truth (elsewhere)
//
// A supported tool missing from PATH stays in the catalog. A found binary is
// not necessarily configured. No shell-config parsing, no PATH mutation, no
// full-environment dumps — only the minimum relevant discovery data.

import os
import time

// ToolProbe is the raw per-tool detection result. `found` means the
// executable resolved on this session's PATH; `config_paths` lists existing
// known configuration locations (configuration evidence, not PATH truth).
pub struct ToolProbe {
pub mut:
	id            string
	tool_name     string
	found         bool
	resolved_path string
	config_paths  []string
}

// version_probe_tools is the allowlist of CLI-first tools whose `--version`
// is known to be safe and non-interactive. GUI launchers (cursor, windsurf)
// are never executed — their version stays unknown rather than risking an
// interactive process from the Desktop.
const version_probe_tools = ['claude', 'opencode', 'gemini', 'copilot', 'codex', 'pi', 'muse']

// wellknown_bin_dirs are static per-user install locations checked when PATH
// lookup misses. A Desktop process started from a GUI launcher inherits a
// minimal PATH (no ~/.local/bin, no tool shims) while the user shells see
// everything — without this fallback the wizard reports "0 of 11 found" on
// machines that have the tools. Static names only: no shell-config parsing,
// no PATH mutation, no execution — a resolved path is still the evidence.
fn wellknown_bin_dirs(home string) []string {
	return [
		os.join_path(home, '.local', 'bin'),
		os.join_path(home, '.opencode', 'bin'),
		'/usr/local/bin',
	]
}

// find_in_wellknown resolves an executable name against the static
// well-known bins. Returns '' when absent or not executable.
fn find_in_wellknown(name string, home string) string {
	if name.trim_space() == '' || name.contains('/') || name.contains('\\') {
		return ''
	}
	for dir in wellknown_bin_dirs(home) {
		cand := os.join_path(dir, name)
		if os.is_file(cand) && os.is_executable(cand) {
			return cand
		}
	}
	return ''
}

// version probe budget: bounded and explainable.
const version_probe_timeout_ms = 3000

// resolve_tool_binary resolves an executable on this session's PATH, falling
// back to the static well-known bins (GUI-launcher minimal PATH, see
// wellknown_bin_dirs). '' when neither sees it. Under ATK_GUI_FREEZE (golden
// captures) no lookup runs at all: the frozen session is a bare machine, so
// local and CI captures agree byte-for-byte on tool rows.
fn resolve_tool_binary(name string, home string) string {
	if os.getenv('ATK_GUI_FREEZE') != '' {
		return ''
	}
	found := os.find_abs_path_of_executable(name) or { '' }
	if found != '' {
		return found
	}
	return find_in_wellknown(name, home)
}

// tool_probe is THE authoritative per-tool detector: it resolves the
// executable on this session's PATH and collects known configuration
// sentinels. Everything else (target_detected, discovery results, panels)
// derives from this — one detector per fact.
pub fn tool_probe(id string) ToolProbe {
	home := os.home_dir()
	mut p := ToolProbe{
		id: id
	}
	match id {
		'claude-code' {
			p.tool_name = 'claude'
			p.resolved_path = resolve_tool_binary('claude', home)
			p.add_config_if_exists(os.join_path(home, '.claude'))
		}
		'cursor' {
			p.tool_name = 'cursor'
			p.resolved_path = resolve_tool_binary('cursor', home)
			p.add_config_if_exists(os.join_path(home, '.cursor'))
		}
		'opencode' {
			p.tool_name = 'opencode'
			p.resolved_path = resolve_tool_binary('opencode', home)
			p.add_config_if_exists(os.join_path(home, '.config', 'opencode'))
		}
		'windsurf' {
			p.tool_name = 'windsurf'
			p.resolved_path = resolve_tool_binary('windsurf', home)
			p.add_config_if_exists(os.join_path(home, '.codeium', 'windsurf'))
			p.add_config_if_exists(os.join_path(home, '.windsurf'))
			p.add_config_if_exists(os.join_path(home, '.codeium'))
		}
		'pi' {
			p.tool_name = 'pi'
			p.resolved_path = resolve_tool_binary('pi', home)
		}
		'muse-code' {
			p.tool_name = 'muse'
			p.resolved_path = resolve_tool_binary('muse', home)
			p.add_config_if_exists(os.join_path(home, '.config', 'muse'))
			p.add_config_if_exists(os.join_path(home, '.agents'))
		}
		'gemini-cli' {
			p.tool_name = 'gemini'
			p.resolved_path = resolve_tool_binary('gemini', home)
			p.add_config_if_exists(os.join_path(home, '.gemini'))
		}
		'copilot-cli' {
			p.tool_name = 'copilot'
			p.resolved_path = resolve_tool_binary('copilot', home)
			p.add_config_if_exists(os.join_path(home, '.config', 'github-copilot'))
		}
		'codex' {
			p.tool_name = 'codex'
			p.resolved_path = resolve_tool_binary('codex', home)
			p.add_config_if_exists(os.join_path(home, '.codex'))
		}
		else {
			// copilot-repository is per-project; agent-plugins is a portable
			// format — neither has a user-level runtime to detect.
			return p
		}
	}
	p.found = p.resolved_path != ''
	return p
}

fn (mut p ToolProbe) add_config_if_exists(path string) {
	// frozen sessions report no configuration sentinels either — same bare
	// machine as the binary lookup above.
	if os.getenv('ATK_GUI_FREEZE') != '' {
		return
	}
	if os.exists(path) {
		p.config_paths << path
	}
}

// probe_version executes `<tool> --version` with a bounded wait for the
// CLI-first allowlist. Returns ('', false) when unsupported, not found, the
// probe fails, or times out — never an invented version.
fn probe_version(tool_name string, resolved_path string) (string, bool) {
	if resolved_path == '' || !(tool_name in version_probe_tools) {
		return '', false
	}
	mut p := os.new_process(resolved_path)
	p.set_args(['--version'])
	p.set_redirect_stdio()
	p.run()
	mut waited := 0
	for waited < version_probe_timeout_ms && p.is_alive() {
		time.sleep(50 * time.millisecond)
		waited += 50
	}
	if p.is_alive() {
		// a version probe must never leave an interactive process behind
		p.signal_kill()
	}
	p.wait()
	// exit status is part of the truth: a nonzero/killed/aborted exit means
	// the version is unknown even if stdout looked plausible (#1163 review)
	if p.status != .exited || p.code != 0 {
		p.close()
		return '', false
	}
	out := p.stdout_slurp()
	p.close()
	mut first := if out.contains('\n') { out.all_before('\n') } else { out }
	first = first.trim_space()
	// keep only bounded, printable diagnostic text
	if first == '' {
		return '', false
	}
	if first.len > 80 {
		return '', false
	}
	for i in 0 .. first.len {
		c := int(first[i])
		if c < 32 || c > 126 {
			return '', false
		}
	}
	return first, true
}

// ToolDiscovery is the typed discovery result for Desktop surfaces.
pub struct ToolDiscovery {
pub mut:
	id            string // canonical target id
	display_name  string
	tool_name     string
	found         bool // executable found on this session's PATH
	resolved_path string
	config_paths  []string
	version       string
	version_known bool
	reason        string // truthful why-text when missing
	doctor_check  string // Doctor check id when a fix seam exists ('profile:<id>')
}

// tool_discovery builds the typed discovery result for one canonical tool.
pub fn (mut e Engine) tool_discovery(id string) ToolDiscovery {
	mut display := id
	for r in e.targets_registry() {
		if r.id == id {
			display = r.display_name
			break
		}
	}
	probe := tool_probe(id)
	if probe.found && probe.tool_name in version_probe_tools {
		// a real subprocess probe runs on this pass — counted so cache
		// behavior is testable (cached calls within TTL never increment)
		e.discovery_probe_calls++
	}
	mut d := ToolDiscovery{
		id: id
		display_name: display
		tool_name: probe.tool_name
		found: probe.found
		resolved_path: probe.resolved_path
		config_paths: probe.config_paths
		doctor_check: 'profile:${id}'
	}
	if probe.found {
		version, known := probe_version(probe.tool_name, probe.resolved_path)
		d.version = version
		d.version_known = known
	} else {
		if probe.config_paths.len > 0 {
			d.reason = "configured (settings found) but ${probe.tool_name} was not found on this session's PATH"
		} else if probe.tool_name != '' {
			d.reason = "${probe.tool_name} not found on this session's PATH"
		} else {
			d.reason = 'no user-level runtime to detect'
		}
	}
	return d
}

// tool_discovery_catalog returns discovery results for every canonical
// supported target (catalog truth drives the roster; discovery adds
// environment truth per entry — a missing tool never disappears).
pub fn (mut e Engine) tool_discovery_catalog() []ToolDiscovery {
	mut out := []ToolDiscovery{}
	for r in e.targets_registry() {
		out << e.tool_discovery(r.id)
	}
	return out
}

// discovery TTL: the session environment is process-scoped and effectively
// static; rendering calls the catalog every frame, so results are cached —
// a version probe must NEVER spawn processes at frame rate (#1163 review).
const discovery_cache_ttl_ms = 60_000

// tool_discovery_catalog_cached returns the catalog through a TTL cache.
// Rendering surfaces use this; tests and explicit refresh use the uncached
// tool_discovery_catalog().
pub fn (mut e Engine) tool_discovery_catalog_cached() []ToolDiscovery {
	e.mu.lock()
	now := time.now().unix_milli()
	fresh := e.discovery_cache.len > 0 && now - e.discovery_cache_at < discovery_cache_ttl_ms
	if fresh {
		out := e.discovery_cache.clone()
		e.mu.unlock()
		return out
	}
	e.mu.unlock()
	out := e.tool_discovery_catalog()
	e.mu.lock()
	e.discovery_cache = out.clone()
	e.discovery_cache_at = now
	e.mu.unlock()
	return out
}

// path_entries returns the count of PATH entries in this Desktop session
// (evidence only; the individual entries are local diagnostic detail and are
// not rendered wholesale).
pub fn session_path_entry_count() int {
	path := os.getenv('PATH')
	if path == '' {
		return 0
	}
	return path.split(':').map(it.trim_space()).filter(it != '').len
}
