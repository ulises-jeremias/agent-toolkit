module agent_toolkit_core

import os
import yaml

// LibrarySkill is catalog metadata, never a claim about local installation.
pub struct LibrarySkill {
pub:
	id            string
	name          string
	domain        string
	description   string
	origin        string
	source_file   string
	requires      []string
	prerequisites []string
	mcp_required  []string
	compatibility []LibraryCompatibility
}

// LibraryCompatibility is the declared support level from the target registry.
pub struct LibraryCompatibility {
pub:
	target       string
	display_name string
	status       string // supported | partial | unsupported | unknown
}

pub struct LibrarySkillsResponse {
pub:
	ok      bool
	count   int
	message string
	skills  []LibrarySkill
}

struct SkillCapabilityRegistry {
	skills []SkillCapabilityEntry
}

struct SkillCapabilityEntry {
	id            string
	origin        string
	requires      []string
	prerequisites []string
	mcp_required  []string
}

struct SkillCatalogFile {
	skills []SkillCatalogEntry
}

struct SkillCatalogEntry {
	id          string
	description string
}

struct TargetCapabilityRegistry {
	targets []TargetCapabilityEntry
}

struct TargetCapabilityEntry {
	id           string
	display_name string
	capabilities map[string]string
}

// list_library_skills exposes the generated capability registries through a
// typed, read-only API. It uses the same toolkit root resolver as installs.
pub fn list_library_skills() LibrarySkillsResponse {
	root := find_toolkit_root() or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Toolkit capability data is unavailable: ${err.msg()}'
		}
	}
	return list_library_skills_at(root.path)
}

// list_library_skills_at is injectable for tests and keeps embedded package
// reads on the same data-root abstraction as checkout reads.
pub fn list_library_skills_at(root string) LibrarySkillsResponse {
	registry_text := data_read_file(root, os.join_path(root, 'capabilities/skills/registry.yaml')) or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Skill capability registry could not be read: ${err.msg()}'
		}
	}
	catalog_text := data_read_file(root, os.join_path(root, 'catalogs/skill-catalog.yaml')) or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Skill catalog could not be read: ${err.msg()}'
		}
	}
	targets_text := data_read_file(root, os.join_path(root, 'capabilities/targets/registry.yaml')) or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Target compatibility registry could not be read: ${err.msg()}'
		}
	}
	registry := yaml.decode[SkillCapabilityRegistry](project_skill_registry(registry_text)) or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Skill capability registry is invalid: ${err.msg()}'
		}
	}
	catalog := yaml.decode[SkillCatalogFile](catalog_text) or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Skill catalog is invalid: ${err.msg()}'
		}
	}
	targets := yaml.decode[TargetCapabilityRegistry](project_target_registry(targets_text)) or {
		return LibrarySkillsResponse{
			ok: false
			message: 'Target compatibility registry is invalid: ${err.msg()}'
		}
	}
	mut descriptions := map[string]string{}
	for entry in catalog.skills {
		descriptions[entry.id] = entry.description
	}
	compatibility := library_skill_compatibility(targets.targets)
	mut skills := []LibrarySkill{}
	mut seen := map[string]bool{}
	for entry in registry.skills {
		if entry.id.len == 0 || seen[entry.id] {
			continue
		}
		seen[entry.id] = true
		parts := entry.id.split('/')
		if parts.len != 2 || parts[0].len == 0 || parts[1].len == 0 {
			continue
		}
		skills << LibrarySkill{
			id: entry.id
			name: parts[1]
			domain: parts[0]
			description: descriptions[entry.id]
			origin: entry.origin
			source_file: 'skills/${entry.id}/SKILL.md'
			requires: entry.requires.clone()
			prerequisites: entry.prerequisites.clone()
			mcp_required: entry.mcp_required.clone()
			compatibility: compatibility.clone()
		}
	}
	skills.sort(a.id < b.id)
	return LibrarySkillsResponse{
		ok: true
		count: skills.len
		message: 'Catalog metadata only; local availability and installation are shown separately.'
		skills: skills
	}
}

// These generated registries use YAML indentation that V's YAML decoder
// rejects. Project only the stable fields needed by Desktop into a small,
// ordinary YAML document; block prose and unrelated routing fields are ignored.
fn project_skill_registry(text string) string {
	mut lines := ['skills:']
	mut list_field := ''
	for line in text.split('\n') {
		trimmed := line.trim_space()
		if trimmed.starts_with('- id:') {
			lines << '  ${trimmed}'
			list_field = ''
		} else if trimmed.starts_with('origin:') || trimmed.starts_with('requires:')
			|| trimmed.starts_with('prerequisites:') || trimmed.starts_with('mcp_required:') {
			lines << '    ${trimmed}'
			list_field = if trimmed.ends_with(':') { trimmed.all_before(':') } else { '' }
		} else if list_field.len > 0 && trimmed.starts_with('- ') {
			lines << '      ${trimmed}'
		} else if trimmed.len > 0 && !trimmed.starts_with('#') {
			list_field = ''
		}
	}
	return lines.join('\n')
}

fn project_target_registry(text string) string {
	mut lines := ['targets:']
	mut inside_capabilities := false
	for line in text.split('\n') {
		trimmed := line.trim_space()
		if trimmed.starts_with('- id:') {
			lines << '  ${trimmed}'
			inside_capabilities = false
		} else if trimmed.starts_with('display_name:') {
			lines << '    ${trimmed}'
		} else if trimmed == 'capabilities:' {
			lines << '    capabilities:'
			inside_capabilities = true
		} else if inside_capabilities && trimmed.starts_with('agent_skills:') {
			support := trimmed.all_after(':').trim_space().trim('"').trim("'")
			lines << "      agent_skills: '${support}'"
		} else if trimmed.len > 0 && line.starts_with('  ') && !line.starts_with('    ') {
			inside_capabilities = false
		}
	}
	return lines.join('\n')
}

fn library_skill_compatibility(targets []TargetCapabilityEntry) []LibraryCompatibility {
	mut out := []LibraryCompatibility{}
	for target in targets {
		support := target.capabilities['agent_skills'] or { 'unknown' }
		status := match support {
			'true' { 'supported' }
			'partial' { 'partial' }
			'false', 'none' { 'unsupported' }
			else { 'unknown' }
		}
		out << LibraryCompatibility{
			target: target.id
			display_name: target.display_name
			status: status
		}
	}
	return out
}
