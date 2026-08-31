module agent_toolkit_cli

import agent_toolkit_core
import json

// render writes a CommandResult to stdout according to mode; returns exit code.
pub fn render(result agent_toolkit_core.CommandResult, mode agent_toolkit_core.RenderMode) int {
	match mode {
		.quiet {
			if result.ok {
				return 0
			}
			return agent_toolkit_core.err_user('command.failed', result.message).exit_code()
		}
		.json {
			println(json.encode(result))
			if result.ok {
				return 0
			}
			return agent_toolkit_core.err_user('command.failed', result.message).exit_code()
		}
		.human {
			println(result.message)
			if result.ok {
				return 0
			}
			return agent_toolkit_core.err_user('command.failed', result.message).exit_code()
		}
	}
}

// render_error prints a domain error and returns its exit code.
pub fn render_error(err agent_toolkit_core.DomainError, mode agent_toolkit_core.RenderMode) int {
	match mode {
		.quiet {}
		.json {
			payload := {
				'ok':      'false'
				'code':    err.code
				'class':   err.class.str()
				'message': err.message
			}
			println(json.encode(payload))
		}
		.human {
			eprintln(err.message)
		}
	}
	return err.exit_code()
}
