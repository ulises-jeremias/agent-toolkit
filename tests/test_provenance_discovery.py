"""Regression: discovery must not propose a commit that removed the locked path.

Upstream can consolidate per-skill folders into one skill. The newest commit that
touches the old path is then the deletion, and applying it fails with a 404.
"""

from __future__ import annotations

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
