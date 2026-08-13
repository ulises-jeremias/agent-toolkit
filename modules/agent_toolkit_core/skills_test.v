module agent_toolkit_core

import os

fn test_skills_list_and_validate() {
	base := os.join_path(os.temp_dir(), 'at-skills-${os.getpid()}')
	skill_dir := os.join_path(base, 'skills', 'core', 'assistant')
	os.mkdir_all(skill_dir) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'catalogs')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(skill_dir, 'SKILL.md'), '---\nname: assistant\ndescription: Helps with repos\n---\n\n# Assistant\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(os.join_path(base, 'catalogs', 'skills-layout.json'), '{"layout":"x","groups":{"core":["assistant"]},"skills":[{"id":"core/assistant","name":"assistant","domain":"core"}]}') or {
		assert false, err.msg()
		return
	}
	listed := run_skills(SkillsOptions{
		subcommand:   'list'
		toolkit_root: base
	})
	assert listed.ok
	assert listed.message.contains('assistant')
	assert listed.count == 1

	bad_domain := run_skills(SkillsOptions{
		subcommand:   'list'
		domain:       'nope'
		toolkit_root: base
	})
	assert !bad_domain.ok

	valid := run_skills(SkillsOptions{
		subcommand:   'validate'
		toolkit_root: base
	})
	assert valid.ok
	assert valid.errors == 0
}

fn test_skills_sync_copy_and_cursor_index() {
	base := os.join_path(os.temp_dir(), 'at-skills-sync-${os.getpid()}')
	home := os.join_path(base, 'home')
	skill_dir := os.join_path(base, 'skills', 'core', 'assistant')
	os.mkdir_all(skill_dir) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'catalogs')) or { assert false, err.msg() }
	os.mkdir_all(home) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(skill_dir, 'SKILL.md'), '---\nname: assistant\ndescription: Helps\n---\n') or {
		assert false, err.msg()
		return
	}
	os.write_file(os.join_path(base, 'catalogs', 'skills-layout.json'), '{"skills":[{"id":"core/assistant","name":"assistant","domain":"core"}]}') or {
		assert false, err.msg()
		return
	}
	sync := run_skills(SkillsOptions{
		subcommand:   'sync'
		tools:        ['claude-code', 'cursor']
		home_dir:     home
		toolkit_root: base
	})
	assert sync.ok
	assert os.is_file(os.join_path(home, '.claude', 'skills', 'assistant', 'SKILL.md'))
	idx := os.read_file(os.join_path(home, '.cursor', 'skills-index.json')) or { '' }
	assert idx.contains('"assistant"')
}

fn test_skills_unknown_subcommand() {
	r := run_skills(SkillsOptions{
		subcommand: 'explode'
	})
	assert !r.ok
	assert r.message.contains('Unknown subcommand')
}
