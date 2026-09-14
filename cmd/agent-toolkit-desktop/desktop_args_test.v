module main

import os

// Headless flag regression tests: --version/--help classification must not
// depend on any display being present. The display env is cleared explicitly
// so these prove the no-DISPLAY/no-WAYLAND decision path.
fn clear_display_env() {
	os.unsetenv('DISPLAY')
	os.unsetenv('WAYLAND_DISPLAY')
	os.unsetenv('ATK_GUI_HEADLESS')
}

fn test_version_flags_classify_without_display() {
	clear_display_env()
	for flag in ['--version', '-V', 'version'] {
		assert classify_desktop_argv([flag]) == .version, 'flag must classify as version: ${flag}'
	}
}

fn test_help_flags_classify_without_display() {
	clear_display_env()
	for flag in ['--help', '-h', 'help'] {
		assert classify_desktop_argv([flag]) == .help, 'flag must classify as help: ${flag}'
	}
}

fn test_unknown_flags_are_usage_errors() {
	clear_display_env()
	for flag in ['--bogus', '-x', '--version=x'] {
		assert classify_desktop_argv([flag]) == .usage_error, 'flag must classify as usage_error: ${flag}'
	}
}

fn test_launch_paths_unchanged() {
	clear_display_env()
	assert classify_desktop_argv([]) == .launch, 'no args must launch'
	assert classify_desktop_argv(['anything-else']) == .launch, 'positional args must still launch'
}

fn test_help_text_is_concise_and_mentions_flags() {
	help := desktop_help_text()
	assert help.contains('--version'), 'help must document --version'
	assert help.contains('--help'), 'help must document --help'
	assert help.contains('agent-toolkit-desktop'), 'help must name the binary'
}
