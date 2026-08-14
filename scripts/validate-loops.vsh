#!/usr/bin/env -S v run
// Validate all loops/**/loop.yaml against schemas/loop.schema.json.
// Uses python3 + jsonschema (same engine as CI). Requires: pyyaml, jsonschema.
// Usage: v run scripts/validate-loops.vsh   (from repo root or any subdir)

fn repo_root() string {
	mut d := dir(@FILE)
	// scripts/ -> repo root
	d = dir(d)
	if is_file(join_path(d, 'VERSION')) {
		return d
	}
	return getwd()
}

const py_script = r"
import json, sys, yaml
from pathlib import Path
from jsonschema import validate, ValidationError

schema_path = Path('schemas/loop.schema.json')
if not schema_path.is_file():
    print('schemas/loop.schema.json not found — skipping.')
    sys.exit(0)

loops_dir = Path('loops')
if not loops_dir.is_dir():
    print('No loops/ directory — skipping.')
    sys.exit(0)

schema = json.loads(schema_path.read_text())
errors = []
loop_files = sorted(loops_dir.rglob('loop.yaml'))

if not loop_files:
    print('No loop.yaml files found — nothing to validate.')
    sys.exit(0)

print()
print('Validating loop.yaml templates against loop.schema.json...')
print()

for f in loop_files:
    try:
        d = yaml.safe_load(f.read_text())
        validate(d, schema)
        print(f'  OK: {f}')
    except ValidationError as e:
        errors.append(f'  FAIL: {f}: {e.message}')
        print(f'  FAIL: {f}: {e.message}', file=sys.stderr)
    except Exception as e:
        errors.append(f'  FAIL: {f}: {e}')
        print(f'  FAIL: {f}: {e}', file=sys.stderr)

print()
if errors:
    print(f'{len(errors)} loop validation error(s).', file=sys.stderr)
    sys.exit(1)

print(f'All {len(loop_files)} loop template(s) valid.')
"

fn main() {
	root := repo_root()
	chdir(root) or {
		eprintln('cannot chdir to ${root}: ${err}')
		exit(1)
	}

	tmp := join_path(temp_dir(), 'agent-toolkit-validate-loops.py')
	write_file(tmp, py_script) or {
		eprintln('cannot write temp script: ${err}')
		exit(1)
	}
	defer {
		rm(tmp) or {}
	}

	rc := system('python3 ${tmp}')
	if rc != 0 {
		exit(if rc < 0 { 1 } else { rc })
	}
}
