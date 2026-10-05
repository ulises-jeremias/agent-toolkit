module agent_toolkit_core

import os
import yaml
import x.json2

const person_limit = 65536

struct PersonRolePreference {
pub:
	person_id        string
	preferred_people []string
}

struct PersonBindingsDocument {
pub:
	spec  string
	roles map[string]PersonRolePreference
}

pub struct PeopleResponse {
pub:
	ok     bool
	people []map[string]json2.Any
}

pub struct PersonResponse {
pub:
	ok     bool
	person map[string]json2.Any
}

fn person_slug(value string) bool {
	if value.len == 0 || value.len > 64 || !((value[0] >= 97 && value[0] <= 122) || (value[0] >= 48 && value[0] <= 57)) {
		return false
	}
	for ch in value.bytes() {
		if !(ch >= 97 && ch <= 122) && !(ch >= 48 && ch <= 57) && ch != 45 && ch != 95 {
			return false
		}
	}
	return true
}

fn person_ref(value string) bool {
	if value.len == 0 || value.len > 128 || !((value[0] >= 65 && value[0] <= 90) || (value[0] >= 97 && value[0] <= 122) || (value[0] >= 48 && value[0] <= 57)) {
		return false
	}
	for ch in value.bytes() {
		if !(ch >= 65 && ch <= 90) && !(ch >= 97 && ch <= 122) && !(ch >= 48 && ch <= 57) && ch != 45 && ch != 95 && ch != 46 && ch != 58 && ch != 47 {
			return false
		}
	}
	return true
}

fn person_string(doc map[string]json2.Any, field string, required bool, max_len int, kind string) !string {
	value := doc[field] or {
		if required { return error('${field} is required') }
		return ''
	}
	if value is string {
		if value.len == 0 || value.len > max_len {
			return error('${field} has invalid length')
		}
		if kind == 'id' && !person_slug(value) { return error('${field} has invalid id') }
		if kind == 'ref' && !person_ref(value) { return error('${field} has invalid reference') }
		return value
	}
	return error('${field} must be text')
}

fn person_allowed(doc map[string]json2.Any, fields []string) ! {
	for field, _ in doc {
		if field !in fields { return error('person contains an unsupported field') }
	}
}

fn person_refs(doc map[string]json2.Any, field string) ! {
	value := doc[field] or { return }
	if value is []json2.Any {
		if value.len > 32 { return error('${field} has too many entries') }
		mut seen := []string{}
		for item in value {
			if item is string {
				if !person_ref(item) || item in seen { return error('${field} contains an invalid or duplicate reference') }
				seen << item
			} else { return error('${field} must contain references') }
		}
		return
	}
	return error('${field} must be a list')
}

fn person_number(doc map[string]json2.Any, field string, limit f64, integer bool) ! {
	value := doc[field] or { return }
	mut number := f64(-1)
	match value {
		f64 { number = value }
		int { number = f64(value) }
		i64 { number = f64(value) }
		else { return error('${field} must be a number') }
	}
	if number < 0 || number > limit || (integer && number != f64(i64(number))) {
		return error('${field} is outside the allowed range')
	}
}

// validate_person_json enforces the workspace declaration contract at the
// canonical write boundary. Unknown fields, runtime fields and commands fail.
pub fn validate_person_json(raw string) !map[string]json2.Any {
	if raw.len == 0 || raw.len > person_limit { return error('person document has invalid size') }
	doc := json2.decode[map[string]json2.Any](raw) or { return error('person document is not valid JSON') }
	person_allowed(doc, ['spec', 'id', 'name', 'role', 'goal', 'archived', 'definition_id', 'avatar',
		'preferred_provider', 'preferred_model', 'capabilities', 'skills', 'mcp_servers', 'isolation',
		'budget', 'import_source'])!
	if person_string(doc, 'spec', true, 64, '')! != 'agent-toolkit/person@1' { return error('unsupported person spec') }
	person_string(doc, 'id', true, 64, 'id')!
	person_string(doc, 'name', true, 128, '')!
	person_string(doc, 'role', true, 64, 'id')!
	person_string(doc, 'goal', true, 2048, '')!
	archived := doc['archived'] or { return error('archived is required') }
	if archived !is bool { return error('archived must be a boolean') }
	for field in ['definition_id', 'preferred_provider', 'preferred_model'] {
		person_string(doc, field, false, 128, 'ref')!
	}
	for field in ['capabilities', 'skills', 'mcp_servers'] { person_refs(doc, field)! }
	if isolation := doc['isolation'] {
		if isolation is string {
			if isolation !in ['inherited', 'worktree', 'session'] { return error('isolation is not supported') }
		} else { return error('isolation must be text') }
	}
	if avatar := doc['avatar'] {
		if avatar is map[string]json2.Any {
			person_allowed(avatar, ['character', 'accent'])!
			person_string(avatar, 'character', false, 64, 'id')!
			if accent := avatar['accent'] {
				if accent is string {
					if accent.len != 7 || accent[0] != `#` { return error('avatar accent must be a hex color') }
					for ch in accent[1..].bytes() {
						if !ch.is_hex_digit() { return error('avatar accent must be a hex color') }
					}
				} else { return error('avatar accent must be text') }
			}
		} else { return error('avatar must be an object') }
	}
	if budget := doc['budget'] {
		if budget is map[string]json2.Any {
			person_allowed(budget, ['max_tokens', 'max_cost_usd', 'max_seconds'])!
			person_number(budget, 'max_tokens', 1000000000, true)!
			person_number(budget, 'max_cost_usd', 1000000, false)!
			person_number(budget, 'max_seconds', 31536000, true)!
		} else { return error('budget must be an object') }
	}
	if source := doc['import_source'] {
		if source is map[string]json2.Any {
			person_allowed(source, ['spec', 'id', 'review_required', 'auto_spawn', 'auto_install',
				'live_sync', 'original_character', 'original_accent'])!
			if person_string(source, 'spec', true, 64, '')! != 'munder-difflin/hire@1' { return error('unsupported import source') }
			person_string(source, 'id', false, 128, 'ref')!
			person_string(source, 'original_character', false, 128, '')!
			person_string(source, 'original_accent', false, 128, '')!
			for field, expected in {'review_required': true, 'auto_spawn': false, 'auto_install': false, 'live_sync': false} {
				flag := source[field] or { return error('${field} is required') }
				if flag is bool {
					if flag != expected { return error('${field} cannot be enabled') }
				} else { return error('${field} must be a boolean') }
			}
		} else { return error('import source must be an object') }
	}
	return doc
}

fn person_dir(workspace string) !string {
	ws := find_workspace_root(workspace) or { return error('workspace not found') }
	dir := os.join_path(os.real_path(ws), 'people')
	if os.is_link(dir) { return error('people directory is a symlink') }
	return dir
}

fn person_path(workspace string, id string) !string {
	if !person_slug(id) { return error('invalid person id') }
	dir := person_dir(workspace)!
	path := os.join_path(dir, '${id}.json')
	if os.is_link(path) { return error('person file is a symlink') }
	return path
}

// read_person_bindings loads optional workspace-local swarm role preferences.
// They are hints only: explicit start-dialog choices win and unresolved roles
// continue to use the recipe's ephemeral AgentDefinition.
fn read_person_bindings(workspace string) !map[string]PersonRolePreference {
	dir := person_dir(workspace)!
	path := os.join_path(dir, 'bindings.yaml')
	if os.is_link(path) { return error('people bindings file is a symlink') }
	if !os.is_file(path) { return map[string]PersonRolePreference{} }
	text := os.read_file(path) or { return error('people bindings file cannot be read') }
	if text.len == 0 || text.len > person_limit { return error('people bindings file has invalid size') }
	parsed := yaml.parse_text(text) or { return error('people bindings file is invalid YAML: ${err}') }
	root := parsed.root
	if root is map[string]yaml.Any {
		if root.len != 2 { return error('people bindings file contains unsupported fields') }
		spec := root['spec'] or { return error('people bindings spec is required') }
		if spec is string {
			if spec != 'agent-toolkit/people-bindings@1' { return error('unsupported people bindings spec') }
		} else {
			return error('people bindings spec must be text')
		}
		roles := root['roles'] or { return error('people bindings roles are required') }
		if roles is map[string]yaml.Any {
			if roles.len > 64 { return error('people bindings has too many role entries') }
			for role, value in roles {
				if !person_slug(role) { return error('people bindings contains an invalid role id') }
				if value is map[string]yaml.Any {
					if value.len > 2 { return error('people bindings contains unsupported role fields') }
					if person_id := value['person_id'] {
						if person_id is string {
							if !person_slug(person_id) { return error('people bindings contains an invalid person id') }
						} else {
							return error('people bindings person_id must be text')
						}
					}
					if preferred := value['preferred_people'] {
						if preferred is []yaml.Any {
							if preferred.len > 32 {
								return error('people bindings has too many preferred People for ${role}')
							}
							mut seen := []string{}
							for entry in preferred {
								if entry is string {
									if !person_slug(entry) || entry in seen {
										return error('people bindings has an invalid or duplicate preferred Person for ${role}')
									}
									seen << entry
								} else {
									return error('people bindings preferred_people must contain ids')
								}
							}
						} else {
							return error('people bindings preferred_people must be a list')
						}
					}
					for field, _ in value {
						if field !in ['person_id', 'preferred_people'] {
							return error('people bindings contains unsupported role fields')
						}
					}
				} else {
					return error('people bindings role preferences must be objects')
				}
			}
		} else {
			return error('people bindings roles must be an object')
		}
		for field, _ in root {
			if field !in ['spec', 'roles'] { return error('people bindings file contains unsupported fields') }
		}
	} else {
		return error('people bindings file must be an object')
	}
	doc := yaml.decode[PersonBindingsDocument](text) or {
		return error('people bindings file is invalid YAML: ${err}')
	}
	return doc.roles
}

fn find_person_by_id(people []map[string]json2.Any, id string) ?map[string]json2.Any {
	for person in people {
		person_id := person['id'] or { continue }
		if person_id is string && person_id == id { return person.clone() }
	}
	return none
}

pub fn list_people(workspace string) !PeopleResponse {
	dir := person_dir(workspace)!
	mut people := []map[string]json2.Any{}
	if !os.is_dir(dir) { return PeopleResponse{ ok: true, people: people } }
	mut names := os.ls(dir) or { return error('people directory cannot be read') }
	names.sort()
	for name in names {
		if !name.ends_with('.json') { continue }
		id := name[..name.len - 5]
		path := person_path(workspace, id)!
		text := os.read_file(path) or { return error('person ${id} cannot be read') }
		person := validate_person_json(text) or { return error('person ${id} is invalid: ${err}') }
		if person_string(person, 'id', true, 64, 'id')! != id { return error('person filename does not match id') }
		people << person
	}
	return PeopleResponse{ ok: true, people: people }
}

pub fn read_person(workspace string, id string) !PersonResponse {
	path := person_path(workspace, id)!
	if !os.is_file(path) { return error('person not found') }
	text := os.read_file(path) or { return error('person cannot be read') }
	person := validate_person_json(text)!
	if person_string(person, 'id', true, 64, 'id')! != id { return error('person filename does not match id') }
	return PersonResponse{ ok: true, person: person }
}

pub fn save_person(workspace string, raw string, create bool) !PersonResponse {
	person := validate_person_json(raw)!
	id := person_string(person, 'id', true, 64, 'id')!
	path := person_path(workspace, id)!
	if create && os.exists(path) { return error('person already exists') }
	if !create && !os.is_file(path) { return error('person not found') }
	dir := os.dir(path)
	os.mkdir_all(dir) or { return error('people directory cannot be created') }
	if os.is_link(dir) || os.is_link(path) { return error('person storage is a symlink') }
	tmp := path + '.${os.getpid()}.tmp'
	if os.exists(tmp) || os.is_link(tmp) { return error('person write is busy') }
	os.write_file(tmp, json2.encode(person, escape_unicode: true) + '\n') or { return error('person cannot be written') }
	os.mv(tmp, path) or {
		os.rm(tmp) or {}
		return error('person cannot be saved')
	}
	return PersonResponse{ ok: true, person: person }
}

// validate_swarm_person_bindings ensures each explicit durable collaborator
// names one role in this canonical recipe and one active workspace Person.
// Roles remain ephemeral recipe responsibilities; a Person only supplies
// durable identity to the runtime process that takes that role.
pub fn validate_swarm_person_bindings(workspace string, recipe string, bindings map[string]string) ! {
	if bindings.len == 0 {
		return
	}
	roles := swarm_recipe_roles(recipe)
	mut seen := []string{}
	for role, id in bindings {
		if role !in roles {
			return error('person binding role ${role} is not in recipe ${recipe}')
		}
		if id in seen {
			return error('person ${id} is bound to more than one role')
		}
		person := read_person(workspace, id) or { return error('person binding ${role}: ${err.msg()}') }
		archived := person.person['archived'] or { return error('person ${id} has no archive state') }
		if archived is bool {
			if archived {
				return error('person ${id} is archived and cannot be assigned')
			}
		} else {
			return error('person ${id} has invalid archive state')
		}
		seen << id
	}
}

// resolve_swarm_person_bindings preserves explicit assignments, then applies
// ordered compatible workspace preferences, then matches an active Person by
// durable role or AgentDefinition. Unmatched roles remain ephemeral.
pub fn resolve_swarm_person_bindings(workspace string, recipe string, explicit map[string]string) !map[string]string {
	validate_swarm_person_bindings(workspace, recipe, explicit)!
	mut resolved := explicit.clone()
	mut used := []string{}
	for _, person_id in resolved {
		used << person_id
	}
	people := list_people(workspace)!
	preferences := read_person_bindings(workspace)!
	config := resolve_swarm_config(workspace, recipe, '', '', '')!
	for role_name in swarm_recipe_roles(recipe) {
		if role_name in resolved { continue }
		role := config.spec.roles[role_name] or { continue }
		preference := preferences[role_name] or { PersonRolePreference{} }
		mut preferred_ids := []string{}
		if preference.person_id.len > 0 { preferred_ids << preference.person_id }
		for preferred_id in preference.preferred_people { preferred_ids << preferred_id }
		for id in preferred_ids {
			if id in used { continue }
			person := find_person_by_id(people.people, id) or { continue }
			archived := person['archived'] or { continue }
			if archived is bool {
				if archived { continue }
			} else { continue }
			person_role := person_string(person, 'role', true, 64, 'id')!
			definition_id := person_string(person, 'definition_id', false, 128, 'ref')!
			if person_role != role_name && (role.persona.len == 0 || definition_id != role.persona) { continue }
			resolved[role_name] = id
			used << id
			break
		}
		if role_name in resolved { continue }
		for person in people.people {
			id := person_string(person, 'id', true, 64, 'id')!
			if id in used { continue }
			archived := person['archived'] or { continue }
			if archived is bool {
				if archived { continue }
			} else { continue }
			person_role := person_string(person, 'role', true, 64, 'id')!
			definition_id := person_string(person, 'definition_id', false, 128, 'ref')!
			if person_role != role_name && (role.persona.len == 0 || definition_id != role.persona) { continue }
			resolved[role_name] = id
			used << id
			break
		}
	}
	return resolved
}
