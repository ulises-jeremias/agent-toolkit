module agent_toolkit_core

import os

// remaining_targets lists non-Tier-1 emitters (#552).
pub fn remaining_targets() []string {
	return [
		'copilot-cli',
		'copilot-repository',
		'windsurf',
		'pi',
		'gemini-cli',
		'muse-code',
		'codex',
		'agent-plugins',
	]
}

// all_emit_targets returns Tier-1 + remaining emitters.
pub fn all_emit_targets() []string {
	mut out := tier1_targets()
	out << remaining_targets()
	return out
}

// is_known_emit_target reports whether target_id has a V emitter (incl. aliases).
pub fn is_known_emit_target(target_id string) bool {
	id := normalize_emit_target(target_id)
	return is_tier1_target(id) || id in remaining_targets()
}

// compile_target dispatches Tier-1 and remaining emitters.
pub fn compile_target(target_id string, graph CanonicalGraph, product LoadedProduct, output_root string, repo_root string) CompilationResult {
	id := normalize_emit_target(target_id)
	if is_tier1_target(id) {
		return compile_tier1(id, graph, product, output_root, repo_root)
	}
	mut result := CompilationResult{
		target:  id
		product: product.id
	}
	if output_root.len == 0 {
		result.errors << 'output root is empty'
		return result
	}
	out_dir := os.join_path(output_root, product.id)
	os.mkdir_all(out_dir) or {
		result.errors << 'cannot create output dir: ${err}'
		return result
	}
	mut records := []ArtifactRecord{}
	match id {
		'copilot-cli' {
			emit_copilot_cli(mut result, mut records, graph, product, out_dir, output_root)
		}
		'copilot-repository' {
			emit_copilot_repository(mut result, mut records, graph, product, out_dir, output_root)
		}
		'windsurf' {
			emit_windsurf(mut result, mut records, graph, product, out_dir, output_root)
		}
		'pi' {
			emit_pi(mut result, mut records, graph, product, out_dir, output_root)
		}
		'gemini-cli' {
			emit_gemini_cli(mut result, mut records, graph, product, out_dir, output_root)
		}
		'muse-code' {
			emit_muse_code(mut result, mut records, graph, product, out_dir, output_root)
		}
		'codex' {
			emit_codex(mut result, mut records, graph, product, out_dir, output_root)
		}
		'agent-plugins' {
			emit_agent_plugins(mut result, mut records, graph, product, out_dir, output_root)
		}
		else {
			result.errors << "unknown emit target '${target_id}'"
		}
	}
	_ = repo_root
	if result.is_valid() && records.len > 0 {
		prov := write_provenance(out_dir, product.id, id, records) or {
			result.warnings << 'provenance write skipped: ${err}'
			return result
		}
		result.artifacts << prov
		result.emitted << 'provenance'
	}
	return result
}

fn emit_copilot_cli(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	manifest_path := os.join_path(out_dir, 'plugin.json')
	ver := resolve_toolkit_version()
	body := '{\n' + '  "name": "${json_escape(product.id)}",\n' +
		'  "version": "${json_escape(ver)}",\n' +
		'  "description": "${json_escape(product.description)}",\n' +
		'  "author": {\n' + '    "name": "ulises-jeremias",\n' +
		'    "url": "https://github.com/ulises-jeremias/agent-toolkit"\n' + '  },\n' +
		'  "repository": "https://github.com/ulises-jeremias/agent-toolkit",\n' +
		'  "license": "MIT",\n' + '  "skills": "skills/",\n' + '  "agents": "agents/"\n}\n'
	write_text_artifact(manifest_path, body, 'generated', output_root, mut result, mut records)
	if result.errors.len > 0 {
		return
	}
	result.emitted << 'plugin-manifest'
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'),
		output_root)
	emit_copilot_agents_flat(mut result, mut records, graph, product, os.join_path(out_dir, 'agents'),
		output_root)
	result.unsupported << 'hooks (cross-platform Bash+PowerShell handlers required — pending #16)'
	result.unsupported << 'mcp (unknown-blocked: not confirmed in official Copilot CLI docs)'
}

fn emit_copilot_repository(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	emit_copilot_instructions(mut result, mut records, graph, product, out_dir, output_root)
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, '.github',
		'skills'), output_root)
	emit_copilot_agents_flat(mut result, mut records, graph, product, os.join_path(out_dir, '.github',
		'agents'), output_root)
	result.unsupported << 'hooks (unknown-blocked for repository surface)'
	result.unsupported << 'mcp (unknown-blocked for repository surface)'
}

fn emit_copilot_instructions(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	mut lines := []string{}
	name := if product.name.len > 0 { product.name } else { product.id }
	lines << '# ${name}'
	lines << ''
	lines << product.description
	lines << ''
	lines << '## Available skills'
	lines << ''
	for skill_id in product.included_skills {
		skill := graph.skills[skill_id] or { continue }
		lines << '- **${skill.name}**: ${skill.id}'
	}
	lines << ''
	lines << '## Available agents'
	lines << ''
	for agent_id in product.included_agents {
		agent := graph.agents[agent_id] or { continue }
		lines << '- **${agent.name}**: ${agent.id}'
	}
	content := lines.join('\n') + '\n'
	path := os.join_path(out_dir, '.github', 'copilot-instructions.md')
	write_text_artifact(path, content, 'generated', output_root, mut result, mut records)
	result.emitted << 'copilot-instructions.md'
}

fn emit_copilot_agents_flat(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, agents_dir string, output_root string) {
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
		os.mkdir_all(agents_dir) or {
			result.errors << 'mkdir agents dir failed: ${err}'
			return
		}
		content := os.read_file(agent.source_path) or {
			result.errors << 'read agent failed: ${err}'
			return
		}
		dst := os.join_path(agents_dir, '${agent.name}.agent.md')
		write_text_artifact(dst, content, agent.source_path, output_root, mut result, mut records)
		result.emitted << 'agent:${agent_id}'
	}
}
