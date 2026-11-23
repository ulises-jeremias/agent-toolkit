"""Regression: discovery must not propose a commit that removed the locked path.

Upstream can consolidate per-skill folders into one skill. The newest commit that
touches the old path is then the deletion, and applying it fails with a 404.
"""

from __future__ import annotations

import argparse
import json

import scripts.provenance as prov

LOCKED = "a" * 40
NEWER = "b" * 40


def _lock(path: str) -> dict:
    return {
        "capabilities": {
            "cap": {
                "sources": {
                    "src": {
                        "repository": "owner/upstream",
                        "path": path,
                        "requested": {"type": "commit", "ref": LOCKED},
                        "resolved": {"commit": LOCKED, "resolved_at": "2026-10-01T00:00:00Z"},
                    }
                }
            }
        }
    }


def test_skips_update_when_path_was_removed_upstream(monkeypatch, capsys):
    monkeypatch.setattr(prov, "_fetch_latest_commit", lambda repo, path=None: NEWER)
    monkeypatch.setattr(prov, "_path_exists_at", lambda repo, path, commit: False)

    updates = prov._discover_updates(_lock("skills/confluence-admin"))

    assert updates == []
    assert "removed upstream" in capsys.readouterr().err


def test_proposes_update_when_path_exists_at_newer_commit(monkeypatch):
    monkeypatch.setattr(prov, "_fetch_latest_commit", lambda repo, path=None: NEWER)
    monkeypatch.setattr(prov, "_path_exists_at", lambda repo, path, commit: True)

    updates = prov._discover_updates(_lock("skills/confluence"))

    assert [u["latest_commit"] for u in updates] == [NEWER]


def test_keeps_proposing_when_existence_check_is_inconclusive(monkeypatch):
    monkeypatch.setattr(prov, "_fetch_latest_commit", lambda repo, path=None: NEWER)
    monkeypatch.setattr(prov, "_path_exists_at", lambda repo, path, commit: None)

    updates = prov._discover_updates(_lock("skills/confluence"))

    assert [u["latest_commit"] for u in updates] == [NEWER]


def test_does_not_discover_updates_for_nonredistributable_source(monkeypatch):
    def unexpected_fetch(*args, **kwargs):
        raise AssertionError("blocked upstream source must not be queried for sync")

    monkeypatch.setattr(prov, "_fetch_latest_commit", unexpected_fetch)
    declarations = {
        "cap": {
            "frontmatter": {"distribution": {"redistribution_allowed": False}},
            "sources": [{"_source_id": "src", "repository": "owner/upstream", "path": "skills/x"}],
        }
    }

    assert prov._discover_updates(_lock("skills/x"), declarations) == []
    assert prov._nonredistributable_sources(declarations) == [
        {
            "capability": "cap",
            "source": "src",
            "repository": "owner/upstream",
            "path": "skills/x",
            "reason": "distribution.redistribution_allowed is false",
        }
    ]


def test_redistributable_sources_remain_eligible_for_updates(monkeypatch):
    monkeypatch.setattr(prov, "_fetch_latest_commit", lambda repo, path=None: NEWER)
    monkeypatch.setattr(prov, "_path_exists_at", lambda repo, path, commit: True)
    declarations = {
        "cap": {
            "frontmatter": {"distribution": {"redistribution_allowed": True}},
            "sources": [{"_source_id": "src", "repository": "owner/upstream", "path": "skills/x"}],
        }
    }

    assert [
        u["latest_commit"] for u in prov._discover_updates(_lock("skills/x"), declarations)
    ] == [NEWER]
    assert prov._nonredistributable_sources(declarations) == []


def test_json_discovery_reports_blocked_sources(monkeypatch, capsys):
    declarations = {
        "cap": {
            "frontmatter": {"distribution": {"redistribution_allowed": False}},
            "sources": [{"_source_id": "src", "repository": "owner/upstream", "path": "skills/x"}],
        }
    }
    monkeypatch.setattr(prov, "_load_lock", lambda: {})
    monkeypatch.setattr(prov, "_discover_declarations", lambda: declarations)
    monkeypatch.setattr(prov, "_discover_updates", lambda lock, declarations: [])

    assert prov.cmd_updates(argparse.Namespace(apply=False, json=True)) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["count"] == 0
    assert payload["updates"] == []
    assert payload["blocked"][0]["reason"] == "distribution.redistribution_allowed is false"


def test_text_discovery_does_not_claim_blocked_source_is_up_to_date(monkeypatch, capsys):
    declarations = {
        "cap": {
            "frontmatter": {"distribution": {"redistribution_allowed": False}},
            "sources": [{"_source_id": "src", "repository": "owner/upstream", "path": "skills/x"}],
        }
    }
    lock = _lock("skills/x")
    monkeypatch.setattr(prov, "_load_lock", lambda: lock)
    monkeypatch.setattr(prov, "_discover_declarations", lambda: declarations)
    monkeypatch.setattr(prov, "_discover_updates", lambda lock, declarations: [])

    assert prov.cmd_updates(argparse.Namespace(apply=False, json=False)) == 0
    captured = capsys.readouterr()
    assert "update sync blocked" in captured.err
    assert "up-to-date" not in captured.out
    assert "blocked by distribution policy" in captured.out


def test_apply_reports_blocked_source_without_applying_it(monkeypatch, capsys):
    declarations = {
        "cap": {
            "frontmatter": {"distribution": {"redistribution_allowed": False}},
            "sources": [{"_source_id": "src", "repository": "owner/upstream", "path": "skills/x"}],
        }
    }
    monkeypatch.setattr(prov, "_load_lock", lambda: _lock("skills/x"))
    monkeypatch.setattr(prov, "_discover_declarations", lambda: declarations)
    monkeypatch.setattr(prov, "_discover_updates", lambda lock, declarations: [])

    assert prov.cmd_updates(argparse.Namespace(apply=True, json=False)) == 0
    captured = capsys.readouterr()
    assert "blocked cap/src" in captured.err
    assert "No updates to apply." in captured.out
