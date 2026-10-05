module agent_toolkit_core

import os

const lina_json = '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false,"avatar":{"character":"scout","accent":"#4a7c9b"},"preferred_provider":"opencode","skills":["review"]}'

fn test_people_crud_and_archive_roundtrip() {
	ws := os.join_path(os.temp_dir(), 'atk-people-crud-${os.getpid()}')
	os.mkdir_all(ws) or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	assert list_people(ws)!.people.len == 0
	created := save_person(ws, lina_json, true)!
	assert created.person['name']!.str() == 'Lina'
	assert os.is_file(os.join_path(ws, 'people', 'lina.json'))
	assert list_people(ws)!.people.len == 1
	assert read_person(ws, 'lina')!.person['role']!.str() == 'reviewer'
	if _ := save_person(ws, lina_json, true) {
		assert false, 'duplicate person accepted'
	} else {
		assert err.msg().contains('already exists')
	}
	archived := save_person(ws, lina_json.replace('"archived":false', '"archived":true'), false)!
	assert archived.person['archived']!.bool()
	assert read_person(ws, 'lina')!.person['archived']!.bool()
	assert !save_person(ws, lina_json, false)!.person['archived']!.bool()
}

fn test_swarm_person_bindings_require_active_people_and_canonical_roles() {
	ws := os.join_path(os.temp_dir(), 'atk-people-swarm-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	save_person(ws, lina_json, true)!
	validate_swarm_person_bindings(ws, 'team', {
		'planner': 'lina'
	}) or { panic(err) }
	if _ := validate_swarm_person_bindings(ws, 'team', {
		'unknown-role': 'lina'
	}) {
		assert false, 'unknown recipe role accepted'
	} else {
		assert err.msg().contains('not in recipe')
	}
	if _ := validate_swarm_person_bindings(ws, 'team', {
		'planner': 'missing'
	}) {
		assert false, 'unknown Person accepted'
	} else {
		assert err.msg().contains('not found')
	}
	save_person(ws, lina_json.replace('"archived":false', '"archived":true'), false)!
	if _ := validate_swarm_person_bindings(ws, 'team', {
		'planner': 'lina'
	}) {
		assert false, 'archived Person accepted'
	} else {
		assert err.msg().contains('archived')
	}
}

fn test_swarm_person_binding_resolution_prefers_explicit_then_compatible_unique_people() {
	ws := os.join_path(os.temp_dir(), 'atk-people-swarm-resolve-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	save_person(ws, lina_json.replace('"role":"reviewer"', '"role":"designer","definition_id":"planner"'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"alex"').replace('"name":"Lina"', '"name":"Alex"'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"zoe"').replace('"name":"Lina"', '"name":"Zoe"'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"aaron"').replace('"name":"Lina"', '"name":"Aaron"').replace('"archived":false', '"archived":true'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"mira"').replace('"name":"Lina"', '"name":"Mira"').replace('"role":"reviewer"', '"role":"qa"'), true)!
	resolved := resolve_swarm_person_bindings(ws, 'team', {
		'architect': 'mira'
	})!
	assert resolved['architect'] == 'mira'
	assert resolved['planner'] == 'lina'
	assert resolved['reviewer'] == 'alex'
	assert 'implementer' !in resolved
	mut unique_people := []string{}
	for person_id in resolved.values() {
		if person_id !in unique_people { unique_people << person_id }
	}
	assert resolved.values().len == unique_people.len
}

fn test_swarm_person_binding_resolution_honors_workspace_preferences_before_role_matching() {
	ws := os.join_path(os.temp_dir(), 'atk-people-bindings-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	save_person(ws, lina_json.replace('"role":"reviewer"', '"role":"planner"'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"maya"').replace('"name":"Lina"', '"name":"Maya"').replace('"role":"reviewer"', '"role":"architect"'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"zoe"').replace('"name":"Lina"', '"name":"Zoe"').replace('"role":"reviewer"', '"role":"implementer"'), true)!
	save_person(ws, lina_json.replace('"id":"lina"', '"id":"alex"').replace('"name":"Lina"', '"name":"Alex"'), true)!
	os.write_file(os.join_path(ws, 'people', 'bindings.yaml'), 'spec: agent-toolkit/people-bindings@1\nroles:\n  planner:\n    person_id: lina\n  implementer:\n    preferred_people: [lina, maya, zoe]\n  reviewer:\n    person_id: absent\n    preferred_people: [maya, alex]\n') or { panic(err) }

	resolved := resolve_swarm_person_bindings(ws, 'team', {})!
	assert resolved['planner'] == 'lina'
	assert resolved['implementer'] == 'zoe'
	assert resolved['reviewer'] == 'alex'
	assert resolved['architect'] == 'maya'
	assert resolve_swarm_person_bindings(ws, 'team', {
		'planner': 'zoe'
	})!['planner'] == 'zoe'
	assert resolve_swarm_person_bindings(ws, 'team', {})!.values().len == 4
}

fn test_swarm_person_binding_preferences_fail_closed_on_invalid_documents_and_symlinks() {
	ws := os.join_path(os.temp_dir(), 'atk-people-bindings-invalid-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	defer { os.rmdir_all(ws) or {} }
	bindings := os.join_path(ws, 'people', 'bindings.yaml')
	os.mkdir_all(os.dir(bindings)) or { panic(err) }
	for invalid in [
		'spec: unknown\nroles: {}\n',
		'spec: agent-toolkit/people-bindings@1\nroles:\n  ../planner:\n    person_id: lina\n',
		'spec: agent-toolkit/people-bindings@1\nroles:\n  planner:\n    preferred_people: [lina, lina]\n',
	] {
		os.write_file(bindings, invalid) or { panic(err) }
		if _ := resolve_swarm_person_bindings(ws, 'team', {}) {
			assert false, 'invalid workspace People preferences were accepted'
		}
	}
	os.rm(bindings) or { panic(err) }
	outside := os.join_path(os.temp_dir(), 'atk-people-bindings-outside-${os.getpid()}')
	os.write_file(outside, 'spec: agent-toolkit/people-bindings@1\nroles: {}\n') or { panic(err) }
	defer { os.rm(outside) or {} }
	os.symlink(outside, bindings) or { panic(err) }
	if _ := resolve_swarm_person_bindings(ws, 'team', {}) {
		assert false, 'symlinked workspace People preferences were accepted'
	} else {
		assert err.msg().contains('symlink')
	}
}

fn test_people_reject_invalid_runtime_and_symlink_storage() {
	for invalid in [
		lina_json.replace('"id":"lina"', '"id":"../lina"'),
		lina_json.replace('"archived":false', '"archived":false,"status":"working"'),
		lina_json.replace('"review"', '"review","review"'),
		lina_json.replace('"accent":"#4a7c9b"', '"accent":"red"'),
	] {
		if _ := validate_person_json(invalid) {
			assert false, 'invalid person accepted'
		}
	}
	ws := os.join_path(os.temp_dir(), 'atk-people-link-${os.getpid()}')
	outside := os.join_path(os.temp_dir(), 'atk-people-outside-${os.getpid()}')
	os.mkdir_all(ws) or { panic(err) }
	os.mkdir_all(outside) or { panic(err) }
	defer {
		os.rmdir_all(ws) or {}
		os.rmdir_all(outside) or {}
	}
	os.symlink(outside, os.join_path(ws, 'people')) or { panic(err) }
	if _ := save_person(ws, lina_json, true) {
		assert false, 'symlinked storage accepted'
	}
	assert !os.exists(os.join_path(outside, 'lina.json'))
}
