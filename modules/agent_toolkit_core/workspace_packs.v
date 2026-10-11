module agent_toolkit_core

import os

const workspace_pack_count_limit = 256
const workspace_pack_file_limit = 64 * 1024

pub struct WorkspacePackSummary {
pub:
	path             string
	name             string
	description      string
	projects         []string
	validation_errors []string
	active           bool
}

pub struct WorkspacePacksResponse {
pub:
	ok          bool
	workspace   string
	active_pack string
	marker_issue string
	packs       []WorkspacePackSummary
}

pub struct WorkspacePackActivateRequest {
pub:
	workspace string
	pack_path string
}

pub struct WorkspacePackActivateResponse {
pub:
	ok          bool
	workspace   string
	active_pack string
	message     string
}

// list_workspace_packs returns safe, local workspace context bundles. These
// are distinct from repository solution packs and loop --pack overrides.
pub fn list_workspace_packs(workspace string) !WorkspacePacksResponse {
	ws := find_workspace_root(workspace) or { return error('workspace not found') }
	root := os.real_path(ws)
	dir := os.join_path(root, 'packs')
	if os.is_link(dir) { return error('workspace packs directory is a symlink') }
	active_file := os.join_path(root, '.active-pack')
	mut marker_issue := ''
	mut active := ''
	if os.is_link(active_file) {
		marker_issue = 'The saved context marker is a symbolic link. Clear the selection to remove the link safely.'
	} else if os.is_file(active_file) {
		if os.file_size(active_file) > 4096 {
			marker_issue = 'The saved context marker is too large to read. Clear the selection to remove it.'
		} else {
			active = os.read_file(active_file) or {
				marker_issue = 'The saved context marker cannot be read. Clear the selection to remove it.'
				''
			}.trim_space()
		}
	} else if os.exists(active_file) {
		marker_issue = 'The saved context marker is not a regular file. Clear the selection to remove it.'
	}
	if !os.is_dir(dir) {
		return WorkspacePacksResponse{
			ok: true
			workspace: root
			active_pack: active
			marker_issue: marker_issue
			packs: []WorkspacePackSummary{}
		}
	}
	paths := workspace_pack_paths(root, dir, 0)
	if paths.len > workspace_pack_count_limit { return error('too many workspace packs') }
	mut packs := []WorkspacePackSummary{}
	for path in paths {
		file := os.join_path(root, path)
		if os.is_link(file) { continue }
		if os.file_size(file) > workspace_pack_file_limit {
			packs << WorkspacePackSummary{
				path: path
				name: os.file_name(path).all_before_last('.')
				validation_errors: ['Pack exceeds the 64 KiB review limit.']
				active: path == active
			}
			continue
		}
		text := os.read_file(file) or {
			packs << WorkspacePackSummary{
				path: path
				name: os.file_name(path).all_before_last('.')
				validation_errors: ['Pack could not be read.']
				active: path == active
			}
			continue
		}
		name := yaml_string_field(text, 'name')
		description := yaml_string_field(text, 'description')
		mut validation_errors := []string{}
		if name.len == 0 { validation_errors << "Missing required field 'name'." }
		if description.len == 0 { validation_errors << "Missing required field 'description'." }
		packs << WorkspacePackSummary{
			path: path
			name: if name.len > 0 { name } else { os.file_name(path).all_before_last('.') }
			description: description
			projects: yaml_string_list(text, 'projects')
			validation_errors: validation_errors
			active: path == active
		}
	}
	packs.sort(a.path < b.path)
	return WorkspacePacksResponse{
		ok: true
		workspace: root
		active_pack: active
		marker_issue: marker_issue
		packs: packs
	}
}

// activate_workspace_pack switches the future session context marker without
// copying files or executing pack contents. An empty path clears the marker.
pub fn activate_workspace_pack(req WorkspacePackActivateRequest) !WorkspacePackActivateResponse {
	ws := find_workspace_root(req.workspace) or { return error('workspace not found') }
	root := os.real_path(ws)
	marker := os.join_path(root, '.active-pack')
	if req.pack_path.len > 0 {
		if os.is_link(marker) { return error('active pack marker is a symlink; clear it before selecting another pack') }
		packs := list_workspace_packs(root)!
		selected := packs.packs.filter(it.path == req.pack_path)
		if selected.len == 0 { return error('workspace pack not found: ${req.pack_path}') }
		if selected[0].validation_errors.len > 0 {
			return error('workspace pack is invalid: ${selected[0].validation_errors.join(' ')}')
		}
	}
	if req.pack_path.len == 0 {
		if os.exists(marker) || os.is_link(marker) {
			if !os.is_link(marker) && os.is_dir(marker) {
				os.rmdir(marker) or {
					return error('active pack marker is a non-empty directory; move its contents before selecting a pack')
				}
			} else {
				os.rm(marker) or { return error('active pack marker cannot be cleared') }
			}
		}
		return WorkspacePackActivateResponse{
			ok: true
			workspace: root
			message: 'Active workspace pack cleared. Future context no longer uses a pack overlay.'
		}
	}
	tmp := marker + '.${os.getpid()}.tmp'
	if os.exists(tmp) || os.is_link(tmp) { return error('active pack update is busy') }
	os.write_file(tmp, req.pack_path + '\n') or { return error('active pack marker cannot be written') }
	os.mv(tmp, marker) or {
		os.rm(tmp) or {}
		return error('active pack marker cannot be saved')
	}
	return WorkspacePackActivateResponse{
		ok: true
		workspace: root
		active_pack: req.pack_path
		message: 'Active workspace pack set to ${req.pack_path}. Its context applies to future workspace sessions; no files were copied and no capabilities were installed or run.'
	}
}

fn workspace_pack_paths(root string, dir string, depth int) []string {
	if depth > 4 || os.is_link(dir) { return []string{} }
	entries := os.ls(dir) or { return []string{} }
	mut paths := []string{}
	for entry in entries {
		path := os.join_path(dir, entry)
		if os.is_link(path) { continue }
		if os.is_dir(path) {
			paths << workspace_pack_paths(root, path, depth + 1)
		} else if entry.ends_with('.yaml') || entry.ends_with('.yml') {
			paths << pack_rel_path(root, path)
		}
		if paths.len > workspace_pack_count_limit { return paths }
	}
	paths.sort()
	return paths
}
