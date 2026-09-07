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

// version probe budget: bounded and explainable.
const version_probe_timeout_ms = 3000

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
			p.resolved_path = os.find_abs_path_of_executable('claude') or { '' }
			p.add_config_if_exists(os.join_path(home, '.claude'))
		}
		'cursor' {
			p.tool_name = 'cursor'
			p.resolved_path = os.find_abs_path_of_executable('cursor') or { '' }
			p.add_config_if_exists(os.join_path(home, '.cursor'))
		}
		'opencode' {
			p.tool_name = 'opencode'
			p.resolved_path = os.find_abs_path_of_executable('opencode') or { '' }
			p.add_config_if_exists(os.join_path(home, '.config', 'opencode'))
		}
		'windsurf' {
			p.tool_name = 'windsurf'
			p.resolved_path = os.find_abs_path_of_executable('windsurf') or { '' }
			p.add_config_if_exists(os.join_path(home, '.codeium', 'windsurf'))
			p.add_config_if_exists(os.join_path(home, '.windsurf'))
			p.add_config_if_exists(os.join_path(home, '.codeium'))
		}
		'pi' {
			p.tool_name = 'pi'
			p.resolved_path = os.find_abs_path_of_executable('pi') or { '' }
		}
		'muse-code' {
			p.tool_name = 'muse'
			p.resolved_path = os.find_abs_path_of_executable('muse') or { '' }
			p.add_config_if_exists(os.join_path(home, '.config', 'muse'))
			p.add_config_if_exists(os.join_path(home, '.agents'))
		}
		'gemini-cli' {
			p.tool_name = 'gemini'
			p.resolved_path = os.find_abs_path_of_executable('gemini') or { '' }
			p.add_config_if_exists(os.join_path(home, '.gemini'))
		}
		'copilot-cli' {
			p.tool_name = 'copilot'
			p.resolved_path = os.find_abs_path_of_executable('copilot') or { '' }
			p.add_config_if_exists(os.join_path(home, '.config', 'github-copilot'))
		}
		'codex' {
			p.tool_name = 'codex'
			p.resolved_path = os.find_abs_path_of_executable('codex') or { '' }
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
			d.reason = 'no user-level runtime to detect for this target'
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
