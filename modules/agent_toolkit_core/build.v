module agent_toolkit_core

import os

// BuildReport aggregates Tier-1 compile / drift-check results for `build --check`.
pub struct BuildReport {
pub mut:
	ok          bool
	mode        string // check | build
	repo_root   string
	output_root string
	results     []CompilationResult
	drift       []string
	message     string
}

// BuildOptions configures agent-toolkit build / build --check.
pub struct BuildOptions {
pub:
	check       bool
	target      string // empty = all Tier-1
	product     string // empty = all products
	output_dir  string // empty = <repo>/plugins
	write_files bool   // false for --check (temp only)
}

// run_build executes Tier-1 compile (write) or dry-run + drift check.
pub fn run_build(opts BuildOptions) BuildReport {
	mut report := BuildReport{
		ok:   true
		mode: if opts.check { 'check' } else { 'build' }
	}
	repo := find_repo_root() or {
		report.ok = false
		report.message = 'repo root not found: ${err}'
		return report
	}
	report.repo_root = repo
	graph := load_graph(repo)
	if !graph.is_valid() {
		report.ok = false
		report.message = 'canonical graph load failed (${graph.errors.len} error(s))'
		report.drift << graph.errors
		return report
	}

	mut products := []LoadedProduct{}
	if opts.product.len > 0 {
		p := graph.select_product(opts.product) or {
			report.ok = false
			report.message = "product '${opts.product}' not found"
			return report
		}
		products << p
	} else {
		for _, p in graph.products {
			products << p
		}
	}

	mut targets := []string{}
	if opts.target.len > 0 {
		if !is_known_emit_target(opts.target) {
			report.ok = false
			report.message = "unknown emit target '${opts.target}' (available: ${all_emit_targets().join(', ')})"
			return report
		}
		targets << normalize_emit_target(opts.target)
	} else {
		targets = all_emit_targets()
	}

	output_root := if opts.output_dir.len > 0 {
		opts.output_dir
	} else {
		os.join_path(repo, 'plugins')
	}
	report.output_root = output_root

	write := opts.write_files && !opts.check
	mut work_root := output_root
	if !write {
		work_root = os.join_path(os.temp_dir(), 'agent-toolkit-check-${os.getpid()}')
		os.mkdir_all(work_root) or {
			report.ok = false
			report.message = 'temp output mkdir failed: ${err}'
			return report
		}
		defer {
			os.rmdir_all(work_root) or {}
		}
	}

	mut lines := []string{}
	lines << ''
	lines << 'Mode: ${report.mode}  Output: ${output_root}'
	lines << 'Targets: ${targets.join(', ')}  Products: ${products.len}'
	lines << ''

	for t in targets {
		for p in products {
			r := compile_target(t, graph, p, work_root, repo)
			report.results << r
			lines << r.report()
			lines << ''
			if !r.is_valid() {
				report.ok = false
			}
			if opts.check {
				if should_check_plugin_drift(p.id) {
					drift := detect_plugin_drift(work_root, output_root, p.id, t)
					report.drift << drift
					for d in drift {
						lines << '  DRIFT: ${d}'
						report.ok = false
					}
				}
			}
		}
	}

	if opts.check && report.ok {
		lines << '✅ build --check: Tier-1 compile + plugin drift OK'
	} else if opts.check && !report.ok {
		lines << '❌ build --check failed (compile errors and/or plugin drift)'
	} else if report.ok {
		lines << '✅ build complete'
	} else {
		lines << '❌ build failed'
	}
	report.message = lines.join('\n')
	return report
}

// detect_plugin_drift compares freshly emitted Tier-1 artifacts to committed plugins/.
fn detect_plugin_drift(work_root string, plugins_root string, product_id string, target_id string) []string {
	mut drift := []string{}
	plugin_product := os.join_path(plugins_root, product_id)
	if !os.is_dir(plugin_product) {
		return drift
	}
	work_product := os.join_path(work_root, product_id)
	pairs := drift_path_pairs(target_id, work_product, plugin_product)
	for pair in pairs {
		if !os.is_file(pair[0]) {
			continue
		}
		if !os.is_file(pair[1]) {
			drift << '${product_id}/${target_id}: missing in plugins: ${os.file_name(os.dir(pair[1]))}/${os.file_name(pair[1])}'
			continue
		}
		if file_digest(pair[0]) != file_digest(pair[1]) {
			rel := relative_to(pair[1], plugins_root) or { pair[1] }
			drift << 'content digest mismatch: ${rel.replace('\\', '/')}'
		}
	}
	return drift
}

// should_check_plugin_drift limits digest compare to shared plugin products
// (core/agents/forge) for digest parity with plugin check.
fn should_check_plugin_drift(product_id string) bool {
	return product_id in ['agent-toolkit-core', 'agent-toolkit-agents', 'agent-toolkit-forge']
}

fn drift_path_pairs(target_id string, work_product string, plugin_product string) [][]string {
	mut pairs := [][]string{}
	match target_id {
		'cursor', 'claude-code' {
			// Shared plugin surface (core/agents/forge) for digest parity with plugin check.
			pairs << skill_agent_pairs(os.join_path(work_product, 'skills'), os.join_path(plugin_product,
				'skills'), 'SKILL.md')
			pairs << skill_agent_pairs(os.join_path(work_product, 'agents'), os.join_path(plugin_product,
				'agents'), 'AGENT.md')
		}
		'opencode' {
			// Compile-validate only: committed `.opencode/` trees are often stale vs skills/
			// until `build` regenerates them. Drift for OpenCode lands with write-mode rebuild.
		}
		else {}
	}
	return pairs
}

fn skill_agent_pairs(work_dir string, plugin_dir string, filename string) [][]string {
	mut pairs := [][]string{}
	if !os.is_dir(work_dir) {
		return pairs
	}
	entries := os.ls(work_dir) or { return pairs }
	for e in entries {
		w := os.join_path(work_dir, e, filename)
		p := os.join_path(plugin_dir, e, filename)
		if os.is_file(w) {
			pairs << [w, p]
		}
	}
	return pairs
}

// build_result maps a BuildReport to CommandResult.
pub fn build_result(report BuildReport) CommandResult {
	mut data := map[string]string{}
	data['mode'] = report.mode
	data['ok'] = if report.ok { 'true' } else { 'false' }
	data['repo_root'] = report.repo_root
	data['output_root'] = report.output_root
	data['results'] = '${report.results.len}'
	data['drift_count'] = '${report.drift.len}'
	if report.drift.len > 0 {
		data['drift'] = report.drift.join('|')
	}
	mut emitted := []string{}
	for r in report.results {
		emitted << '${r.target}/${r.product}:${r.emitted.len}'
	}
	data['emitted_summary'] = emitted.join(',')
	return CommandResult{
		command: 'build'
		ok:      report.ok
		message: report.message
		data:    data
	}
}
