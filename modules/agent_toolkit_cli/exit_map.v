module agent_toolkit_cli

import agent_toolkit_core

// map_exit returns the process exit code for a domain error (ADR-010).
pub fn map_exit(err agent_toolkit_core.DomainError) int {
	return err.exit_code()
}

// map_exit_class returns the process exit code for an error class.
pub fn map_exit_class(class agent_toolkit_core.ErrorClass) int {
	return class.exit_code()
}
