module agent_toolkit_core

import os

// data root abstraction — "embedded" is the in-memory full-embed tier (issue #766).

pub fn is_embedded_root(data_root string) bool {
	return data_root == 'embedded'
}

// data_is_dir reports whether rel (or full path) is a directory, handling embedded.
pub fn data_is_dir(data_root string, path string) bool {
	if is_embedded_root(data_root) {
		rel := strip_embedded_prefix(path)
		if rel.len == 0 {
			return embedded_is_valid_root()
		}
		return embedded_is_dir(rel)
	}
	return os.is_dir(path)
}

// data_is_file reports file existence.
pub fn data_is_file(data_root string, path string) bool {
	if is_embedded_root(data_root) {
		rel := strip_embedded_prefix(path)
		return embedded_is_file(rel)
	}
	return os.is_file(path)
}

// data_read_file reads file contents.
pub fn data_read_file(data_root string, path string) !string {
	if is_embedded_root(data_root) {
		rel := strip_embedded_prefix(path)
		return embedded_read_file(rel)
	}
	return os.read_file(path) or { return error('read failed: ${path}: ${err}') }
}

// data_ls lists immediate children names (files/dirs) of dir.
pub fn data_ls(data_root string, dir string) []string {
	if is_embedded_root(data_root) {
		rel := strip_embedded_prefix(dir)
		return embedded_ls(rel)
	}
	entries := os.ls(dir) or { return [] }
	return entries
}

// data_list_rel_files recursively lists files relative to src_dir (like list_rel_files).
pub fn data_list_rel_files(data_root string, src_dir string) []string {
	if is_embedded_root(data_root) {
		rel := strip_embedded_prefix(src_dir)
		// collect all embedded files under rel/
		prefix := if rel.len == 0 { '' } else { rel + '/' }
		mut out := []string{}
		for k, _ in embedded_file_map {
			if prefix.len == 0 {
				// root — not used for install, but handle
				out << k
			} else if k == rel {
				out << os.file_name(k)
			} else if k.starts_with(prefix) {
				out << k[prefix.len..]
			}
		}
		out.sort()
		return out
	}
	// fallback to filesystem walk (duplicate of diff.v:list_rel_files to avoid private conflict)
	mut out2 := []string{}
	if !os.is_dir(src_dir) {
		return out2
	}
	data_walk_rel(src_dir, src_dir, mut out2)
	out2.sort()
	return out2
}

fn data_walk_rel(root string, cur string, mut out []string) {
	entries := os.ls(cur) or { return }
	for e in entries {
		p := os.join_path(cur, e)
		if os.is_dir(p) {
			data_walk_rel(root, p, mut out)
		} else if os.is_file(p) {
			rel := p[root.len..].trim_string_left(os.path_separator)
			out << rel
		}
	}
}

// strip_embedded_prefix removes leading "embedded/" or "embedded" from a path.
fn strip_embedded_prefix(path string) string {
	if path == 'embedded' {
		return ''
	}
	if path.starts_with('embedded/') {
		return path[9..]
	}
	// also handle "embedded\\"
	if path.starts_with('embedded\\') {
		return path[9..]
	}
	return path
}

// data_map_tree_files is map_tree_files but handling embedded data_root.
pub fn data_map_tree_files(data_root string, src_dir string, dst_dir string) []FileMapping {
	if is_embedded_root(data_root) {
		rel := strip_embedded_prefix(src_dir)
		if !embedded_is_dir(rel) {
			return []
		}
		mut out := []FileMapping{}
		for f in data_list_rel_files(data_root, src_dir) {
			// f is relative to rel, e.g., "assistant.md" or "sub/file.md"
			rel_file := if rel.len == 0 { f } else { rel + '/' + f }
			src := 'embedded/' + rel_file
			dst := os.join_path(dst_dir, f)
			out << FileMapping{src, dst}
		}
		return out
	}
	return map_tree_files(src_dir, dst_dir)
}

// Helpers for source-present checks that need to consult embedded set.
pub fn data_has_profiles_tool(data_root string, tool string) bool {
	if is_embedded_root(data_root) {
		return embedded_is_dir('profiles/' + tool)
	}
	return os.is_dir(os.join_path(data_root, 'profiles', tool))
}
