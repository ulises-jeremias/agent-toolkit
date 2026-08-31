module agent_toolkit_core

import crypto.sha256
import os

// DiffOptions configures `agent-toolkit diff` (Python cli/diff.py parity).
pub struct DiffOptions {
pub:
	target     string // empty = Tier-1 defaults
	product    string // empty = all products
	plugins_dir string // empty = <repo>/plugins
}

// DiffChangeSet is added/changed/removed relative paths for one product×target.
pub struct DiffChangeSet {
pub mut:
	added   []string
	changed []string
	removed []string
}

// DiffEntry is one product→target comparison result.
pub struct DiffEntry {
pub mut:
	target     string
	product    string
	changes    DiffChangeSet
	no_changes bool
	error      string
}

// DiffReport aggregates diff entries (exit non-zero when any changes / errors).
pub struct DiffReport {
pub mut:
	ok      bool
	entries []DiffEntry
	message string
}

// run_diff compiles into a temp tree and compares against committed plugins/.
pub fn run_diff(opts DiffOptions) DiffReport {
	mut report := DiffReport{
		ok: true
	}
	repo := find_repo_root() or {
		report.ok = false
		report.message = 'repo root not found: ${err}'
		return report
	}
	graph := load_graph(repo)
	if !graph.is_valid() {
		report.ok = false
		report.message = 'canonical graph load failed (${graph.errors.len} error(s))'
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
		if !is_tier1_target(opts.target) && !is_known_emit_target(opts.target) {
			report.ok = false
			report.message = "unknown target '${opts.target}'"
			return report
		}
		// Diff focuses on Tier-1 like Python defaults; allow explicit known targets.
		targets << normalize_emit_target(opts.target)
	} else {
		targets = tier1_targets()
	}
	plugins_root := if opts.plugins_dir.len > 0 {
		opts.plugins_dir
	} else {
		os.join_path(repo, 'plugins')
	}
	work_root := os.join_path(os.temp_dir(), 'agent-toolkit-diff-${os.getpid()}')
	os.mkdir_all(work_root) or {
		report.ok = false
		report.message = 'temp output mkdir failed: ${err}'
		return report
	}
	defer {
		os.rmdir_all(work_root) or {}
	}

	mut lines := []string{}
	lines << 'agent-toolkit diff'
	lines << 'Plugins: ${plugins_root}'
	lines << 'Targets: ${targets.join(', ')}  Products: ${products.len}'
	lines << ''

	for t in targets {
		for p in products {
			mut entry := DiffEntry{
				target:  t
				product: p.id
			}
			r := compile_target(t, graph, p, work_root, repo)
			if !r.is_valid() {
				entry.error = r.errors.join('; ')
				report.ok = false
				report.entries << entry
				lines << '  ✗  ${p.id} → ${t}: compile failed (${entry.error})'
				continue
			}
			entry.changes = diff_product_trees(os.join_path(work_root, p.id), os.join_path(plugins_root,
				p.id))
			entry.no_changes = entry.changes.added.len == 0 && entry.changes.changed.len == 0
				&& entry.changes.removed.len == 0
			report.entries << entry
			header := '~ ${p.id} → ${t}'
			if entry.no_changes {
				lines << '  ✓  ${header}: no changes'
			} else {
				report.ok = false
				lines << ''
				lines << '  ${header}:'
				for f in entry.changes.added {
					lines << '    + ${f}'
				}
				for f in entry.changes.changed {
					lines << '    ~ ${f}'
				}
				for f in entry.changes.removed {
					lines << '    - ${f}'
				}
			}
		}
	}
	lines << ''
	report.message = lines.join('\n')
	return report
}

// diff_result maps DiffReport to CommandResult.
pub fn diff_result(report DiffReport) CommandResult {
	mut changed := 0
	for e in report.entries {
		if !e.no_changes || e.error.len > 0 {
			changed++
		}
	}
	return CommandResult{
		command: 'diff'
		ok:      report.ok
		message: report.message
		data:    {
			'entries':  '${report.entries.len}'
			'changed':  '${changed}'
			'ok':       if report.ok { 'true' } else { 'false' }
		}
	}
}

fn diff_product_trees(built_dir string, current_dir string) DiffChangeSet {
	mut changes := DiffChangeSet{}
	built := list_rel_files(built_dir)
	mut built_set := map[string]bool{}
	for rel in built {
		built_set[rel] = true
		b_path := os.join_path(built_dir, rel)
		c_path := os.join_path(current_dir, rel)
		if !os.is_file(c_path) {
			changes.added << rel
			continue
		}
		if diff_file_digest(b_path) != diff_file_digest(c_path) {
			changes.changed << rel
		}
	}
	if os.is_dir(current_dir) {
		for rel in list_rel_files(current_dir) {
			if rel.ends_with('.provenance.json') {
				continue
			}
			if rel in built_set {
				continue
			}
			// Python currently does not populate removed (pass); keep empty for parity.
			_ = rel
		}
	}
	changes.added.sort()
	changes.changed.sort()
	changes.removed.sort()
	return changes
}

fn list_rel_files(root string) []string {
	mut out := []string{}
	if !os.is_dir(root) {
		return out
	}
	collect_rel_files(root, root, mut out)
	out.sort()
	return out
}

fn collect_rel_files(base string, dir string, mut out []string) {
	entries := os.ls(dir) or { return }
	for e in entries {
		path := os.join_path(dir, e)
		if os.is_dir(path) {
			collect_rel_files(base, path, mut out)
			continue
		}
		if !os.is_file(path) {
			continue
		}
		rel := relative_to(path, base) or { continue }
		norm := rel.replace('\\', '/')
		if norm.ends_with('.provenance.json') {
			continue
		}
		out << norm
	}
}

fn diff_file_digest(path string) string {
	data := os.read_file(path) or { return 'missing' }
	sum := sha256.hexhash(data)
	if sum.len < 12 {
		return sum
	}
	return sum[..12]
}
