module agent_toolkit_cli

import agent_toolkit_core

// run is a smoke entry for the thin CLI adapter (no argv parsing yet).
pub fn run() string {
	return agent_toolkit_core.ping()
}
