#!/usr/bin/env python3
"""Offline People declaration validation. Requires jsonschema and PyYAML."""

import argparse
import hashlib
import json
import math
import os
import re
import stat
from pathlib import Path

LIMIT = 64 * 1024
FILES = {
    "schemas/person.schema.json": "schemas/person.schema.json",
    "schemas/people-bindings.schema.json": "schemas/people-bindings.schema.json",
    "scripts/validate-people.py": "scripts/workspace/validate-people.py",
}
LOCK = "schemas/people-contracts.lock.json"
ID = re.compile(r"[a-z0-9][a-z0-9_-]{0,63}\Z")


def safe_path(path, directory=False):
    path = Path(os.path.abspath(path))
    for ancestor in (*reversed(path.parents), path):
        try:
            mode = ancestor.lstat().st_mode
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(mode):
            raise ValueError("symlink rejected")
        is_dir = ancestor != path or directory
        if is_dir and not stat.S_ISDIR(mode):
            raise ValueError("not a directory")
        if not is_dir and not stat.S_ISREG(mode):
            raise ValueError("not a regular file")


def read(path):
    safe_path(path)
    with path.open("rb") as stream:
        data = stream.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("declaration exceeds 64 KiB")
    return data


def pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def reject_constant(_value):
    raise ValueError("nonfinite number")


def finite_tree(value, ancestors=None, count=None):
    ancestors = set() if ancestors is None else ancestors
    count = [0] if count is None else count
    count[0] += 1
    if count[0] > 4096 or len(ancestors) > 64:
        raise ValueError("declaration is too complex")
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError("nonfinite number")
    if isinstance(value, (dict, list)):
        if id(value) in ancestors:
            raise ValueError("recursive declaration")
        ancestors.add(id(value))
        children = list(value.items()) if isinstance(value, dict) else enumerate(value)
        for key, child in children:
            if isinstance(value, dict) and not isinstance(key, str):
                raise ValueError("nonstring key")
            finite_tree(child, ancestors, count)
        ancestors.remove(id(value))


def parse_json(data):
    value = json.loads(data, object_pairs_hook=pairs, parse_constant=reject_constant)
    finite_tree(value)
    return value


def verify_mirrors(workspace):
    """STOP before parsing/evaluating any schema if any locked bytes have changed."""
    lock = parse_json(read(workspace / LOCK))
    if (
        not isinstance(lock, dict)
        or set(lock) != {"spec", "source", "files"}
        or lock["spec"] != "agent-toolkit/people-contracts-lock@1"
        or lock["source"] != "https://github.com/ulises-jeremias/agent-toolkit"
        or not isinstance(lock["files"], dict)
        or set(lock["files"]) != set(FILES)
    ):
        raise ValueError("invalid contract lock")
    payloads = {}
    for rel, source in FILES.items():
        entry = lock["files"][rel]
        if (
            not isinstance(entry, dict)
            or set(entry) != {"source", "sha256"}
            or entry["source"] != source
        ):
            raise ValueError("invalid contract lock entry")
        data = read(workspace / rel)
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError("contract mirror drift")
        payloads[rel] = data
    return payloads


def no_network(uri):
    from referencing.exceptions import NoSuchResource

    raise NoSuchResource(ref=uri)


def validator(schema):
    from jsonschema import Draft202012Validator
    from referencing import Registry

    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=Registry(retrieve=no_network))


def parse_yaml(data):
    import yaml

    class UniqueLoader(yaml.SafeLoader):
        pass

    def mapping(loader, node):
        return pairs(
            (loader.construct_object(k), loader.construct_object(v)) for k, v in node.value
        )

    UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
    value = yaml.load(data.decode("utf-8"), Loader=UniqueLoader)
    finite_tree(value)
    return value


def validate(workspace):
    workspace = Path(os.path.abspath(workspace))
    safe_path(workspace, directory=True)
    payloads = verify_mirrors(workspace)
    people_validator = validator(parse_json(payloads["schemas/person.schema.json"]))
    bindings_validator = validator(parse_json(payloads["schemas/people-bindings.schema.json"]))
    people = {}
    for directory in (workspace / "people", workspace / "templates/people"):
        safe_path(directory, directory=True)
        if not directory.exists():
            continue
        for path in sorted(directory.iterdir()):
            # Reject linked entries even when their extension would otherwise be ignored.
            safe_path(path, directory=path.is_dir())
            if path.suffix != ".json":
                continue
            person = parse_json(read(path))
            if next(people_validator.iter_errors(person), None) is not None:
                raise ValueError("Person schema violation")
            if not ID.fullmatch(path.stem) or person["id"] != path.stem:
                raise ValueError("Person id must match filename")
            if directory == workspace / "people":
                people[person["id"]] = person
    bindings_path = workspace / "people/bindings.yaml"
    safe_path(bindings_path)
    if bindings_path.exists():
        bindings = parse_yaml(read(bindings_path))
        if next(bindings_validator.iter_errors(bindings), None) is not None:
            raise ValueError("People bindings schema violation")
        for choice in bindings["roles"].values():
            refs = choice.get("preferred_people", []) + (
                [choice["person_id"]] if "person_id" in choice else []
            )
            if any(ref not in people for ref in refs):
                raise ValueError("People binding references missing Person")
    return len(people)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    args = parser.parse_args()
    try:
        count = validate(args.workspace)
    except ImportError:
        print("People validation failed: install jsonschema and PyYAML for offline validation.")
        return 1
    except Exception:
        # Never echo values, dynamic keys, validator paths, or exception text.
        # A static diagnostic is intentionally less detailed than jsonschema's message.
        print(
            "People validation failed: unsafe/malformed declaration, missing reference, or contract drift."
        )
        return 1
    print(f"People declarations valid: {count} configured. No runtime activity inferred.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
