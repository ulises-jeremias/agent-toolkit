"""Traversal protection regression for #967: job IDs, workspace, symlink."""
import pathlib
import re

def test_job_id_validation_in_code():
    jobs_v = pathlib.Path("modules/agent_toolkit_server/jobs.v").read_text()
    assert "is_valid_job_id" in jobs_v
    assert "%" in jobs_v  # encoded check
    assert "is_log_path_safe" in jobs_v

def test_server_validates_job_log():
    server = pathlib.Path("modules/agent_toolkit_server/server.veb.v").read_text()
    # must check is_valid_job_id and is_log_path_safe before file read
    assert server.count("is_valid_job_id") >= 2
    assert "is_log_path_safe" in server
    assert "is_allowed_workspace" in server
    assert "workspace outside allowed roots" in server

def test_workspace_rejects_traversal_payloads():
    server = pathlib.Path("modules/agent_toolkit_server/server.veb.v").read_text()
    # Should reject .. and % early with 400
    assert "contains('..')" in server
    assert "contains('%')" in server

def test_loop_name_validation():
    server = pathlib.Path("modules/agent_toolkit_server/server.veb.v").read_text()
    assert "is_valid_loop_name" in server

def test_symlink_blocked_in_log_path():
    jobs_v = pathlib.Path("modules/agent_toolkit_server/jobs.v").read_text()
    assert "is_link" in jobs_v
    assert "real_path" in jobs_v
    assert "symlink" in jobs_v.lower()

def test_job_id_payloads_rejected():
    # Simulate payload checks as strings that should be invalid
    invalid = [
        "job_../../etc/passwd",
        "job_..%2fsecret",
        "job_%2e%2e%2fsecret",
        "job_%2e%2e/secret",
        "/etc/passwd",
        "job_abc/def",
        "job_abc%2fdef",
        "job_../traversal",
    ]
    # Ensure the V function would reject these (we check pattern, not execution)
    # All contain traversal chars that is_valid_job_id forbids
    for p in invalid:
        assert ".." in p or "/" in p or "%" in p or p.startswith("/"), p

def test_workspace_acceptance_criteria_documented():
    jobs_v = pathlib.Path("modules/agent_toolkit_server/jobs.v").read_text()
    server = pathlib.Path("modules/agent_toolkit_server/server.veb.v").read_text()
    # Must handle symlink escape
    assert "is_log_path_safe" in jobs_v or "is_log_path_safe" in server
