@[has_globals]
module agent_toolkit_core

import compress.gzip
import sync

// The generated bundle keeps the complete offline payload intact while avoiding
// thousands of individual static embed declarations in the native C build.
const embedded_data_bundle = $embed_file('embedded_data.bundle.gz')

struct EmbeddedFileRange {
mut:
	offset int
	len    int
}

struct EmbeddedDataIndex {
mut:
	files      map[string]EmbeddedFileRange
	dirs       map[string]bool
	payload    []u8
	load_error string
}

__global embedded_data_cache = sync.new_lazy_lock[EmbeddedDataIndex](load_embedded_data_index)

fn embedded_data_index() EmbeddedDataIndex {
	mut cache := embedded_data_cache
	return cache.get()
}

fn load_embedded_data_index() EmbeddedDataIndex {
	compressed := embedded_data_bundle.to_bytes()
	payload := gzip.decompress(compressed) or {
		return EmbeddedDataIndex{
			load_error: 'embedded resource bundle could not be decompressed: ${err.msg()}'
		}
	}
	return decode_embedded_data_bundle(payload) or {
		EmbeddedDataIndex{
			load_error: 'embedded resource bundle is invalid: ${err.msg()}'
		}
	}
}

fn decode_embedded_data_bundle(payload []u8) !EmbeddedDataIndex {
	mut offset := 0
	file_count_raw, next_offset := read_embedded_u32(payload, offset)!
	offset = next_offset
	file_count := int(file_count_raw)
	if file_count > 100_000 {
		return error('embedded resource file count is invalid')
	}
	mut index := EmbeddedDataIndex{
		files:   map[string]EmbeddedFileRange{}
		dirs:    map[string]bool{}
		payload: payload
	}
	for _ in 0 .. file_count {
		path_len_raw, next_path_offset := read_embedded_u32(payload, offset)!
		offset = next_path_offset
		content_len, next_content_offset := read_embedded_u64(payload, offset)!
		offset = next_content_offset
		path_len := int(path_len_raw)
		if path_len < 1 || path_len > payload.len - offset {
			return error('embedded resource path length is invalid')
		}
		path := payload[offset..offset + path_len].bytestr()
		offset += path_len
		if !is_valid_embedded_resource_path(path) || path in index.files || path in index.dirs {
			return error('embedded resource path is invalid')
		}
		parts := path.split('/')
		mut parent := ''
		for i, part in parts {
			if i == parts.len - 1 {
				break
			}
			parent = if parent.len == 0 { part } else { parent + '/' + part }
			if parent in index.files {
				return error('embedded resource file conflicts with a directory')
			}
		}
		if content_len > u64(payload.len - offset) {
			return error('embedded resource content length is invalid')
		}
		content_size := int(content_len)
		index.files[path] = EmbeddedFileRange{
			offset: offset
			len:    content_size
		}
		offset += content_size
	for depth in 1 .. parts.len {
		index.dirs[parts[..depth].join('/')] = true
		}
	}
	if offset != payload.len {
		return error('embedded resource bundle has trailing data')
	}
	return index
}

fn is_valid_embedded_resource_path(path string) bool {
	if path.len == 0 || path.starts_with('/') || path.starts_with('\\') || path.contains('\\')
		|| path.contains('\x00') {
		return false
	}
	for part in path.split('/') {
		if part.len == 0 || part == '.' || part == '..' {
			return false
		}
	}
	return true
}

fn read_embedded_u32(data []u8, offset int) !(u32, int) {
	if offset < 0 || data.len - offset < 4 {
		return error('embedded resource bundle ended early')
	}
	mut value := u32(0)
	for i in 0 .. 4 {
		value |= u32(data[offset + i]) << (i * 8)
	}
	return value, offset + 4
}

fn read_embedded_u64(data []u8, offset int) !(u64, int) {
	if offset < 0 || data.len - offset < 8 {
		return error('embedded resource bundle ended early')
	}
	mut value := u64(0)
	for i in 0 .. 8 {
		value |= u64(data[offset + i]) << (i * 8)
	}
	return value, offset + 8
}

pub fn embedded_has_file(path string) bool {
	return path in embedded_data_index().files
}

pub fn embedded_is_file(path string) bool {
	return embedded_has_file(path)
}

pub fn embedded_is_dir(path string) bool {
	index := embedded_data_index()
	if path in index.dirs {
		return true
	}
	prefix := path + '/'
	for k, _ in index.files {
		if k.starts_with(prefix) {
			return true
		}
	}
	return false
}

pub fn embedded_read_file(path string) !string {
	index := embedded_data_index()
	if index.load_error.len > 0 {
		return error(index.load_error)
	}
	range := index.files[path] or { return error('embedded file not found: ${path}') }
	return index.payload[range.offset..range.offset + range.len].bytestr()
}

pub fn embedded_ls(dir string) []string {
	index := embedded_data_index()
	mut out := []string{}
	mut seen := map[string]bool{}
	prefix := if dir.len == 0 { '' } else { dir + '/' }
	for k, _ in index.files {
		if !k.starts_with(prefix) {
			continue
		}
		rest := k[prefix.len..]
		idx := rest.index('/') or { -1 }
		name := if idx == -1 { rest } else { rest[..idx] }
		if name.len > 0 && name !in seen {
			seen[name] = true
			out << name
		}
	}
	out.sort()
	return out
}

pub fn embedded_file_paths() []string {
	mut paths := embedded_data_index().files.keys()
	paths.sort()
	return paths
}

pub fn embedded_is_valid_root() bool {
	dirs := embedded_data_index().dirs
	return 'profiles' in dirs && ('skills' in dirs || 'loops' in dirs)
}

pub fn embedded_is_repo_checkout() bool {
	dirs := embedded_data_index().dirs
	return 'skills' in dirs && 'loops' in dirs
}
