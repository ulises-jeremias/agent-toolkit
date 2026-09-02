module agent_toolkit_cli

import agent_toolkit_core
import x.json2

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
			println(json2.encode(result, escape_unicode: true))
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
			println(json2.encode(payload, escape_unicode: true))
		}
		.human {
			eprintln(err.message)
		}
	}
	return err.exit_code()
}
