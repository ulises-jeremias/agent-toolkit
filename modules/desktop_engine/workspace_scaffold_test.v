module desktop_engine

import os

fn test_workspace_scaffold_probe_reads_real_directories() {
	tmp := os.join_path(os.temp_dir(), 'engine-scaffold-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	os.mkdir_all(os.join_path(tmp, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(tmp, 'AGENTS.md'), '# contract\n') or { panic(err.msg()) }
	// a FILE named packs must not count as the packs/ directory
	os.write_file(os.join_path(tmp, 'packs'), '') or { panic(err.msg()) }
	s := probe_workspace_scaffold(tmp)
	assert s.entries.len == workspace_scaffold_entry_names.len
	flags := s.present_flags()
	assert flags.len == workspace_scaffold_entry_names.len
	assert flags[0], 'knowledge/ exists'
	assert !flags[1], 'personas/ missing'
	assert !flags[2], 'packs is a file, not the packs/ directory'
	assert !flags[3] && !flags[4], 'repos/ and projects/ missing'
	assert flags[5], 'AGENTS.md exists'
	assert s.present_count() == 2
}

fn test_workspace_scaffold_probe_unknown_root_is_empty_not_missing() {
	assert probe_workspace_scaffold('').entries.len == 0, 'no root → unknown, never "missing"'
	assert probe_workspace_scaffold('/definitely/not/a/dir/${os.getpid()}').entries.len == 0
	assert probe_workspace_scaffold('').present_flags().len == 0
}

fn test_workspace_scaffold_projection_stamps_revision_and_api_call() {
	tmp := os.join_path(os.temp_dir(), 'engine-scaffold-proj-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	os.mkdir_all(os.join_path(tmp, 'repos')) or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	before := eng.api_call_count()
	s := eng.workspace_scaffold(tmp)
	assert eng.api_call_count() > before, 'projection must count as an Engine API call'
	assert s.revision == eng.revision()
	assert s.entries.len == workspace_scaffold_entry_names.len
	assert s.root == os.real_path(tmp)
	mut names := []string{}
	for e in s.entries {
		names << e.name
	}
	assert names == workspace_scaffold_entry_names
	flags := s.present_flags()
	assert !flags[0] && !flags[5], 'knowledge/ and AGENTS.md missing here'
	assert flags[3], 'repos/ exists'
}

fn test_workspace_scaffold_probe_canonicalizes_symlinked_root() {
	base := os.join_path(os.temp_dir(), 'engine-scaffold-link-${os.getpid()}')
	os.mkdir_all(os.join_path(base, 'real', 'repos')) or { panic(err.msg()) }
	defer { os.rmdir_all(base) or {} }
	link := os.join_path(base, 'link')
	os.symlink(os.join_path(base, 'real'), link) or { panic(err.msg()) }
	// macOS /tmp -> /private/tmp: probing through a symlink must still
	// report the canonical root, never the unresolved spelling.
	s := probe_workspace_scaffold(link)
	assert s.root == os.real_path(link)
	assert s.root == os.real_path(os.join_path(base, 'real'))
	assert s.present_flags()[3], 'repos/ visible through the link'
}
