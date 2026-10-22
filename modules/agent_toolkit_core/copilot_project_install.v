module agent_toolkit_core

import crypto.sha256
import os

pub struct CopilotProjectInstallReport {
pub mut:
	ok            bool
	message       string
	project       string
	path          string
	content       string
	status        string
	review_token  string
	files_written int
	files_removed int
	files         []CopilotProjectFile
}

// CopilotProjectFile is one file in a Copilot project install/removal review.
// state is new|current|preserved for installs and unchanged|modified|missing
// for removals. path is relative to the project root.
pub struct CopilotProjectFile {
pub:
	path  string
	kind  string
	state string
}

fn copilot_project_receipt_product(root string) string {
	return 'agent-toolkit-copilot-' + sha256.hexhash(root)[..12]
}

struct CopilotPlannedFile {
	dest    string
	rel     string
	kind    string
	content string
}

fn copilot_read_mapping_content(src string) ?string {
	if is_embedded_src(src) {
		return embedded_read_file(strip_embedded_prefix(src)) or { return none }
	}
	return os.read_file(src) or { return none }
}

// copilot_planned_files builds the full reviewed file set: the instruction
// profile plus the compiled Copilot repository Skills (.github/skills) and
// Agent Definitions (.github/agents/*.agent.md) from the canonical catalog.
// When the catalog is unavailable only the instructions are planned.
fn copilot_planned_files(root string, instructions string) []CopilotPlannedFile {
	mut planned := []CopilotPlannedFile{}
	planned << CopilotPlannedFile{
		dest: os.join_path(root, '.github', 'copilot-instructions.md')
		rel: '.github/copilot-instructions.md'
		kind: 'instructions'
		content: instructions
	}
	tr := find_toolkit_root() or { return planned }
	data_root := tr.path
	skills_dst := os.join_path(root, '.github', 'skills')
	skill_mappings := catalog_skill_mappings(data_root, skills_dst) or { []FileMapping{} }
	for m in skill_mappings {
		content := copilot_read_mapping_content(m.src) or { continue }
		planned << CopilotPlannedFile{
			dest: m.dst
			rel: m.dst[root.len + 1..].replace('\\', '/')
			kind: 'skill'
			content: content
		}
	}
	compiled := compiled_agent_files(data_root)
	mut agent_names := compiled.keys()
	agent_names.sort()
	for name in agent_names {
		content := copilot_read_mapping_content(compiled[name]) or { continue }
		planned << CopilotPlannedFile{
			dest: os.join_path(root, '.github', 'agents', '${name}.agent.md')
			rel: '.github/agents/${name}.agent.md'
			kind: 'agent'
			content: content
		}
	}
	return planned
}

fn copilot_install_state(dest string, content string) string {
	if !os.is_file(dest) {
		return 'new'
	}
	existing := os.read_file(dest) or { return 'preserved' }
	return if existing == content { 'current' } else { 'preserved' }
}

fn copilot_files_of(planned []CopilotPlannedFile, states []string) []CopilotProjectFile {
	mut files := []CopilotProjectFile{}
	for i, p in planned {
		files << CopilotProjectFile{
			path: p.rel
			kind: p.kind
			state: states[i]
		}
	}
	return files
}

fn copilot_install_token(project_root string, project string, planned []CopilotPlannedFile, states []string) string {
	mut parts := []string{}
	parts << project_root
	parts << project
	for i, p in planned {
		current := if os.is_file(p.dest) {
			sha256.hexhash(os.read_file(p.dest) or { '' })
		} else {
			'absent'
		}
		parts << '${p.rel}\n${sha256.hexhash(p.content)}\n${states[i]}\n${current}'
	}
	return sha256.hexhash(parts.join('\n'))
}

// copilot_project_install previews or installs the Toolkit Copilot repository
// set (instructions, Skills and Agent Definitions) in one workspace-linked
// project. Existing project files are never overwritten by this operation.
pub fn copilot_project_install(workspace string, project string, review_token string, apply bool, receipt_dir string) CopilotProjectInstallReport {
	root := resolve_project_files_root(workspace, project) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not resolve a linked project: ${err}', project: project }
	}
	github_dir := os.join_path(root, '.github')
	if os.is_link(github_dir) {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The project contains a symbolic link at the Copilot destination. No files were changed.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'unsafe-path'
		}
	}
	if os.exists(github_dir) && !os.is_dir(github_dir) {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The project already has a non-directory .github path. No files were changed.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'path-conflict'
		}
	}
	instructions := embedded_read_file('profiles/copilot/copilot-instructions.md') or {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The packaged GitHub Copilot profile is unavailable: ${err}'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'unavailable'
		}
	}
	project_root := os.real_path(root)
	planned := copilot_planned_files(project_root, instructions)
	for p in planned {
		if install_path_has_symlink_component(p.dest) {
			return CopilotProjectInstallReport{
				ok: false
				message: 'The project contains a symbolic link at a Copilot destination. No files were changed.'
				project: project
				path: '.github/copilot-instructions.md'
				status: 'unsafe-path'
			}
		}
	}
	mut states := []string{}
	for p in planned {
		states << copilot_install_state(p.dest, p.content)
	}
	files := copilot_files_of(planned, states)
	token := copilot_install_token(project_root, project, planned, states)
	if apply && (review_token.len == 0 || review_token != token) {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The project changed after review. Nothing was written; review the current project state again.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'stale-review'
			files: files
		}
	}
	new_count := states.filter(it == 'new').len
	preserved_count := states.filter(it == 'preserved').len
	if new_count == 0 && preserved_count == 0 {
		return CopilotProjectInstallReport{
			ok: true
			message: 'The Agent Toolkit Copilot repository set is already present and matches the bundled version. No files were changed.'
			project: project
			path: '.github/copilot-instructions.md'
			content: instructions
			status: 'current'
			review_token: token
			files: files
		}
	}
	if new_count == 0 {
		return CopilotProjectInstallReport{
			ok: true
			message: 'Existing project files differ from the Toolkit Copilot set and are preserved. Review or move them yourself before installing.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'preserved-existing'
			review_token: token
			files: files
		}
	}
	if !apply {
		return CopilotProjectInstallReport{
			ok: true
			message: 'Review ${new_count} new file(s) for this project’s .github folder (${planned.len} reviewed in total). Existing files are never overwritten.'
			project: project
			path: '.github/copilot-instructions.md'
			content: instructions
			status: 'ready'
			review_token: token
			files: files
		}
	}
	// Remember prior receipt artifacts so files that are already current stay
	// owned by the receipt after this install writes a fresh one.
	product := copilot_project_receipt_product(project_root)
	dir := if receipt_dir.len > 0 { receipt_dir } else { default_receipt_dir() }
	prior_receipt := load_install_receipt('copilot-repository', product, dir)
	mut tx := new_install_transaction('copilot-repository', InstallTxOptions{
		product: product
		scope: 'project:${project_root}'
		receipt_dir: receipt_dir
		toolkit_root: ''
	})
	for i, p in planned {
		if states[i] != 'new' {
			continue
		}
		tx.stage_write(p.dest, p.content) or {
			return CopilotProjectInstallReport{ ok: false, message: 'Could not stage the Copilot repository set: ${err}', project: project, path: '.github/copilot-instructions.md', status: 'failed', files: files }
		}
	}
	tx.commit() or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not safely install the Copilot repository set: ${err}', project: project, path: '.github/copilot-instructions.md', status: 'failed', files: files }
	}
	if tx.receipt.artifacts.len == 0 {
		return CopilotProjectInstallReport{ ok: false, message: 'The destination changed during installation. No receipt was recorded; review the project again.', project: project, path: '.github/copilot-instructions.md', status: 'stale-review', files: files }
	}
	written := tx.receipt.artifacts.len
	if prior := prior_receipt {
		mut recorded := map[string]bool{}
		for a in tx.receipt.artifacts {
			recorded[a.path] = true
		}
		mut merged := tx.receipt
		mut added := false
		for a in prior.artifacts {
			if a.path in recorded {
				continue
			}
			// Keep prior ownership only for files still identical to the plan.
			for p in planned {
				if p.dest == a.path && copilot_install_state(p.dest, p.content) == 'current'
					&& receipt_artifact_digest(p.dest) == a.digest {
					merged.artifacts << a
					added = true
					break
				}
			}
		}
		if added {
			save_install_receipt(mut merged, dir) or {}
		}
	}
	mut message := 'Installed ${written} Agent Toolkit Copilot file(s) in ${project} (.github/copilot-instructions.md, .github/skills, .github/agents). Restart or reopen Copilot in that repository to load them.'
	if preserved_count > 0 {
		message += ' ${preserved_count} existing file(s) were preserved untouched.'
	}
	return CopilotProjectInstallReport{
		ok: true
		message: message
		project: project
		path: '.github/copilot-instructions.md'
		content: instructions
		status: 'installed'
		review_token: token
		files_written: written
		files: files
	}
}

// copilot_rmdir_empty_tree removes dir and any empty subdirectories,
// deepest first. Non-empty directories are left alone.
fn copilot_rmdir_empty_tree(dir string) {
	for entry in os.ls(dir) or { return } {
		child := os.join_path(dir, entry)
		if os.is_dir(child) && !os.is_link(child) {
			copilot_rmdir_empty_tree(child)
		}
	}
	os.rmdir(dir) or {}
}

// copilot_project_remove previews or removes every unchanged file recorded
// in the Copilot project receipt. If any receipted file was edited after
// installation, nothing is removed and all files are preserved.
pub fn copilot_project_remove(workspace string, project string, review_token string, apply bool, receipt_dir string) CopilotProjectInstallReport {
	root := resolve_project_files_root(workspace, project) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not resolve a linked project: ${err}', project: project }
	}
	project_root := os.real_path(root)
	github_dir := os.join_path(project_root, '.github')
	if os.is_link(github_dir) {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The project now contains a symbolic link at the Copilot destination. No files were removed.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'unsafe-path'
		}
	}
	product := copilot_project_receipt_product(project_root)
	dir := if receipt_dir.len > 0 { receipt_dir } else { default_receipt_dir() }
	receipt_path := os.join_path(dir, receipt_filename('copilot-repository', product))
	receipt_text := os.read_file(receipt_path) or {
		return CopilotProjectInstallReport{
			ok: false
			message: 'No Agent Toolkit receipt proves ownership of these project files. Nothing was removed.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'no-receipt'
		}
	}
	receipt := parse_install_receipt(receipt_text) or {
		return CopilotProjectInstallReport{ ok: false, message: 'The project receipt is invalid. Nothing was removed.', project: project, path: '.github/copilot-instructions.md', status: 'invalid-receipt' }
	}
	if receipt.target != 'copilot-repository' || receipt.product != product || receipt.scope != 'project:${project_root}' || receipt.artifacts.len == 0 {
		return CopilotProjectInstallReport{ ok: false, message: 'The receipt does not identify Toolkit-owned project files. Nothing was removed.', project: project, path: '.github/copilot-instructions.md', status: 'invalid-receipt' }
	}
	github_prefix := github_dir + os.path_separator
	mut files := []CopilotProjectFile{}
	mut states := []string{}
	for a in receipt.artifacts {
		if a.ownership != 'created' || !a.path.starts_with(github_prefix) || install_path_has_symlink_component(a.path) {
			return CopilotProjectInstallReport{ ok: false, message: 'The receipt does not identify Toolkit-owned project files. Nothing was removed.', project: project, path: '.github/copilot-instructions.md', status: 'invalid-receipt' }
		}
		state := if !os.is_file(a.path) {
			'missing'
		} else if receipt_artifact_digest(a.path) == a.digest {
			'unchanged'
		} else {
			'modified'
		}
		states << state
		rel := a.path[project_root.len + 1..].replace('\\', '/')
		kind := if rel == '.github/copilot-instructions.md' {
			'instructions'
		} else if rel.starts_with('.github/skills/') {
			'skill'
		} else {
			'agent'
		}
		files << CopilotProjectFile{
			path: rel
			kind: kind
			state: state
		}
	}
	mut token_parts := []string{}
	token_parts << project_root
	token_parts << project
	token_parts << sha256.hexhash(receipt_text)
	for i, a in receipt.artifacts {
		token_parts << '${a.path}\n${states[i]}\n${receipt_artifact_digest(a.path)}'
	}
	token := sha256.hexhash(token_parts.join('\n'))
	if apply && (review_token.len == 0 || review_token != token) {
		return CopilotProjectInstallReport{ ok: false, message: 'The files changed after removal review. Nothing was removed; review the current project state again.', project: project, path: '.github/copilot-instructions.md', status: 'stale-review', files: files }
	}
	present := states.filter(it != 'missing').len
	if present == 0 {
		return CopilotProjectInstallReport{ ok: true, message: 'The receipted Copilot files are already absent. No project file was changed.', project: project, path: '.github/copilot-instructions.md', status: 'already-absent', files: files }
	}
	if states.contains('modified') {
		return CopilotProjectInstallReport{
			ok: true
			message: 'Some Copilot files changed after Agent Toolkit created them. All project files and the receipt are preserved.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'modified'
			review_token: token
			files: files
		}
	}
	if !apply {
		return CopilotProjectInstallReport{
			ok: true
			message: 'Review removal of ${present} unchanged, receipt-owned Copilot file(s) under .github. No other project files will be touched.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'ready-remove'
			review_token: token
			files: files
		}
	}
	mut removed := 0
	for i, a in receipt.artifacts {
		if states[i] == 'missing' {
			continue
		}
		quarantine := '${a.path}.agent-toolkit-removal-${os.getpid()}'
		if os.exists(quarantine) || os.is_link(quarantine) {
			return CopilotProjectInstallReport{ ok: false, message: 'A recovery file already exists beside a destination. Removal stopped; files already removed stay removed and the receipt is preserved.', project: project, path: '.github/copilot-instructions.md', status: 'recovery-conflict', files_removed: removed, files: files }
		}
		os.rename(a.path, quarantine) or {
			return CopilotProjectInstallReport{ ok: false, message: 'Could not safely quarantine a project file: ${err}', project: project, path: '.github/copilot-instructions.md', status: 'failed', files_removed: removed, files: files }
		}
		if os.is_link(quarantine) || receipt_artifact_digest(quarantine) != a.digest {
			if !os.exists(a.path) && !os.is_link(a.path) {
				os.rename(quarantine, a.path) or {
					return CopilotProjectInstallReport{ ok: false, message: 'A file changed during removal and could not be restored automatically. It is preserved at ${quarantine}.', project: project, path: '.github/copilot-instructions.md', status: 'recovery-required', files_removed: removed, files: files }
				}
			}
			return CopilotProjectInstallReport{ ok: false, message: 'A file changed during removal. It was preserved; review the project again.', project: project, path: '.github/copilot-instructions.md', status: 'stale-review', files_removed: removed, files: files }
		}
		os.rm(quarantine) or {
			return CopilotProjectInstallReport{ ok: false, message: 'Could not remove a quarantined file; it is preserved at ${quarantine}.', project: project, path: '.github/copilot-instructions.md', status: 'recovery-required', files_removed: removed, files: files }
		}
		removed++
	}
	// Best-effort cleanup of now-empty skill/agent directories.
	for sub in ['skills', 'agents'] {
		sub_dir := os.join_path(github_dir, sub)
		if os.is_dir(sub_dir) && !os.is_link(sub_dir) {
			copilot_rmdir_empty_tree(sub_dir)
		}
	}
	os.rm(receipt_path) or {
		return CopilotProjectInstallReport{ ok: false, message: 'The Copilot files were removed, but the receipt remains at ${receipt_path}. Refresh installation evidence to reconcile it.', project: project, path: '.github/copilot-instructions.md', status: 'receipt-cleanup-required', files_removed: removed, files: files }
	}
	return CopilotProjectInstallReport{
		ok: true
		message: 'Removed ${removed} unchanged Agent Toolkit Copilot file(s) from ${project}. Other files in .github were left alone.'
		project: project
		path: '.github/copilot-instructions.md'
		status: 'removed'
		files_removed: removed
		files: files
	}
}
