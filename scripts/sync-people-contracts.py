#!/usr/bin/env python3
"""Mirror only the named People contracts. No declarations or user files are copied."""

import argparse
import hashlib
import json
import os
import stat
import tempfile
from pathlib import Path

ROOT = Path(__file__).absolute().parent.parent
MIRRORS = {
    "schemas/person.schema.json": "schemas/person.schema.json",
    "schemas/people-bindings.schema.json": "schemas/people-bindings.schema.json",
    "scripts/validate-people.py": "scripts/workspace/validate-people.py",
}
LOCK = "schemas/people-contracts.lock.json"


def preflight(path):
    """Reject links in every existing ancestor, including dangling final links."""
    path = Path(os.path.abspath(path))
    for ancestor in (*reversed(path.parents), path):
        try:
            mode = ancestor.lstat().st_mode
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(mode):
            raise ValueError("symlinked destination rejected")
        if ancestor != path and not stat.S_ISDIR(mode):
            raise ValueError("destination ancestor is not a directory")
        if ancestor == path and not stat.S_ISREG(mode):
            raise ValueError("destination is not a regular file")


def expected():
    payloads = {dest: (ROOT / source).read_bytes() for dest, source in MIRRORS.items()}
    lock = {
        "spec": "agent-toolkit/people-contracts-lock@1",
        "source": "https://github.com/ulises-jeremias/agent-toolkit",
        "files": {
            dest: {"source": source, "sha256": hashlib.sha256(payloads[dest]).hexdigest()}
            for dest, source in MIRRORS.items()
        },
    }
    payloads[LOCK] = (json.dumps(lock, indent=2, sort_keys=True) + "\n").encode()
    return payloads


def sync(workspace, write=False):
    workspace = Path(os.path.abspath(workspace))
    payloads = expected()
    # Preflight the entire operation before any mkdir/write, not one file at a time.
    for rel in payloads:
        preflight(workspace / rel)
    if not write:
        for rel, data in payloads.items():
            if not (workspace / rel).is_file() or (workspace / rel).read_bytes() != data:
                raise ValueError("People contract mirror drift; run --write after human review")
        return
    for rel, data in payloads.items():
        dest = workspace / rel
        if dest.is_file() and dest.read_bytes() == data:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        # Replace a sibling inode, never truncate an existing outside hardlink.
        fd, name = tempfile.mkstemp(prefix=".people-contract-", dir=dest.parent)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(name, 0o644)
            os.replace(name, dest)
        finally:
            if os.path.exists(name):
                os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    args = parser.parse_args()
    try:
        sync(args.workspace, args.write)
    except (OSError, ValueError):
        # Do not print OS error strings containing untrusted filenames/controls.
        print("People contract sync failed: unsafe destination or mirror drift.")
        return 1
    print("People contract mirrors match." if args.check else "People contract mirrors written.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
