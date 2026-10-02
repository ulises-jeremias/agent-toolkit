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
