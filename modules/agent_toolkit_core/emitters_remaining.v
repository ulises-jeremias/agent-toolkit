module agent_toolkit_core

import os

// normalize_emit_target maps Python CLI aliases to canonical emitter ids.
pub fn normalize_emit_target(target_id string) string {
	return match target_id {
		'gemini', 'gemini-cli' { 'gemini-cli' }
		'muse', 'muse-code' { 'muse-code' }
		'copilot', 'copilot-cli' { 'copilot-cli' }
		else { target_id }
	}
}

fn emit_windsurf(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	emit_windsurf_agents_md(mut result, mut records, graph, product, out_dir, output_root)
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'), output_root)
	for agent_id in product.included_agents {
		agent := graph.agents[agent_id] or {
			result.warnings << "Agent '${agent_id}' not found — skipping"
			result.omitted << 'agent:${agent_id}'
			continue
		}
		if !os.is_file(agent.source_path) {
			result.warnings << 'Agent source missing: ${agent.source_path}'
			result.omitted << 'agent:${agent_id}'
			continue
		}
		body := os.read_file(agent.source_path) or {
			result.errors << 'read agent failed: ${err}'
			return
		}
		header := '---\ndescription: ${json_escape(agent.name)}\nalwaysApply: true\n---\n\n'
		path := os.join_path(out_dir, 'rules', '${agent.name}.mdc')
		write_text_artifact(path, header + body, agent.source_path, output_root, mut result, mut records)
		result.emitted << 'rule:${agent_id}'
	}
	result.unsupported << 'hooks — no official Windsurf extension format for lifecycle hooks'
	result.unsupported << 'mcp — no official Windsurf MCP configuration format'
	result.unsupported << 'memories — intentionally NOT generated; personal per-user state (ADR-002)'
	result.unsupported << 'plugin-manifest — Windsurf has no marketplace; no manifest format to target'
}

fn emit_windsurf_agents_md(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	mut lines := []string{}
	name := if product.name.len > 0 { product.name } else { product.id }
	lines << '# ${name}'
	lines << ''
	lines << product.description
	lines << ''
	if product.included_skills.len > 0 {
		lines << '## Available Skills'
		lines << ''
		for skill_id in product.included_skills {
			skill := graph.skills[skill_id] or { continue }
			lines << '- **${skill.name}**: ${skill.id}'
		}
		lines << ''
	}
	if product.included_agents.len > 0 {
		lines << '## Available Agents'
		lines << ''
		for agent_id in product.included_agents {
			agent := graph.agents[agent_id] or { continue }
			lines << '- **${agent.name}**: ${agent.id}'
		}
		lines << ''
	}
	lines << '## Scope'
	lines << ''
	lines << 'These instructions are project-scoped. Rules in `rules/` provide always-on behavioral constraints. Skills in `skills/` are on-demand procedures invoked explicitly.'
	lines << ''
	write_text_artifact(os.join_path(out_dir, 'AGENTS.md'), lines.join('\n'), 'generated', output_root, mut result, mut records)
	result.emitted << 'AGENTS.md'
}

fn emit_pi(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	emit_pi_package_json(mut result, mut records, graph, product, out_dir, output_root)
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'), output_root)
	emit_agents_under(mut result, mut records, graph, product, os.join_path(out_dir, 'agents'), output_root)
	result.unsupported << 'lifecycle hooks — requires TypeScript ExtensionAPI (packages/pi-package/)'
	result.unsupported << 'custom tools — requires TypeScript ExtensionAPI with tool registration'
	result.unsupported << 'MCP server config — no static format; requires TypeScript runtime'
	result.unsupported << 'session state — runtime only; not expressible in static assets'
	result.unsupported << 'plugin marketplace install — Pi uses npm/pi.dev registry, not a marketplace'
}

fn emit_pi_package_json(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	ver := resolve_toolkit_version()
	mut skill_paths := []string{}
	for skill_id in product.included_skills {
		skill := graph.skills[skill_id] or { continue }
		skill_paths << '"skills/${skill.name}/SKILL.md"'
	}
	mut agent_paths := []string{}
	for agent_id in product.included_agents {
		agent := graph.agents[agent_id] or { continue }
		agent_paths << '"agents/${agent.name}/AGENT.md"'
	}
	kw := product.id.replace('agent-toolkit-', '')
	body := '{\n' + '  "name": "@agent-toolkit/${json_escape(product.id)}",\n' + '  "version": "${json_escape(ver)}",\n' + '  "description": "${json_escape(product.description)}",\n' + '  "license": "MIT",\n' + '  "repository": {\n' + '    "type": "git",\n' + '    "url": "https://github.com/ulises-jeremias/agent-toolkit"\n' + '  },\n' + '  "keywords": [\n' + '    "agent-toolkit",\n' + '    "pi",\n' + '    "skills",\n' + '    "agents",\n' + '    "${json_escape(kw)}"\n' + '  ],\n' + '  "pi": {\n' + '    "skills": [\n      ${skill_paths.join(',\n      ')}\n    ],\n' + '    "agents": [\n      ${agent_paths.join(',\n      ')}\n    ]\n' + '  }\n}\n'
	write_text_artifact(os.join_path(out_dir, 'pi-package.json'), body, 'generated', output_root, mut result, mut records)
	result.emitted << 'pi-package-json'
}

fn emit_gemini_cli(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	ver := resolve_toolkit_version()
	manifest := '{\n' + '  "name": "${json_escape(product.id)}",\n' + '  "version": "${json_escape(ver)}",\n' + '  "description": "${json_escape(product.description)}",\n' + '  "author": "ulises-jeremias",\n' + '  "repository": "https://github.com/ulises-jeremias/agent-toolkit",\n' + '  "license": "MIT",\n' + '  "geminiCliVersion": ">=0.1.0",\n' + '  "contextFiles": [],\n' + '  "commands": "\${extensionPath}/commands.toml"\n}\n'
	write_text_artifact(os.join_path(out_dir, 'gemini-extension.json'), manifest, 'generated', output_root, mut result, mut records)
	result.emitted << 'extension-manifest'

	mut toml_lines := []string{}
	for skill_id in product.included_skills {
		skill := graph.skills[skill_id] or {
			result.warnings << "Skill '${skill_id}' not found — skipping"
			result.omitted << 'skill:${skill_id}'
			continue
		}
		if !os.is_file(skill.source_path) {
			result.warnings << 'Skill source missing: ${skill.source_path}'
			result.omitted << 'skill:${skill_id}'
			continue
		}
		dst_dir := os.join_path(out_dir, 'skills', skill.name)
		os.mkdir_all(dst_dir) or {
			result.errors << 'mkdir skill dir failed: ${err}'
			return
		}
		content := os.read_file(skill.source_path) or {
			result.errors << 'read skill failed: ${err}'
			return
		}
		write_text_artifact(os.join_path(dst_dir, 'SKILL.md'), content, skill.source_path, output_root, mut result, mut records)
		copy_skill_references(skill, dst_dir, output_root, mut result, mut records)
		rel := 'skills/${skill.name}/SKILL.md'
		safe_name := skill.name.replace('-', '_').replace(' ', '_')
		desc := skill.id.replace('"', "'")
		toml_lines << '[[commands]]'
		toml_lines << 'name = "${safe_name}"'
		toml_lines << 'description = "${desc}"'
		toml_lines << 'prompt = """'
		toml_lines << 'Follow the `${skill.name}` skill instructions for {{args}}.'
		toml_lines << ''
		toml_lines << '@{${rel}}'
		toml_lines << '"""'
		toml_lines << ''
		result.emitted << 'skill:${skill_id}'
	}
	if toml_lines.len > 0 {
		write_text_artifact(os.join_path(out_dir, 'commands.toml'), toml_lines.join('\n') + '\n', 'generated', output_root, mut result, mut records)
		result.emitted << 'commands.toml'
	}
	for agent_id in product.included_agents {
		agent := graph.agents[agent_id] or {
			result.warnings << "Agent '${agent_id}' not found — skipping"
			result.omitted << 'agent:${agent_id}'
			continue
		}
		if !os.is_file(agent.source_path) {
			result.warnings << 'Agent source missing: ${agent.source_path}'
			result.omitted << 'agent:${agent_id}'
			continue
		}
		content := os.read_file(agent.source_path) or {
			result.errors << 'read agent failed: ${err}'
			return
		}
		path := os.join_path(out_dir, 'context', '${agent.name}.md')
		write_text_artifact(path, content, agent.source_path, output_root, mut result, mut records)
		result.emitted << 'agent:${agent_id}'
	}
	result.unsupported << 'hooks (hooks/hooks.json — pending canonical hook model #16)'
	result.unsupported << 'mcp (mcpServers — pending MCP registry #15; field reserved in manifest)'
	result.unsupported << 'excludeTools (tool restrictions — pending agent model with abstract tools)'
}

fn emit_muse_code(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'), output_root)
	emit_agents_under(mut result, mut records, graph, product, os.join_path(out_dir, 'agents'), output_root)
	result.unsupported << 'plugin-marketplace — Muse Code has no marketplace; install via muse skills install / .agents/skills'
}

fn emit_codex(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	ver := resolve_toolkit_version()
	kw := product.id.replace('agent-toolkit-', '')
	body := '{\n' + '  "name": "${json_escape(product.id)}",\n' + '  "version": "${json_escape(ver)}",\n' + '  "description": "${json_escape(product.description)}",\n' + '  "maturity": "experimental",\n' + '  "author": {\n' + '    "name": "ulises-jeremias",\n' + '    "email": "ulisescf.24@gmail.com"\n' + '  },\n' + '  "homepage": "https://github.com/ulises-jeremias/agent-toolkit",\n' + '  "repository": "https://github.com/ulises-jeremias/agent-toolkit",\n' + '  "license": "MIT",\n' + '  "keywords": [\n' + '    "agent-toolkit",\n' + '    "${json_escape(kw)}",\n' + '    "codex",\n' + '    "skills",\n' + '    "agents"\n' + '  ]\n}\n'
	write_text_artifact(os.join_path(out_dir, '.codex-plugin', 'plugin.json'), body, 'generated', output_root, mut result, mut records)
	result.emitted << 'plugin-manifest'
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'), output_root)
	emit_agents_under(mut result, mut records, graph, product, os.join_path(out_dir, 'agents'), output_root)
	result.unsupported << 'hooks — unknown-blocked: lifecycle hooks not confirmed in official Codex plugin docs'
	result.unsupported << 'mcp — unknown-blocked: MCP integration not confirmed in official Codex plugin docs'
	result.warnings << "Codex plugin API is experimental (maturity='experimental'). Do NOT submit to Codex marketplace without explicit OpenAI authorization."
}

fn emit_agent_plugins(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string, repo_root string) {
	ver := resolve_toolkit_version()
	mut keywords := ['agent-toolkit', product.id.replace('agent-toolkit-', '')]
	if product.id == 'agent-toolkit-core' {
		keywords = ['agent-toolkit', 'core', 'skills', 'agents']
	} else if product.id == 'agent-toolkit-complete' {
		keywords = ['agent-toolkit', 'complete', 'skills', 'agents', 'mcp']
	}
	mut kw_json := []string{}
	for k in keywords {
		kw_json << '"${json_escape(k)}"'
	}
	mut has_agents := product.included_agents.len > 0
	mut has_hooks := product.included_hooks.len > 0
	mut ext_entries := []string{}
	if has_agents || has_hooks {
		mut claude_inner := []string{}
		if has_agents {
			claude_inner << '"agents": "com.anthropic.claude-code/agents/"'
		}
		if has_hooks {
			claude_inner << '"hooks": "com.anthropic.claude-code/hooks/"'
		}
		ext_entries << '"com.anthropic.claude-code": { ${claude_inner.join(', ')} }'
	}
	ext_entries << '"com.agent-toolkit.cli": { "product": "${json_escape(product.id)}", "stability": "${json_escape(product.stability)}" }'
	extensions_block := ',\n  "extensions": {\n    ${ext_entries.join(',\n    ')}\n  }'
	body := '{\n' + '  "\$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",\n' + '  "name": "${json_escape(product.id)}",\n' + '  "version": "${json_escape(ver)}",\n' + '  "description": "${json_escape(product.description)}",\n' + '  "author": {\n' + '    "name": "ulises-jeremias",\n' + '    "url": "https://github.com/ulises-jeremias/agent-toolkit"\n' + '  },\n' + '  "homepage": "https://github.com/ulises-jeremias/agent-toolkit",\n' + '  "repository": "https://github.com/ulises-jeremias/agent-toolkit",\n' + '  "license": "MIT",\n' + '  "keywords": [\n    ${kw_json.join(',\n    ')}\n  ]' + extensions_block + '\n}\n'
	write_text_artifact(os.join_path(out_dir, 'plugin.json'), body, 'generated', output_root, mut result, mut records)
	result.emitted << 'plugin-manifest'
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'), output_root)
	// Portable core must NOT contain agents/hooks/rules at top-level per spec §7 (skills + mcp only).
	// Emit them into extension namespace com.anthropic.claude-code/ where harness supports them.
	if has_agents {
		ext_agents_root := os.join_path(out_dir, 'com.anthropic.claude-code', 'agents')
		for agent_id in product.included_agents {
			agent := graph.agents[agent_id] or {
				result.warnings << "Agent '${agent_id}' not found — skipping extension emit"
				continue
			}
			if !os.is_file(agent.source_path) {
				continue
			}
			content := os.read_file(agent.source_path) or { continue }
			dst_dir := os.join_path(ext_agents_root, agent.name)
			os.mkdir_all(dst_dir) or { continue }
			dst := os.join_path(dst_dir, 'AGENT.md')
			write_text_artifact(dst, content, agent.source_path, output_root, mut result, mut records)
			result.emitted << 'extension-agent:${agent_id}'
		}
	}
	if has_hooks {
		ext_hooks_root := os.join_path(out_dir, 'com.anthropic.claude-code', 'hooks')
		os.mkdir_all(ext_hooks_root) or {}
		// Emit a marker README explaining extension content; hooks themselves emitted via dedicated hook emitter if product includes.
		write_text_artifact(os.join_path(ext_hooks_root, 'README.md'), '# Claude Code Extension (non-portable)\n\nClaude-specific hooks/agents live here per Agent Plugins §8. Portable clients ignore this namespace.\n', 'generated', output_root, mut result, mut records)
		result.emitted << 'extension-hooks'
	}
	// Portable MCP: emit mcp.json from canonical mcp/templates via registry_emit logic.
	wrote_mcp := emit_portable_mcp(mut result, mut records, graph, product, out_dir, output_root, repo_root)
	if !wrote_mcp && product.included_mcp.len > 0 {
		result.warnings << 'MCP requested (${product.included_mcp.join(', ')}) but no servers emitted — check mcp/templates'
	}
	if has_agents || has_hooks {
		result.unsupported << 'agents/hooks are not portable in Agent Plugins 1.0 — emitted via com.anthropic.claude-code/ extension (ignored by portable clients)'
	}
}
