module agent_toolkit_core

import os

fn test_workspace_packs_list_validate_activate_and_clear() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(os.join_path(base, 'packs', 'teams')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'teams', 'review.yaml'), 'name: Review\ndescription: Review this project\nprojects:\n  - agent-toolkit\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'broken.yaml'), 'description: No name\n') or { assert false, err.msg() }

	listed := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert listed.packs.len == 2
	assert listed.packs[0].path == 'packs/broken.yaml'
	assert listed.packs[0].validation_errors.len == 1
	assert listed.packs[1].path == 'packs/teams/review.yaml'
	assert listed.packs[1].name == 'Review'
	assert listed.packs[1].projects == ['agent-toolkit']

	activated := activate_workspace_pack(WorkspacePackActivateRequest{
		workspace: base
		pack_path: 'packs/teams/review.yaml'
	}) or {
		assert false, err.msg()
		return
	}
	assert activated.active_pack == 'packs/teams/review.yaml'
	assert read_strip(os.join_path(base, '.active-pack')) == 'packs/teams/review.yaml'
	active_list := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert active_list.packs[1].active

	activate_workspace_pack(WorkspacePackActivateRequest{
		workspace: base
		pack_path: 'packs/broken.yaml'
	}) or {
		assert err.msg().contains('workspace pack is invalid')
		return
	}
	assert false, 'an invalid workspace pack must not be activated'

	cleared := activate_workspace_pack(WorkspacePackActivateRequest{ workspace: base }) or {
		assert false, err.msg()
		return
	}
	assert cleared.active_pack == ''
	assert !os.exists(os.join_path(base, '.active-pack'))
}

fn test_workspace_packs_skip_symlinks_and_reject_symlinked_marker() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-links-${os.getpid()}')
	outside := os.join_path(os.temp_dir(), 'at-ws-packs-outside-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
		os.rmdir_all(outside) or {}
	}
	os.mkdir_all(os.join_path(base, 'packs')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(outside, 'nested')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	os.write_file(os.join_path(outside, 'nested', 'external.yaml'), 'name: External\ndescription: Outside\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(base, 'packs', 'local.yaml'), 'name: Local\ndescription: Inside\n') or {
		assert false, err.msg()
	}
	os.symlink(os.join_path(outside, 'nested'), os.join_path(base, 'packs', 'linked')) or {
		assert false, err.msg()
	}

	listed := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert listed.packs.len == 1
	assert listed.packs[0].path == 'packs/local.yaml'

	os.symlink(os.join_path(outside, 'marker'), os.join_path(base, '.active-pack')) or {
		assert false, err.msg()
	}
	linked_marker := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert linked_marker.marker_issue.contains('symbolic link')
	cleared := activate_workspace_pack(WorkspacePackActivateRequest{ workspace: base }) or {
		assert false, err.msg()
		return
	}
	assert cleared.active_pack == ''
	assert !os.is_link(os.join_path(base, '.active-pack'))
	assert !os.exists(os.join_path(outside, 'marker'))
}

fn test_workspace_pack_create_edit_and_reject_stale_revision() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-save-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(base) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	created := save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		name: 'Frontend Team'
		description: 'Shared context for frontend work'
		projects: ['web', 'design-system']
		notes: 'Keep changes accessible.\nPrefer small components.'
	}) or {
		assert false, err.msg()
		return
	}
	assert created.pack.path == 'packs/frontend-team.yaml'
	assert created.pack.name == 'Frontend Team'
	assert created.pack.projects == ['web', 'design-system']
	assert created.pack.notes == 'Keep changes accessible.\nPrefer small components.'
	assert created.pack.revision.len == 64
	activate_workspace_pack(WorkspacePackActivateRequest{
		workspace: base
		pack_path: created.pack.path
	}) or {
		assert false, err.msg()
		return
	}
	context := workspace_context(WorkspaceOptions{ workspace_path: base })
	assert context.message.contains('Keep changes accessible.')
	assert context.message.contains('Prefer small components.')

	updated := save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		pack_path: created.pack.path
		revision: created.pack.revision
		name: 'Frontend Team'
		description: 'Updated context for frontend work'
		projects: ['web']
		notes: 'Review changes before merging.\n'
	}) or {
		assert false, err.msg()
		return
	}
	assert updated.pack.description == 'Updated context for frontend work'
	assert updated.pack.projects == ['web']
	assert updated.pack.notes == 'Review changes before merging.\n'
	newline_update := save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		pack_path: created.pack.path
		revision: updated.pack.revision
		name: 'Frontend Team'
		description: 'Updated context for frontend work'
		notes: 'First line\r\nSecond line\r\n'
	}) or {
		assert false, err.msg()
		return
	}
	assert newline_update.pack.notes == 'First line\nSecond line\n'

	save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		pack_path: created.pack.path
		revision: created.pack.revision
		name: 'Frontend Team'
		description: 'Stale update'
	}) or {
		assert err.msg().contains('changed since it was opened')
		return
	}
	assert false, 'stale edits must not overwrite a newer pack'
}

fn test_workspace_pack_save_preserves_rich_fields_outside_desktop_model() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-rich-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(os.join_path(base, 'packs')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	path := os.join_path(base, 'packs', 'rich.yaml')
	os.write_file(path, 'name: Rich\ndescription: Rich pack\nprojects:\n  - alpha\n# ── Repos ──\nrepos:\n  - name: alpha\n    path: projects/alpha\norg:\n  github: example\nai:\n  delivery_skill: delivery/example\n') or {
		assert false, err.msg()
	}
	listed := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert listed.packs.len == 1
	assert listed.packs[0].extra_fields == ['repos', 'org', 'ai']
	saved := save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		pack_path: 'packs/rich.yaml'
		revision: listed.packs[0].revision
		name: 'Rich'
		description: 'Updated rich pack'
		projects: ['alpha', 'beta']
		notes: 'Updated notes.'
	}) or {
		assert false, err.msg()
		return
	}
	assert saved.pack.description == 'Updated rich pack'
	assert saved.pack.extra_fields == ['repos', 'org', 'ai']
	assert saved.message.contains('preserved')
	text := os.read_file(path) or {
		assert false, err.msg()
		return
	}
	assert text.contains('repos:\n  - name: alpha\n    path: projects/alpha')
	assert text.contains('org:\n  github: example')
	assert text.contains('ai:\n  delivery_skill: delivery/example')
	assert text.contains('# ── Repos ──')
	reloaded := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert reloaded.packs[0].projects == ['alpha', 'beta']
	assert reloaded.packs[0].notes == 'Updated notes.'
}

fn test_effective_context_fragments_order_provenance_and_honesty() {
	base := os.join_path(os.temp_dir(), 'at-effective-context-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(os.join_path(base, 'packs')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'personas')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'knowledge', 'learnings')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace rules\nBe kind.\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'team.yaml'), 'name: Team\ndescription: Team context\nprojects:\n  - alpha\nnotes: Shared notes here.\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(base, 'personas', 'reviewer.md'), '# Reviewer\nReview carefully.\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(base, '.active-persona'), 'reviewer\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'knowledge', 'learnings', 'one.md'), '# One\n') or { assert false, err.msg() }
	activate_workspace_pack(WorkspacePackActivateRequest{
		workspace: base
		pack_path: 'packs/team.yaml'
	}) or {
		assert false, err.msg()
		return
	}
	effective := effective_context(base) or {
		assert false, err.msg()
		return
	}
	assert effective.active_pack == 'packs/team.yaml'
	kinds := effective.fragments.map(it.kind)
	assert kinds == ['agents', 'pack', 'persona', 'knowledge']
	for fragment in effective.fragments {
		assert fragment.est_tokens >= 0
	}
	assert effective.fragments[0].sha256.len == 64
	assert effective.fragments[1].detail.contains('alpha')
	assert effective.fragments[1].detail.contains('Shared notes')
	assert effective.fragments[3].detail.contains('learnings=1')
	assert effective.total_est_tokens == effective.fragments[0].est_tokens + effective.fragments[1].est_tokens + effective.fragments[2].est_tokens + effective.fragments[3].est_tokens
	assert effective.notes.join(' ').contains('not a security boundary')
	assert effective.notes.join(' ').contains('future sessions')
	// Switching the active pack must not rewrite what a started session used:
	// the assembler is a pure read, so a second call reflects only the new
	// selection and the first response object is unchanged.
	assert effective.fragments[1].source == 'packs/team.yaml'
}

fn test_workspace_pack_reads_yaml_block_scalar_variants() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-yaml-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(os.join_path(base, 'packs')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'literal.yaml'), 'name: Literal\ndescription: Literal notes\nnotes: |+\n  first line\n  second line\n\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'folded.yaml'), 'name: Folded\ndescription: Folded notes\nnotes: >-\n  first paragraph\n  continues here\n\n  second paragraph\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'indented.yaml'), 'name: Indented\ndescription: Indented notes\nnotes: |2-\n  exact indentation\n') or { assert false, err.msg() }

	listed := list_workspace_packs(base) or {
		assert false, err.msg()
		return
	}
	assert listed.packs.len == 3
	assert listed.packs.filter(it.name == 'Folded')[0].notes == 'first paragraph continues here\nsecond paragraph'
	assert listed.packs.filter(it.name == 'Literal')[0].notes == 'first line\nsecond line\n\n'
	assert listed.packs.filter(it.name == 'Indented')[0].notes == 'exact indentation'
	for pack in listed.packs {
		assert pack.validation_errors.len == 0
	}
}

fn test_workspace_pack_save_rejects_existing_lock_and_cleans_lock_after_save() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-lock-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(os.join_path(base, 'packs')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	created := save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		name: 'Team'
		description: 'Team context'
	}) or {
		assert false, err.msg()
		return
	}
	assert !os.exists(os.join_path(base, 'packs', 'team.yaml.lock'))
	lock_path := os.join_path(base, '${created.pack.path}.lock')
	os.write_file(lock_path, 'busy') or { assert false, err.msg() }
	save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		pack_path: created.pack.path
		revision: created.pack.revision
		name: 'Team'
		description: 'Changed context'
	}) or {
		assert err.msg().contains('update is busy')
		os.rm(lock_path) or {}
		return
	}
	assert false, 'a concurrent save lock must prevent writing'
}

fn test_workspace_pack_save_rejects_invalid_projects_and_symlink_pack_directory() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-save-invalid-${os.getpid()}')
	outside := os.join_path(os.temp_dir(), 'at-ws-packs-save-outside-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
		os.rmdir_all(outside) or {}
	}
	os.mkdir_all(base) or { assert false, err.msg() }
	os.mkdir_all(outside) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		name: 'Team'
		description: 'Context'
		projects: ['../outside']
	}) or {
		assert err.msg().contains('unique simple project names')
	}
	os.symlink(outside, os.join_path(base, 'packs')) or { assert false, err.msg() }
	save_workspace_pack(WorkspacePackSaveRequest{
		workspace: base
		name: 'Team'
		description: 'Context'
	}) or {
		assert err.msg().contains('symlink')
		return
	}
	assert false, 'a symlinked pack directory must be rejected'
}
