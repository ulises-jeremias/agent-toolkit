module agent_toolkit_core

import os

const matrix_rel = 'docs/research/platform-capability-matrix.md'

// matrix_result prints the platform capability matrix from the toolkit tree.
pub fn matrix_result() CommandResult {
	root := lookup_matrix_root()
	if root.len == 0 {
		msg := 'Matrix not found. Run the research pipeline first.\nExpected at: ${matrix_rel}'
		return CommandResult{
			command: 'matrix'
			ok: true
			message: msg
			data: {
				'found': 'false'
				'path':  matrix_rel
			}
		}
	}
	return matrix_result_at(root)
}

// matrix_result_at is the injectable variant for tests.
pub fn matrix_result_at(root string) CommandResult {
	path := os.join_path(root, 'docs', 'research', 'platform-capability-matrix.md')
	if os.is_file(path) {
		text := os.read_file(path) or {
			return CommandResult{
				command: 'matrix'
				ok: true
				message: 'Matrix not found. Run the research pipeline first.\nExpected at: ${path}'
				data: {
					'found': 'false'
					'path':  path
				}
			}
		}
		return CommandResult{
			command: 'matrix'
			ok: true
			message: text
			data: {
				'found': 'true'
				'path':  path
			}
		}
	}
	return CommandResult{
		command: 'matrix'
		ok: true
		message: 'Matrix not found. Run the research pipeline first.\nExpected at: ${path}'
		data: {
			'found': 'false'
			'path':  path
		}
	}
}

fn lookup_matrix_root() string {
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if os.is_dir(os.join_path(val, 'skills')) || os.is_dir(os.join_path(val, 'docs')) {
			return val
		}
	}
	mut cur := os.getwd()
	for {
		if os.is_dir(os.join_path(cur, 'skills')) && os.is_dir(os.join_path(cur, 'loops')) {
			return cur
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	cwd := os.getwd()
	if os.is_dir(os.join_path(cwd, 'docs')) {
		return cwd
	}
	return ''
}
