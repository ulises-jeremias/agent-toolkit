module agent_toolkit_cli

import agent_toolkit_core

// ping_core exposes a tiny smoke dependency on core (used in unit tests).
pub fn ping_core() string {
	return agent_toolkit_core.ping()
}
