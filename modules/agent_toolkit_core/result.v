module agent_toolkit_core

// RenderMode selects CLI presentation for a domain result.
pub enum RenderMode {
	human
	json
	quiet
}

// CommandResult is a structured domain success payload (no printing).
pub struct CommandResult {
pub:
	command string
	ok      bool
	message string
	data    map[string]string
}

// version_result returns the toolkit version as a domain result.
pub fn version_result(version string) CommandResult {
	return CommandResult{
		command: 'version'
		ok:      true
		message: 'agent-toolkit ${version}'
		data:    {
			'version': version
			'engine':  'v'
			'commit':  resolve_commit()
		}
	}
}

// not_implemented_result marks a command as not yet ported to V.
pub fn not_implemented_result(command string) CommandResult {
	return CommandResult{
		command: command
		ok:      false
		message: 'command not implemented in V: ${command} (docs/v/advanced-command-disposition.md)'
		data:    {
			'status':  'not_implemented'
			'command': command
		}
	}
}
