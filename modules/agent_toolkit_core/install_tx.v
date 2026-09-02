module agent_toolkit_core

import os

// InstallTxOptions configures an install transaction (Python install dry-run/force parity).
pub struct InstallTxOptions {
pub:
	dry_run       bool
	force         bool
	receipt_dir   string // empty → default_receipt_dir()
	toolkit_root  string
	product       string // empty → profiles_product
	scope         string // empty → user-home (profile installs)
	version       string // empty → resolve_toolkit_version()
	source_digest string
}

// StagedOp is one pending install write inside a transaction.
struct StagedOp {
	src       string // empty → content write
	dest      string
	content   string
	ownership string // created | merged
}

// InstallTransaction stages file writes, commits atomically, and rolls back on failure.
pub struct InstallTransaction {
pub mut:
	receipt InstallReceipt
	dry_run bool
	force   bool
mut:
	fs           FsService
	receipt_dir  string
	staged       []StagedOp
	committed    []CommittedArtifact
	finished     bool
	receipt_path string
}

// CommittedArtifact records a file written during commit (for rollback).
pub struct CommittedArtifact {
pub:
	path           string
	ownership      string
	created_by_tx  bool // true if dest did not exist before this commit
	backup_content string // prior content when force-overwriting an existing file
	had_backup     bool
}

// new_install_transaction starts a profiles install receipt transaction for target.
pub fn new_install_transaction(target string, opts InstallTxOptions) InstallTransaction {
	product := if opts.product.len > 0 { opts.product } else { profiles_product }
	scope := if opts.scope.len > 0 { opts.scope } else { 'user-home' }
	version := if opts.version.len > 0 { opts.version } else { resolve_toolkit_version() }
	src := if opts.source_digest.len > 0 {
		opts.source_digest
	} else {
		profiles_source_digest(opts.toolkit_root)
	}
	dir := if opts.receipt_dir.len > 0 { opts.receipt_dir } else { default_receipt_dir() }
	return InstallTransaction{
		receipt: new_install_receipt(product, target, scope, version, src)
		dry_run: opts.dry_run
		force: opts.force
		fs: new_fs()
		receipt_dir: dir
		staged: []StagedOp{}
		committed: []CommittedArtifact{}
	}
}

// stage_write queues an atomic content write to dest (ownership created).
pub fn (mut tx InstallTransaction) stage_write(dest string, content string) ! {
	tx.stage_write_owned(dest, content, 'created')!
}

// stage_write_owned queues a write with explicit ownership (created|merged).
pub fn (mut tx InstallTransaction) stage_write_owned(dest string, content string, ownership string) ! {
	if tx.finished {
		return error('install transaction already finished')
	}
	if receipt_path_escapes(dest) {
		return error('artifact path refused (path escape): ${dest}')
	}
	if ownership !in ['created', 'merged'] {
		return error("artifact ownership must be 'created' or 'merged'")
	}
	tx.staged << StagedOp{
		dest: dest
		content: content
		ownership: ownership
	}
}

// stage_copy queues copying src file bytes to dest.
pub fn (mut tx InstallTransaction) stage_copy(src string, dest string) ! {
	if tx.finished {
		return error('install transaction already finished')
	}
	if !os.is_file(src) {
		return error('source not found: ${src}')
	}
	if receipt_path_escapes(dest) {
		return error('artifact path refused (path escape): ${dest}')
	}
	content := os.read_file(src) or { return error('read source failed: ${src}: ${err}') }
	tx.staged << StagedOp{
		src: src
		dest: dest
		content: content
		ownership: 'created'
	}
}

// commit applies staged writes with write_atomic, then saves the receipt.
// On mid-commit failure, rolls back files written by this transaction and returns error.
// dry_run skips filesystem mutation and receipt save (returns empty path).
pub fn (mut tx InstallTransaction) commit() !string {
	if tx.finished {
		return error('install transaction already finished')
	}
	if tx.dry_run {
		tx.finished = true
		return ''
	}
	for op in tx.staged {
		tx.apply_one(op) or {
			tx.rollback_committed()
			tx.finished = true
			return error('install commit failed: ${err}')
		}
	}
	if tx.receipt.artifacts.len == 0 {
		tx.finished = true
		return ''
	}
	path := save_install_receipt(mut tx.receipt, tx.receipt_dir) or {
		tx.rollback_committed()
		tx.finished = true
		return error('receipt save failed: ${err}')
	}
	tx.receipt_path = path
	tx.finished = true
	return path
}

// rollback removes created artifacts from a successful commit and deletes the receipt file.
// Prefer using automatic rollback on commit failure; this supports explicit abort after success
// (used by uninstall/#514 and tests).
pub fn (mut tx InstallTransaction) rollback() ! {
	tx.rollback_committed()
	if tx.receipt_path.len > 0 && os.is_file(tx.receipt_path) {
		os.rm(tx.receipt_path) or { return error('failed to remove receipt: ${err}') }
		tx.receipt_path = ''
	}
	tx.finished = true
}

fn (mut tx InstallTransaction) apply_one(op StagedOp) ! {
	dest := op.dest
	existed := os.is_file(dest)
	if existed {
		existing := os.read_file(dest) or { return error('read existing failed: ${dest}: ${err}') }
		if existing == op.content {
			// Idempotent: already up to date — do not re-record.
			return
		}
		if !tx.force && op.ownership != 'merged' {
			// Preserve user-owned file (Python install skip without --force).
			// ownership=merged is a non-destructive JSON merge already computed by the caller.
			return
		}
		tx.fs.write_atomic(dest, op.content)!
		tx.committed << CommittedArtifact{
			path: dest
			ownership: op.ownership
			created_by_tx: false
			backup_content: existing
			had_backup: true
		}
		tx.record_artifact(dest, op.ownership)
		return
	}
	tx.fs.write_atomic(dest, op.content)!
	tx.committed << CommittedArtifact{
		path: dest
		ownership: op.ownership
		created_by_tx: true
	}
	tx.record_artifact(dest, op.ownership)
}

fn (mut tx InstallTransaction) record_artifact(path string, ownership string) {
	tx.receipt.artifacts << ArtifactEntry{
		path: path
		digest: receipt_artifact_digest(path)
		ownership: ownership
	}
}

fn (mut tx InstallTransaction) rollback_committed() {
	// Reverse order.
	for i := tx.committed.len - 1; i >= 0; i-- {
		a := tx.committed[i]
		if a.created_by_tx {
			if os.is_file(a.path) {
				os.rm(a.path) or {}
			}
			continue
		}
		if a.had_backup {
			tx.fs.write_atomic(a.path, a.backup_content) or {}
		}
	}
	tx.committed = []CommittedArtifact{}
	tx.receipt.artifacts = []ArtifactEntry{}
}
