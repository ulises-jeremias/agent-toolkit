module agent_toolkit_core

import os

fn source_skill_dependency_ids(raw string) []string {
	mut ids := []string{}
	mut current_id := ''
	mut has_dependency := false
	mut reading_dependency_list := false
	for line in raw.split('\n') {
		trimmed := line.trim_space()
		if line.starts_with('- id:') {
			if current_id.len > 0 && has_dependency {
				ids << current_id
			}
			current_id = trimmed.all_after('- id:').trim_space()
			has_dependency = false
			reading_dependency_list = false
			continue
		}
		if trimmed.starts_with('requires:') || trimmed.starts_with('prerequisites:')
			|| trimmed.starts_with('mcp_required:') {
			value := trimmed.all_after(':').trim_space()
			if value.len > 0 && value != '[]' {
				has_dependency = true
			}
			reading_dependency_list = value.len == 0
			continue
		}
		if reading_dependency_list && line.starts_with('  - ') {
			has_dependency = true
		} else if trimmed.len > 0 && line.starts_with('  ') && !line.starts_with('  - ') {
			reading_dependency_list = false
		}
	}
	if current_id.len > 0 && has_dependency {
		ids << current_id
	}
	return ids
}

fn test_library_skill_catalog_uses_embedded_provenance_and_dependency_registries() {
	catalog := list_library_skills_at('embedded')
	assert catalog.ok, catalog.message
	assert catalog.count == catalog.skills.len
	assert catalog.count >= 100
	assert catalog.skills.any(it.id == 'agentic-security/mcp-audit')
	skill := catalog.skills.filter(it.id == 'agentic-security/mcp-audit')[0]
	assert skill.domain == 'agentic-security'
	assert skill.name == 'mcp-audit'
	assert skill.origin == 'first-party'
	assert skill.source_file == 'skills/agentic-security/mcp-audit/SKILL.md'
	assert skill.description.contains('MCP config')
	assert skill.requires.len == 0
	assert catalog.skills.any(it.id == 'agentic-security/owasp-agentic-review')
	owasp := catalog.skills.filter(it.id == 'agentic-security/owasp-agentic-review')[0]
	assert 'agentic-security/threat-modeling' in owasp.prerequisites
	assert skill.compatibility.any(it.target == 'claude-code' && it.status == 'supported')
	assert skill.compatibility.any(it.target == 'windsurf' && it.status == 'partial')
}

fn test_library_skill_catalog_reads_checkout_root_from_filesystem() {
	root := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	registry_path := os.join_path(root, 'capabilities', 'skills', 'registry.yaml')
	registry_text := os.read_file(registry_path) or { panic(err) }
	response := list_library_skills_at(root)
	assert response.ok, response.message
	assert response.count >= 100
	assert response.skills.any(it.id == 'agentic-security/owasp-agentic-review')
	mut expected_ids := []string{}
	for line in registry_text.split('\n') {
		if !line.starts_with('- id:') {
			continue
		}
		id := line.all_after('- id:').trim_space()
		parts := id.split('/')
		if parts.len == 2 && parts[0].len > 0 && parts[1].len > 0 && id !in expected_ids {
			expected_ids << id
		}
	}
	mut actual_dependency_ids := response.skills.filter(it.requires.len > 0 || it.prerequisites.len > 0
		|| it.mcp_required.len > 0).map(it.id)
	mut expected_dependency_ids := source_skill_dependency_ids(registry_text)
	actual_dependency_ids.sort()
	expected_dependency_ids.sort()
	assert response.count == expected_ids.len
	assert actual_dependency_ids == expected_dependency_ids
}

fn test_library_skill_catalog_reports_missing_provenance_as_unavailable() {
	response := list_library_skills_at('missing-library-catalog-root')
	assert !response.ok
	assert response.skills.len == 0
	assert response.message.contains('registry could not be read')
}
