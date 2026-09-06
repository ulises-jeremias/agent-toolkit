module desktop_engine

import os

// Secrets never render raw in the MCP drawer preview (#1106).
fn test_mask_mcp_secrets_masks_all_prefixes() {
	assert mask_mcp_secrets('token ghp_abc123XYZ here') == 'token \${ENV_VAR} here'
	assert mask_mcp_secrets('key=sk-live-456_secret') == 'key=\${ENV_VAR}'
	assert mask_mcp_secrets('hook https://hooks.slack.com/xoxb-789-token end') == 'hook https://hooks.slack.com/\${ENV_VAR} end'
	assert mask_mcp_secrets('old gho_deadbeef42!') == 'old \${ENV_VAR}!'
	// placeholders and clean text pass through untouched
	assert mask_mcp_secrets('token \${GITHUB_TOKEN}') == 'token \${GITHUB_TOKEN}'
	assert mask_mcp_secrets('{"command": "npx"}') == '{"command": "npx"}'
	assert mask_mcp_secrets('the ghp_ prefix alone') == 'the ghp_ prefix alone'
	// multiple secrets in one blob
	assert mask_mcp_secrets('a ghp_111 b sk-222') == 'a \${ENV_VAR} b \${ENV_VAR}'
}

// Drawer data: template fallback + typed probe (#1106).
fn test_mcp_drawer_template_and_probe() {
	tmp := os.join_path(os.temp_dir(), 'mcp-drawer-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	cat := eng.mcp_catalog()
	assert cat.len >= 7
	// unknown provider → default stanza, not an error (drawer always renders)
	content, from_file := eng.mcp_template_json('no-such-provider')
	assert from_file == false
	assert content.contains('no-such-provider')
	// probe is typed and honest: figma reports error
	fig := eng.mcp_probe('figma') or { panic(err.msg()) }
	assert fig.healthy == false
	assert fig.detail.contains('error')
	// github probes against live health without writing state
	gh := eng.mcp_probe('github') or { panic(err.msg()) }
	assert gh.detail != ''
	eng.mcp_probe('') or { assert err.msg().contains('provider id empty') }
	eng.mcp_probe('no-such-provider') or { assert err.msg().contains('not found') }
}
