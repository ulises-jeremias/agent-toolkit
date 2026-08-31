module agent_toolkit_cli

fn test_root_command_tree_has_consumer_and_advanced_groups() {
	root := build_root_command()
	mut groups := map[string]bool{}
	mut names := map[string]bool{}
	for c in root.commands {
		names[c.name] = true
		if c.group.len > 0 {
			groups[c.group] = true
		}
	}
	assert groups['Consumer commands']
	assert groups['Advanced commands']
	assert names['install']
	assert names['skills']
	assert names['loop']
	assert names['workspace']
	assert names['devcompanion']
}

fn test_nested_skills_and_aliases() {
	root := build_root_command()
	skills := find_command(root, 'skills') or {
		assert false, 'skills missing'
		return
	}
	assert skills.commands.len >= 3
	uninstall := find_command(root, 'rollback') or {
		assert false, 'rollback alias missing'
		return
	}
	assert uninstall.name == 'uninstall'
	dc := find_command(root, 'dc') or {
		assert false, 'dc alias missing'
		return
	}
	assert dc.name == 'devcompanion'
}

fn test_global_json_flag_declared() {
	root := build_root_command()
	mut found := false
	for f in root.flags {
		if f.name == 'json' && f.global {
			found = true
		}
	}
	assert found
}
