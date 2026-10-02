module agent_toolkit_core

import os
import time

// Coding-agent CLIs the serve tools API can truthfully detect. Roster is
// the same set desktop_engine/tool_discovery.v probes — catalog targets
// that have no user-level runtime (copilot-repository, agent-plugins) are
// omitted rather than reported as missing.
const coding_agent_ids = ['claude-code', 'cursor', 'opencode', 'windsurf', 'pi', 'muse-code',
	'gemini-cli', 'copilot-cli', 'codex']

const version_probe_tools = ['claude', 'opencode', 'gemini', 'copilot', 'codex', 'pi', 'muse']

const version_probe_timeout_ms = 3000

// AgentInfo is one persona from agents/<id>/AGENT.md.
pub struct AgentInfo {
pub:
	id          string
	name        string
	kind        string
	description string
	source_file string
}

// ToolInfo is one coding-agent CLI with split discovery planes.
// enabled is "unknown" until serve owns a real enablement store (Desktop
// Engine SQLite is not this process).
pub struct ToolInfo {
pub:
	id            string
	tool_name     string
	detected      bool
	configured    bool
	enabled       string
	verified      bool
	resolved_path string
	config_paths  []string
	version       string
	reason        string
	install_hint  string
}

// ProviderInfo is a swarm runner CLI (not a model vendor).
pub struct ProviderInfo {
pub:
	id         string
	bin        string
	available  bool
	capability string
	version    string
}

// ModelInfo is one (profile, runner) slot from swarm_model_profiles.
pub struct ModelInfo {
pub:
	profile string
	runner  string
	model   string
}

pub struct AgentsResponse {
pub:
	ok     bool
	agents []AgentInfo
}

pub struct ToolsResponse {
pub:
	ok    bool
	tools []ToolInfo
}

pub struct ProvidersResponse {
pub:
	ok        bool
	providers []ProviderInfo
}

pub struct ModelsResponse {
pub:
	ok     bool
	models []ModelInfo
}

// list_agents reads definitions from the resolved toolkit data root, including
// the in-memory embedded root used by a standalone Desktop package.
pub fn list_agents() []AgentInfo {
	root := find_toolkit_root() or { return []AgentInfo{} }
	return list_agents_at(root.path)
}

pub fn list_agents_at(root string) []AgentInfo {
	dir := os.join_path(root, 'agents')
	if !data_is_dir(root, dir) {
		return []AgentInfo{}
	}
	mut out := []AgentInfo{}
	mut names := data_ls(root, dir)
	names.sort()
	for name in names {
		if name.starts_with('.') {
			continue
		}
		agent_md := os.join_path(dir, name, 'AGENT.md')
		if !data_is_file(root, agent_md) {
			continue
		}
		text := data_read_file(root, agent_md) or { continue }
		fm_name, kind, description := parse_agent_frontmatter(text)
		out << AgentInfo{
			id: name
			name: if fm_name.len > 0 { fm_name } else { name }
			kind: kind
			description: description
			source_file: 'agents/${name}/AGENT.md'
		}
	}
	return out
}

// list_coding_tools probes each coding-agent CLI. ATK_GUI_FREEZE yields
// a bare machine (no PATH or config sentinels), matching Desktop goldens.
pub fn list_coding_tools() []ToolInfo {
	mut out := []ToolInfo{}
	for id in coding_agent_ids {
		out << probe_coding_tool(id)
	}
	return out
}

pub fn probe_coding_tool(id string) ToolInfo {
	home := os.home_dir()
	tool_name, resolved, configs := coding_tool_probe(id, home)
	detected := resolved.len > 0
	configured := configs.len > 0
	mut version := ''
	mut verified := false
	mut reason := ''
	if detected {
		version, verified = probe_cli_version(tool_name, resolved)
	} else if configured {
		reason = "configured (settings found) but ${tool_name} was not found on this session's PATH"
	} else if tool_name.len > 0 {
		reason = "${tool_name} not found on this session's PATH"
	} else {
		reason = 'no user-level runtime to detect'
	}
	return ToolInfo{
		id: id
		tool_name: tool_name
		detected: detected
		configured: configured
		enabled: 'unknown'
		verified: verified
		resolved_path: resolved
		config_paths: configs
		version: version
		reason: reason
		install_hint: ''
	}
}

// list_providers is the swarm runner roster. `auto` is a resolver, not a CLI.
pub fn list_providers() []ProviderInfo {
	mut out := []ProviderInfo{}
	for name in swarm_runner_names() {
		if name == 'auto' {
			continue
		}
		bin := runner_bins[name] or { '' }
		available := runner_available(name)
		mut version := ''
		if available && bin.len > 0 {
			version, _ = probe_cli_version(bin, resolve_bin(bin, os.home_dir()))
		} else if name == 'skeleton' {
			version = 'filesystem'
		}
		out << ProviderInfo{
			id: name
			bin: bin
			available: available
			capability: runner_caps[name] or { '' }
			version: version
		}
	}
	return out
}

pub fn list_models() []ModelInfo {
	profiles := swarm_model_profiles()
	mut keys := profiles.keys()
	keys.sort()
	mut out := []ModelInfo{}
	for profile in keys {
		by_runner := profiles[profile].clone()
		mut runners := by_runner.keys()
		runners.sort()
		for runner in runners {
			out << ModelInfo{
				profile: profile
				runner: runner
				model: by_runner[runner]
			}
		}
	}
	return out
}

fn parse_agent_frontmatter(text string) (string, string, string) {
	if !text.starts_with('---') {
		return '', '', ''
	}
	rest := text[3..]
	end := rest.index('\n---') or { return '', '', '' }
	block := rest[..end]
	mut name := ''
	mut kind := ''
	mut description := ''
	for raw in block.split_into_lines() {
		line := raw.trim_space()
		if line.starts_with('name:') && name.len == 0 {
			name = line.all_after(':').trim_space().trim("'").trim('"')
		} else if line.starts_with('kind:') && kind.len == 0 {
			kind = line.all_after(':').trim_space().trim("'").trim('"')
		} else if line.starts_with('description:') && description.len == 0 {
			description = line.all_after(':').trim_space().trim("'").trim('"')
		}
	}
	return name, kind, description
}

fn coding_tool_probe(id string, home string) (string, string, []string) {
	mut tool_name := ''
	mut resolved := ''
	mut configs := []string{}
	match id {
		'claude-code' {
			tool_name = 'claude'
			resolved = resolve_bin('claude', home)
			configs = existing_paths([os.join_path(home, '.claude')])
		}
		'cursor' {
			tool_name = 'cursor'
			resolved = resolve_bin('cursor', home)
			configs = existing_paths([os.join_path(home, '.cursor')])
		}
		'opencode' {
			tool_name = 'opencode'
			resolved = resolve_bin('opencode', home)
			configs = existing_paths([os.join_path(home, '.config', 'opencode')])
		}
		'windsurf' {
			tool_name = 'windsurf'
			resolved = resolve_bin('windsurf', home)
			configs = existing_paths([os.join_path(home, '.codeium', 'windsurf'),
				os.join_path(home, '.windsurf'), os.join_path(home, '.codeium')])
		}
		'pi' {
			tool_name = 'pi'
			resolved = resolve_bin('pi', home)
		}
		'muse-code' {
			tool_name = 'muse'
			resolved = resolve_bin('muse', home)
			configs = existing_paths([os.join_path(home, '.config', 'muse'),
				os.join_path(home, '.agents')])
		}
		'gemini-cli' {
			tool_name = 'gemini'
			resolved = resolve_bin('gemini', home)
			configs = existing_paths([os.join_path(home, '.gemini')])
		}
		'copilot-cli' {
			tool_name = 'copilot'
			resolved = resolve_bin('copilot', home)
			configs = existing_paths([os.join_path(home, '.config', 'github-copilot')])
		}
		'codex' {
			tool_name = 'codex'
			resolved = resolve_bin('codex', home)
			configs = existing_paths([os.join_path(home, '.codex')])
		}
		else {}
	}
	return tool_name, resolved, configs
}

fn resolve_bin(name string, home string) string {
	if os.getenv('ATK_GUI_FREEZE') != '' {
		return ''
	}
	found := os.find_abs_path_of_executable(name) or { '' }
	if found.len > 0 {
		return found
	}
	for dir in [os.join_path(home, '.local', 'bin'), os.join_path(home, '.opencode', 'bin'),
		'/usr/local/bin'] {
		cand := os.join_path(dir, name)
		if os.is_file(cand) && os.is_executable(cand) {
			return cand
		}
	}
	return ''
}

fn existing_paths(paths []string) []string {
	if os.getenv('ATK_GUI_FREEZE') != '' {
		return []string{}
	}
	mut out := []string{}
	for p in paths {
		if os.exists(p) {
			out << p
		}
	}
	return out
}

fn probe_cli_version(tool_name string, resolved_path string) (string, bool) {
	if resolved_path.len == 0 || !(tool_name in version_probe_tools) {
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
		p.signal_kill()
	}
	p.wait()
	if p.status != .exited || p.code != 0 {
		p.close()
		return '', false
	}
	out := p.stdout_slurp()
	p.close()
	mut first := if out.contains('\n') { out.all_before('\n') } else { out }
	first = first.trim_space()
	if first.len == 0 || first.len > 80 {
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
