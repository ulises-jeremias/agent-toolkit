module agent_toolkit_core

import os

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
	response := list_library_skills_at(os.getwd())
	assert response.ok, response.message
	assert response.count >= 100
	assert response.skills.any(it.id == 'agentic-security/owasp-agentic-review')
}

fn test_library_skill_catalog_reports_missing_provenance_as_unavailable() {
	response := list_library_skills_at('missing-library-catalog-root')
	assert !response.ok
	assert response.skills.len == 0
	assert response.message.contains('registry could not be read')
}
