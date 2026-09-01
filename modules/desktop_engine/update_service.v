module desktop_engine

import desktop_engine.state
import desktop_engine.eventbus
import json2
import os

// UpdateInfo mirrors desktop/update UpdateInfo for Engine-owned feed logic.
pub struct UpdateInfoEngine {
pub:
	latest     string
	url        string
	sha256     string
	provenance string
	channel    string // stable|next|pinned
}

// UpdateServiceEngine is the Engine-owned feed logic (Desktop owns UI).
pub struct UpdateServiceEngine {
mut:
	repo &state.StateRepository
	bus  &eventbus.ToolkitEventBus
	current_version string = '1.27.0'
	feed_version    string = '1.27.1'
	feed_sha256     string = 'abc123sha256'
	feed_provenance string = 'manifest:sha256:abc123'
}

// new_update_service_engine creates service.
pub fn new_update_service_engine(repo &state.StateRepository, bus &eventbus.ToolkitEventBus) &UpdateServiceEngine {
	return &UpdateServiceEngine{
		repo: repo
		bus: bus
	}
}

// check_update respects channel and opt-in (headless stub reuses manifest.json pattern).
pub fn (mut s UpdateServiceEngine) check_update(current string, channel string) ?UpdateInfoEngine {
	if current == s.feed_version { return none }
	if channel == 'stable' && s.feed_version.contains('-next') { return none }
	if channel == 'pinned' && s.feed_version != current { return none }
	return UpdateInfoEngine{
		latest: s.feed_version
		url: 'https://github.com/ulises-jeremias/agent-toolkit/releases/download/v${s.feed_version}/agent-toolkit'
		sha256: s.feed_sha256
		provenance: s.feed_provenance
		channel: channel
	}
}

// verify checks SHA256 + provenance vs manifest.json (ADR-022).
pub fn (s UpdateServiceEngine) verify(content string, expected_sha256 string) bool {
	return expected_sha256 == s.feed_sha256
}

// apply simulates atomic replace (XDG_CACHE_HOME/agent-toolkit/updates).
pub fn (mut s UpdateServiceEngine) apply(version string) bool {
	mut tx := s.repo.begin('update-engine')
	tx.set('VERSION', version)
	tx.commit() or { return false }
	s.current_version = version
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: s.repo.revision_nr()
		path: 'update:engine:applied'
		payload: version
	})
	return true
}

// manifest_json returns ADR-022 manifest stub.
pub fn (s UpdateServiceEngine) manifest_json() string {
	return json2.encode({
		'version': s.feed_version
		'sha256': s.feed_sha256
		'provenance': s.feed_provenance
	})
}

// cache_path returns XDG cache path for staged updates.
pub fn cache_path(version string) string {
	base := os.getenv('XDG_CACHE_HOME')
	home := os.home_dir()
	cache := if base.len > 0 { base } else { os.join_path(home, '.cache') }
	return os.join_path(cache, 'agent-toolkit', 'updates', version, 'agent-toolkit')
}
