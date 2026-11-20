module agent_toolkit_cli

import os

fn test_veasel_desktop_candidates_prefer_env_override() {
	prior := os.getenv_opt('VEASEL_DESKTOP_BIN') or { '' }
	defer {
		if prior.len > 0 {
			os.setenv('VEASEL_DESKTOP_BIN', prior, true)
		} else {
			os.unsetenv('VEASEL_DESKTOP_BIN')
		}
	}
	os.setenv('VEASEL_DESKTOP_BIN', '/opt/veasel/veasel-desktop', true)
	candidates := veasel_desktop_candidates()
	assert candidates.len >= 2
	assert candidates[0] == '/opt/veasel/veasel-desktop'
	// Canonical install locations stay in the search path (#1804 shim).
	assert candidates.any(it.ends_with('.local/bin/veasel-desktop'))
	os.unsetenv('VEASEL_DESKTOP_BIN')
	without_env := veasel_desktop_candidates()
	assert without_env[0].ends_with('.local/bin/veasel-desktop')
}
