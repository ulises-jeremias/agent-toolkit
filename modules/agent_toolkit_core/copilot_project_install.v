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
}

fn copilot_project_receipt_product(root string) string {
	return 'agent-toolkit-copilot-' + sha256.hexhash(root)[..12]
}

// copilot_project_install previews or installs the Toolkit Copilot instruction
// profile in one workspace-linked project. Existing project files are never
// overwritten by this operation.
pub fn copilot_project_install(workspace string, project string, review_token string, apply bool, receipt_dir string) CopilotProjectInstallReport {
	root := resolve_project_files_root(workspace, project) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not resolve a linked project: ${err}', project: project }
	}
	github_dir := os.join_path(root, '.github')
	dest := os.join_path(github_dir, 'copilot-instructions.md')
	if os.is_link(github_dir) || os.is_link(dest) {
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
	content := embedded_read_file('profiles/copilot/copilot-instructions.md') or {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The packaged GitHub Copilot profile is unavailable: ${err}'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'unavailable'
		}
	}
	project_root := os.real_path(root)
	content_digest := sha256.hexhash(content)
	file_state := if os.is_file(dest) {
		'file:${sha256.hexhash(os.read_file(dest) or { '' })}'
	} else {
		'absent'
	}
	token := sha256.hexhash('${project_root}\n${project}\n${content_digest}\n${file_state}')
	if apply && (review_token.len == 0 || review_token != token) {
		return CopilotProjectInstallReport{
			ok: false
			message: 'The project changed after review. Nothing was written; review the current project state again.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'stale-review'
		}
	}
	if os.is_file(dest) {
		existing := os.read_file(dest) or {
			return CopilotProjectInstallReport{ ok: false, message: 'Could not read the existing Copilot instructions.', project: project, path: '.github/copilot-instructions.md', status: 'unreadable' }
		}
		if existing == content {
			return CopilotProjectInstallReport{
				ok: true
				message: 'The Agent Toolkit Copilot profile is already present and matches the bundled version. No files were changed.'
				project: project
				path: '.github/copilot-instructions.md'
				content: content
				status: 'current'
				review_token: token
			}
		}
		return CopilotProjectInstallReport{
			ok: true
			message: 'An existing .github/copilot-instructions.md is preserved. Review or move it yourself before installing the Toolkit profile.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'preserved-existing'
			review_token: token
		}
	}
	if !apply {
		return CopilotProjectInstallReport{
			ok: true
			message: 'Review one new file in this project’s .github folder. Existing files are never overwritten.'
			project: project
			path: '.github/copilot-instructions.md'
			content: content
			status: 'ready'
			review_token: token
		}
	}
	product := copilot_project_receipt_product(project_root)
	mut tx := new_install_transaction('copilot-repository', InstallTxOptions{
		product: product
		scope: 'project:${project_root}'
		receipt_dir: receipt_dir
		toolkit_root: ''
	})
	tx.stage_write(dest, content) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not stage the Copilot profile: ${err}', project: project, path: '.github/copilot-instructions.md', status: 'failed' }
	}
	tx.commit() or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not safely install the Copilot profile: ${err}', project: project, path: '.github/copilot-instructions.md', status: 'failed' }
	}
	if tx.receipt.artifacts.len == 0 {
		return CopilotProjectInstallReport{ ok: false, message: 'The destination changed during installation. No receipt was recorded; review the project again.', project: project, path: '.github/copilot-instructions.md', status: 'stale-review' }
	}
	return CopilotProjectInstallReport{
		ok: true
		message: 'Installed Agent Toolkit instructions for GitHub Copilot in ${project}. Restart or reopen Copilot in that repository to load the instructions.'
		project: project
		path: '.github/copilot-instructions.md'
		content: content
		status: 'installed'
		review_token: token
		files_written: tx.receipt.artifacts.len
	}
}

// copilot_project_remove previews or removes the one unchanged instructions
// file created by copilot_project_install. User-edited and unreceipted files
// are never removed.
pub fn copilot_project_remove(workspace string, project string, review_token string, apply bool, receipt_dir string) CopilotProjectInstallReport {
	root := resolve_project_files_root(workspace, project) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not resolve a linked project: ${err}', project: project }
	}
	project_root := os.real_path(root)
	dest := os.join_path(project_root, '.github', 'copilot-instructions.md')
	if os.is_link(os.join_path(project_root, '.github')) || os.is_link(dest) {
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
			message: 'No Agent Toolkit receipt proves ownership of this project file. Nothing was removed.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'no-receipt'
		}
	}
	receipt := parse_install_receipt(receipt_text) or {
		return CopilotProjectInstallReport{ ok: false, message: 'The project receipt is invalid. Nothing was removed.', project: project, path: '.github/copilot-instructions.md', status: 'invalid-receipt' }
	}
	if receipt.target != 'copilot-repository' || receipt.product != product || receipt.scope != 'project:${project_root}' || receipt.artifacts.len != 1 || receipt.artifacts[0].path != dest || receipt.artifacts[0].ownership != 'created' {
		return CopilotProjectInstallReport{ ok: false, message: 'The receipt does not identify this Toolkit-owned project instructions file. Nothing was removed.', project: project, path: '.github/copilot-instructions.md', status: 'invalid-receipt' }
	}
	if !os.is_file(dest) {
		return CopilotProjectInstallReport{ ok: true, message: 'The receipted instructions file is already absent. No project file was changed.', project: project, path: '.github/copilot-instructions.md', status: 'already-absent' }
	}
	current_digest := receipt_artifact_digest(dest)
	token := sha256.hexhash('${project_root}\n${project}\n${sha256.hexhash(receipt_text)}\n${current_digest}')
	if apply && (review_token.len == 0 || review_token != token) {
		return CopilotProjectInstallReport{ ok: false, message: 'The file changed after removal review. Nothing was removed; review the current project state again.', project: project, path: '.github/copilot-instructions.md', status: 'stale-review' }
	}
	if current_digest != receipt.artifacts[0].digest {
		return CopilotProjectInstallReport{
			ok: true
			message: 'This file changed after Agent Toolkit created it. The project copy and receipt are preserved.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'modified'
			review_token: token
		}
	}
	if !apply {
		return CopilotProjectInstallReport{
			ok: true
			message: 'Review removal of the unchanged, receipt-owned .github/copilot-instructions.md. No other project files will be touched.'
			project: project
			path: '.github/copilot-instructions.md'
			status: 'ready-remove'
			review_token: token
		}
	}
	quarantine := '${dest}.agent-toolkit-removal-${os.getpid()}'
	if os.exists(quarantine) || os.is_link(quarantine) {
		return CopilotProjectInstallReport{ ok: false, message: 'A recovery file already exists beside the destination. No files were removed.', project: project, path: '.github/copilot-instructions.md', status: 'recovery-conflict' }
	}
	os.rename(dest, quarantine) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not safely quarantine the project file: ${err}', project: project, path: '.github/copilot-instructions.md', status: 'failed' }
	}
	if os.is_link(quarantine) || receipt_artifact_digest(quarantine) != receipt.artifacts[0].digest {
		if !os.exists(dest) && !os.is_link(dest) {
			os.rename(quarantine, dest) or {
				return CopilotProjectInstallReport{ ok: false, message: 'The file changed during removal and could not be restored automatically. It is preserved at ${quarantine}.', project: project, path: '.github/copilot-instructions.md', status: 'recovery-required' }
			}
		}
		return CopilotProjectInstallReport{ ok: false, message: 'The file changed during removal. It was preserved; review the project again.', project: project, path: '.github/copilot-instructions.md', status: 'stale-review' }
	}
	os.rm(quarantine) or {
		return CopilotProjectInstallReport{ ok: false, message: 'Could not remove the quarantined file; it is preserved at ${quarantine}.', project: project, path: '.github/copilot-instructions.md', status: 'recovery-required' }
	}
	os.rm(receipt_path) or {
		return CopilotProjectInstallReport{ ok: false, message: 'The instructions file was removed, but its receipt remains at ${receipt_path}. Refresh installation evidence to reconcile it.', project: project, path: '.github/copilot-instructions.md', status: 'receipt-cleanup-required', files_removed: 1 }
	}
	return CopilotProjectInstallReport{
		ok: true
		message: 'Removed the unchanged Agent Toolkit Copilot instructions from ${project}. Other files in .github were left alone.'
		project: project
		path: '.github/copilot-instructions.md'
		status: 'removed'
		files_removed: 1
	}
}
