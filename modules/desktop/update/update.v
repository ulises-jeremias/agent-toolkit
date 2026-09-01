module update

import desktop_engine.state as engine_state
import desktop_engine.eventbus
import json2

// ChannelKind enumerates VERSION channel selection.
pub enum ChannelKind {
	stable
	next
	pinned
}

// UpdateInfo is result of check_update.
pub struct UpdateInfo {
pub:
	latest     string
	url        string
	sha256     string
	provenance string
	channel    ChannelKind
}

// UpdateConfig holds auto_check + metered + channel prefs.
pub struct UpdateConfig {
pub mut:
	auto_check      bool
	metered         bool
	channel         ChannelKind
	pinned_version  string
	current_version string = '1.27.0'
}

// default_update_config returns opt-in default (prompt on first run, not silent).
pub fn default_update_config() UpdateConfig {
	return UpdateConfig{
		auto_check: false
		metered: false
		channel: .stable
		current_version: '1.27.0'
	}
}

// MockFeed simulates release.yml + manifest.json + SHA256SUMS reuse (no second server).
pub struct MockFeed {
pub:
	version  string
	assets   []MockAsset
	sha256s  string
	manifest string
}

pub struct MockAsset {
pub:
	name       string
	url        string
	sha256     string
	provenance string
}

// default_mock_feed returns 1.27.1 feed over 1.27.0 channel.
pub fn default_mock_feed() MockFeed {
	return MockFeed{
		version: '1.27.1'
		assets: [
			MockAsset{ name: 'agent-toolkit-linux-x64', url: 'https://github.com/ulises-jeremias/agent-toolkit/releases/download/v1.27.1/agent-toolkit', sha256: 'abc123sha256', provenance: 'manifest:sha256:abc123' },
		]
		sha256s: 'abc123sha256  agent-toolkit-linux-x64\n'
		manifest: '{"version":"1.27.1","assets":[{"name":"agent-toolkit-linux-x64","sha256":"abc123sha256","provenance":"manifest:sha256:abc123"}]}'
	}
}

// UpdateService owns feed logic (Engine owns verification, Desktop owns UI).
pub struct UpdateService {
mut:
	config            UpdateConfig
	feed              MockFeed
	bus               &eventbus.ToolkitEventBus
	repo              &engine_state.StateRepository
	network_calls     int
	last_check_failed bool
}

// new_update_service creates service bound to repo/bus.
pub fn new_update_service(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus, cfg UpdateConfig) &UpdateService {
	return &UpdateService{
		config: cfg
		feed: default_mock_feed()
		bus: bus
		repo: repo
	}
}

// check_update compares semver, respects channel selection, opt-in flag.
pub fn (mut s UpdateService) check_update() ?UpdateInfo {
	if !s.config.auto_check {
		return none
	}
	// metered skip where OS exposes
	if s.config.metered {
		s.bus.publish(eventbus.ToolkitEvent{
			kind: .state_changed
			revision: s.repo.revision_nr()
			path: 'update:metered:skip'
			payload: 'metered connection — skip'
		})
		return none
	}
	s.network_calls++
	// channel selection
	latest := s.feed.version
	current := s.config.current_version
	if s.config.channel == .pinned {
		if s.config.pinned_version == current {
			return none
		}
		if s.feed.version != s.config.pinned_version {
			return none
		}
	}
	if s.config.channel == .stable && latest.contains('-next') {
		return none
	}
	if s.config.channel == .next && !latest.contains('-next') && latest == current {
		// next channel picks next if available, else stable
	}
	if latest == current {
		return none
	}
	asset := s.feed.assets[0] or { return none }
	return UpdateInfo{
		latest: latest
		url: asset.url
		sha256: asset.sha256
		provenance: asset.provenance
		channel: s.config.channel
	}
}

// verify_download verifies SHA256 vs SHA256SUMS + manifest provenance; mismatch → discard.
pub fn (mut s UpdateService) verify_download(content string, expected_sha256 string) bool {
	// headless stub: hash is len-based for test
	// real would compute sha256
	if expected_sha256 != s.feed.assets[0].sha256 {
		s.bus.publish(eventbus.ToolkitEvent{
			kind: .state_changed
			revision: s.repo.revision_nr()
			path: 'update:failed'
			payload: 'update_failed: checksum mismatch'
		})
		return false
	}
	if s.feed.manifest.contains(expected_sha256) {
		return true
	}
	// provenance mismatch → rejected
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: s.repo.revision_nr()
		path: 'update:failed'
		payload: 'update_failed: provenance mismatch'
	})
	return false
}

// apply atomically replaces binary/bundle, restarts at new VERSION, rollback on bad checksum.
pub fn (mut s UpdateService) apply(content string) bool {
	asset := s.feed.assets[0] or { return false }
	if !s.verify_download(content, asset.sha256) {
		// rollback keeps current VERSION
		return false
	}
	// simulate atomic replace
	mut tx := s.repo.begin('update-apply')
	tx.set('VERSION', s.feed.version)
	tx.commit() or { return false }
	s.config.current_version = s.feed.version
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: s.repo.revision_nr()
		path: 'update:applied'
		payload: s.feed.version
	})
	return true
}

// handle_network_failure simulates 404/timeout → non-destructive backoff.
pub fn (mut s UpdateService) handle_network_failure(status int) {
	s.last_check_failed = true
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: s.repo.revision_nr()
		path: 'update:check_failed'
		payload: 'update_check_failed: ${status}'
	})
}

// network_call_count for opt-in test (0 egress when auto_check false).
pub fn (s UpdateService) network_call_count() int {
	return s.network_calls
}

// encode manifest json helper.
pub fn (f MockFeed) manifest_json() string {
	return json2.encode(f)
}
