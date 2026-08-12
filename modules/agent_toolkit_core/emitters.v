module agent_toolkit_core

import os

// CompilationResult mirrors Python compiler/model.CompilationResult diagnostics.
pub struct CompilationResult {
pub mut:
	target      string
	product     string
	emitted     []string
	transformed []string
	omitted     []string
	unsupported []string
	warnings    []string
	errors      []string
	artifacts   []string
}

// is_valid reports whether compilation produced no errors.
pub fn (r CompilationResult) is_valid() bool {
	return r.errors.len == 0
}

// report returns a human-readable compilation summary.
pub fn (r CompilationResult) report() string {
	mut lines := []string{}
	lines << 'Target: ${r.target}  Product: ${r.product}'
	if r.emitted.len > 0 {
		lines << '  ✓ emitted:     ${r.emitted.join(', ')}'
	}
	if r.transformed.len > 0 {
		lines << '  ~ transformed: ${r.transformed.join(', ')}'
	}
	if r.omitted.len > 0 {
		lines << '  - omitted:     ${r.omitted.join(', ')}'
	}
	if r.unsupported.len > 0 {
		lines << '  ✗ unsupported: ${r.unsupported.join(', ')}'
	}
	for w in r.warnings {
		lines << '  ⚠ ${w}'
	}
	for e in r.errors {
		lines << '  ✗ ERROR: ${e}'
	}
	return lines.join('\n')
}

// tier1_targets lists the Tier-1 emitter ids (#509).
pub fn tier1_targets() []string {
	return ['cursor', 'claude-code', 'opencode']
}

// is_tier1_target reports whether target_id is a Tier-1 emitter.
pub fn is_tier1_target(target_id string) bool {
	return target_id in tier1_targets()
}

// compile_tier1 compiles one Tier-1 product→target into output_root/<product>/.
// Callers use a temp output_root for dry-run / --check.
pub fn compile_tier1(target_id string, graph CanonicalGraph, product LoadedProduct, output_root string, repo_root string) CompilationResult {
	mut result := CompilationResult{
		target:  target_id
		product: product.id
	}
	if !is_tier1_target(target_id) {
		result.errors << "unknown Tier-1 target '${target_id}'"
		return result
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
	match target_id {
		'cursor' {
			emit_cursor(mut result, mut records, graph, product, out_dir, output_root)
		}
		'claude-code' {
			emit_claude_code(mut result, mut records, graph, product, out_dir, output_root)
		}
		'opencode' {
			emit_opencode(mut result, mut records, graph, product, out_dir, output_root)
		}
		else {
			result.errors << "unknown Tier-1 target '${target_id}'"
		}
	}
	_ = repo_root
	if result.is_valid() && records.len > 0 {
		prov := write_provenance(out_dir, product.id, target_id, records) or {
			result.warnings << 'provenance write skipped: ${err}'
			return result
		}
		result.artifacts << prov
		result.emitted << 'provenance'
	}
	return result
}

fn emit_cursor(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	manifest_path := os.join_path(out_dir, '.cursor-plugin', 'plugin.json')
	keywords := ['agent-toolkit', product.id.replace('agent-toolkit-', ''), 'cursor', 'skills',
		'agents']
	write_plugin_manifest(manifest_path, product, keywords, output_root, mut result, mut records)
	if result.errors.len > 0 {
		return
	}
	result.emitted << 'plugin-manifest'
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'),
		output_root)
	emit_agents_under(mut result, mut records, graph, product, os.join_path(out_dir, 'agents'),
		output_root)
	result.unsupported << 'hooks (pending canonical hook model — Cursor uses workspaceOpen/sessionStart events)'
	result.unsupported << 'mcp (.cursor/mcp.json — user configures manually; not bundled in plugin)'
	result.unsupported << 'cursor-rules (.mdc) — generated as a separate profile surface, not in plugin bundle'
}

fn emit_claude_code(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	manifest_path := os.join_path(out_dir, '.claude-plugin', 'plugin.json')
	keywords := ['agent-toolkit', product.id.replace('agent-toolkit-', '')]
	write_plugin_manifest(manifest_path, product, keywords, output_root, mut result, mut records)
	if result.errors.len > 0 {
		return
	}
	result.emitted << 'plugin-manifest'
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, 'skills'),
		output_root)
	emit_agents_under(mut result, mut records, graph, product, os.join_path(out_dir, 'agents'),
		output_root)
	if product.included_hooks.len == 0 {
		result.unsupported << 'hooks (hooks/hooks.json — none included for this product)'
	} else {
		result.unsupported << 'hooks (registry emit not yet ported to V Tier-1)'
	}
	if product.included_mcp.len == 0 {
		result.unsupported << '.mcp.json (none included for this product)'
	} else {
		result.unsupported << '.mcp.json (registry emit not yet ported to V Tier-1)'
	}
}

fn emit_opencode(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, out_dir string, output_root string) {
	cfg_path := os.join_path(out_dir, 'opencode.json')
	cfg := '{\n  "\$schema": "https://opencode.ai/config.schema.json"\n}\n'
	write_text_artifact(cfg_path, cfg, 'generated', output_root, mut result, mut records)
	if result.errors.len > 0 {
		return
	}
	result.emitted << 'opencode-config'
	emit_skills_under(mut result, mut records, graph, product, os.join_path(out_dir, '.opencode',
		'skills'), output_root)
	emit_agents_under(mut result, mut records, graph, product, os.join_path(out_dir, '.opencode',
		'agents'), output_root)
	result.unsupported << 'lifecycle hooks — requires packages/opencode-plugin/ TypeScript runtime (issue #10)'
	result.unsupported << 'custom tools — requires TypeScript plugin with tool registration API'
	result.unsupported << 'MCP server config — requires TypeScript plugin (no static opencode.json format)'
	result.unsupported << 'model/tool-call interception — requires TypeScript plugin'
	result.unsupported << 'plugin marketplace install — OpenCode uses npm/Bun; no marketplace format'
}

fn emit_skills_under(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, skills_root string, output_root string) {
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
		dst_dir := os.join_path(skills_root, skill.name)
		os.mkdir_all(dst_dir) or {
			result.errors << 'mkdir skill dir failed: ${err}'
			return
		}
		content := os.read_file(skill.source_path) or {
			result.errors << 'read skill failed: ${err}'
			return
		}
		dst := os.join_path(dst_dir, 'SKILL.md')
		write_text_artifact(dst, content, skill.source_path, output_root, mut result, mut records)
		copy_skill_references(skill, dst_dir, output_root, mut result, mut records)
		result.emitted << 'skill:${skill_id}'
	}
}

fn emit_agents_under(mut result CompilationResult, mut records []ArtifactRecord, graph CanonicalGraph, product LoadedProduct, agents_root string, output_root string) {
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
		dst_dir := os.join_path(agents_root, agent.name)
		os.mkdir_all(dst_dir) or {
			result.errors << 'mkdir agent dir failed: ${err}'
			return
		}
		content := os.read_file(agent.source_path) or {
			result.errors << 'read agent failed: ${err}'
			return
		}
		dst := os.join_path(dst_dir, 'AGENT.md')
		write_text_artifact(dst, content, agent.source_path, output_root, mut result, mut records)
		result.emitted << 'agent:${agent_id}'
	}
}

fn copy_skill_references(skill LoadedSkill, dst_dir string, output_root string, mut result CompilationResult, mut records []ArtifactRecord) {
	refs_src := os.join_path(os.dir(skill.source_path), 'references')
	if !os.is_dir(refs_src) {
		return
	}
	files := collect_all_files(refs_src)
	skill_root := os.dir(skill.source_path)
	for src in files {
		rel := relative_to(src, skill_root) or {
			result.errors << 'skill:${skill.id}: path escapes containment root'
			continue
		}
		dst := os.join_path(dst_dir, rel)
		os.mkdir_all(os.dir(dst)) or {
			result.errors << 'mkdir references failed: ${err}'
			return
		}
		content := os.read_file(src) or {
			result.errors << 'read reference failed: ${err}'
			return
		}
		write_text_artifact(dst, content, src, output_root, mut result, mut records)
	}
}

fn write_plugin_manifest(path string, product LoadedProduct, keywords []string, output_root string, mut result CompilationResult, mut records []ArtifactRecord) {
	ver := resolve_toolkit_version()
	mut kw_json := []string{}
	for k in keywords {
		kw_json << '"${json_escape(k)}"'
	}
	body := '{\n' + '  "name": "${json_escape(product.id)}",\n' +
		'  "version": "${json_escape(ver)}",\n' +
		'  "description": "${json_escape(product.description)}",\n' +
		'  "author": {\n' + '    "name": "ulises-jeremias",\n' +
		'    "email": "ulisescf.24@gmail.com"\n' + '  },\n' +
		'  "homepage": "https://github.com/ulises-jeremias/agent-toolkit",\n' +
		'  "repository": "https://github.com/ulises-jeremias/agent-toolkit",\n' +
		'  "license": "MIT",\n' + '  "keywords": [\n    ${kw_json.join(',\n    ')}\n  ]\n}\n'
	write_text_artifact(path, body, 'generated', output_root, mut result, mut records)
}

fn write_text_artifact(path string, content string, source_file string, output_root string, mut result CompilationResult, mut records []ArtifactRecord) {
	os.mkdir_all(os.dir(path)) or {
		result.errors << 'mkdir for ${path} failed: ${err}'
		return
	}
	os.write_file(path, content) or {
		result.errors << 'write ${path} failed: ${err}'
		return
	}
	result.artifacts << path
	rel := relative_to(path, output_root) or { os.file_name(path) }
	src_digest := if source_file != 'generated' && os.is_file(source_file) {
		file_digest(source_file)
	} else {
		'n/a'
	}
	records << ArtifactRecord{
		path:             rel.replace('\\', '/')
		source_file:      source_file
		source_digest:    src_digest
		generated_digest: file_digest(path)
	}
}

fn json_escape(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t',
		'\\t')
}

fn collect_all_files(dir string) []string {
	mut out := []string{}
	if !os.is_dir(dir) {
		return out
	}
	entries := os.ls(dir) or { return out }
	for e in entries {
		if e.starts_with('.') {
			continue
		}
		p := os.join_path(dir, e)
		if os.is_dir(p) {
			out << collect_all_files(p)
		} else if os.is_file(p) {
			out << p
		}
	}
	return out
}

fn relative_to(path string, root string) ?string {
	root_abs := os.real_path(root)
	path_abs := os.real_path(path)
	sep := os.path_separator
	prefix := root_abs.trim_right('/\\') + sep
	if path_abs == root_abs {
		return ''
	}
	if !path_abs.starts_with(prefix) {
		return none
	}
	return path_abs[prefix.len..]
}

// compilation_result_data flattens a CompilationResult for CommandResult JSON maps.
pub fn compilation_result_data(r CompilationResult) map[string]string {
	return {
		'target':      r.target
		'product':     r.product
		'ok':          if r.is_valid() { 'true' } else { 'false' }
		'emitted':     r.emitted.join('|')
		'omitted':     r.omitted.join('|')
		'unsupported': r.unsupported.join('|')
		'warnings':    r.warnings.join('|')
		'errors':      r.errors.join('|')
		'artifacts':   '${r.artifacts.len}'
	}
}
