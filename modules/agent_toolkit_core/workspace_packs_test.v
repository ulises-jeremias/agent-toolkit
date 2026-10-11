module agent_toolkit_core

import os

fn test_workspace_packs_list_validate_activate_and_clear() {
	base := os.join_path(os.temp_dir(), 'at-ws-packs-${os.getpid()}')
	defer { os.rmdir_all(base) or {} }
	os.mkdir_all(os.join_path(base, 'packs', 'teams')) or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'teams', 'review.yaml'), 'name: Review\ndescription: Review this project\nprojects:\n  - agent-toolkit\n') or { assert false, err.msg() }
	os.write_file(os.join_path(base, 'packs', 'broken.yaml'), 'description: No name\n') or { assert false, err.msg() }

	listed := list_workspace_packs(base) or { assert false, err.msg(); return }
	assert listed.packs.len == 2
	assert listed.packs[0].path == 'packs/broken.yaml'
	assert listed.packs[0].validation_errors.len == 1
	assert listed.packs[1].path == 'packs/teams/review.yaml'
	assert listed.packs[1].name == 'Review'
	assert listed.packs[1].projects == ['agent-toolkit']

	activated := activate_workspace_pack(WorkspacePackActivateRequest{
		workspace: base
		pack_path: 'packs/teams/review.yaml'
	}) or { assert false, err.msg(); return }
	assert activated.active_pack == 'packs/teams/review.yaml'
	assert read_strip(os.join_path(base, '.active-pack')) == 'packs/teams/review.yaml'
	active_list := list_workspace_packs(base) or { assert false, err.msg(); return }
	assert active_list.packs[1].active

	invalid := activate_workspace_pack(WorkspacePackActivateRequest{
		workspace: base
		pack_path: 'packs/broken.yaml'
	})
	assert invalid == none

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

	listed := list_workspace_packs(base) or { assert false, err.msg(); return }
	assert listed.packs.len == 1
	assert listed.packs[0].path == 'packs/local.yaml'

	os.symlink(os.join_path(outside, 'marker'), os.join_path(base, '.active-pack')) or {
		assert false, err.msg()
	}
	linked_marker := list_workspace_packs(base) or { assert false, err.msg(); return }
	assert linked_marker.marker_issue.contains('symbolic link')
	cleared := activate_workspace_pack(WorkspacePackActivateRequest{ workspace: base }) or {
		assert false, err.msg()
		return
	}
	assert cleared.active_pack == ''
	assert !os.is_link(os.join_path(base, '.active-pack'))
	assert !os.exists(os.join_path(outside, 'marker'))
}
