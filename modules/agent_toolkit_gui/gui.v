module agent_toolkit_gui

// ping is a smoke-test entry used by foundation make.vsh build target.
pub fn ping() string {
	return 'ok'
}

// spike_version reports the feasibility harness version string for logging.
pub fn spike_version() string {
	return 'phase0-spike-1018-v-master'
}
