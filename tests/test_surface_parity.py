"""Capability-surface gates (ADR-030).

Parity semantics: the canonical capability contract must be covered by the
programmatic API surface. Presentation parity (TUI/Web) is NOT required —
external clients own their presentation.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs" / "compatibility" / "cli-contract.yaml"
OPENAPI = ROOT / "docs" / "surface" / "openapi.json"
SERVER = ROOT / "modules" / "agent_toolkit_server" / "server.veb.v"
SUB_ROUTES = ROOT / "modules" / "agent_toolkit_server" / "sub_routes.v"

# contract command -> (server allowlist family, request DTO struct)
SUB_ROUTE_FAMILIES = {
    "skills": ("skills", "SkillsSubReq"),
    "mcp": ("mcp", "McpSubReq"),
    "plugin": ("plugin", "PluginSubReq"),
    "workspace": ("workspace", "WorkspaceSubReq"),
    "memory": ("memory", "MemorySubReq"),
    "project": ("project", "ProjectSubReq"),
    "loop": ("loops", "LoopsSubReq"),
    "devcompanion": ("dc", "DcSubReq"),
    "swarm": ("swarms", "SwarmsSubReq"),
}
V_TO_SCHEMA_TYPE = {"string": "string", "bool": "boolean", "int": "integer", "[]string": "string[]"}

RETIRED_ARTIFACTS = [
    ROOT / "modules" / "agent_toolkit_server" / "tui_registry.v",
    ROOT / "docs" / "surface" / "web_nav.json",
]


def _commands():
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    return [c["name"] for c in data.get("commands", [])]


def test_every_command_has_openapi_operation():
    """Every contract command with a programmatic surface (`api` not false)
    must have a corresponding OpenAPI operation."""
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    api_commands = [c["name"] for c in data.get("commands", []) if c.get("api", True)]
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    ops = {op["operationId"] for p in spec["paths"].values() for op in p.values()}
    missing = set(api_commands) - ops
    assert not missing, f"missing routes for: {sorted(missing)}"


def test_openapi_has_scopes_and_confirm_flags():
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    for p in spec["paths"].values():
        for op in p.values():
            assert "x-scope" in op, op["operationId"]
            assert isinstance(op.get("x-confirm-required"), bool)


def test_retired_presentation_artifacts_absent():
    """ADR-030 retired TUI/Web generated registries — they must not reappear."""
    for artifact in RETIRED_ARTIFACTS:
        assert not artifact.exists(), (
            f"{artifact.name} was retired by ADR-030 and must not be regenerated"
        )


def test_registered_routes_const_matches_attributes():
    """The `registered_api_routes` const consumed by runtime selfcheck must
    exactly mirror the @['...'] route attributes in server.veb.v."""
    text = SERVER.read_text(encoding="utf-8")
    attrs = set(re.findall(r"@\['([^']+)';", text))
    attrs.discard("/")

    m = re.search(r"const registered_api_routes = \[(.*?)\]", text, re.DOTALL)
    assert m, "registered_api_routes const missing"
    const_items = set(re.findall(r"'([^']+)'", m.group(1)))

    assert attrs == const_items, (
        f"drift — attributes-only: {sorted(attrs - const_items)}, "
        f"const-only: {sorted(const_items - attrs)}"
    )


def test_openapi_paths_match_registered_routes():
    """OpenAPI must describe exactly the registered server API routes (the
    landing '/' is presentation, not an API path)."""
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_paths = {p.replace("{", ":").replace("}", "") for p in spec["paths"]}
    text = SERVER.read_text(encoding="utf-8")
    registered = set(re.findall(r"@\['([^']+)';", text))
    registered.discard("/")

    missing_in_openapi = registered - openapi_paths
    assert not missing_in_openapi, f"routes without OpenAPI docs: {sorted(missing_in_openapi)}"

    undeclared_in_server = openapi_paths - registered
    assert not undeclared_in_server, f"OpenAPI paths without routes: {sorted(undeclared_in_server)}"


def test_openapi_version_matches_version_file():
    """OpenAPI info.version must match VERSION file (stale artifact detection)."""
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_version = spec.get("info", {}).get("version", "")
    version_file = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    assert openapi_version == version_file, (
        f"OpenAPI version {openapi_version!r} != VERSION {version_file!r} — run ./scripts/generate_surface.vsh"
    )


def test_contract_to_openapi_to_routes_triple_parity():
    """Triple parity: contract (api:true) ↔ openapi operations ↔ registered routes ↔ CLI help."""
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    contract_api = {c["name"] for c in data.get("commands", []) if c.get("api", True)}
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_ops = {op["operationId"] for p in spec["paths"].values() for op in p.values()}
    # Filter to contract-mirrored ops (exclude server-native like health, selfcheck, jobs, etc.)
    contract_ops = openapi_ops & contract_api
    assert contract_api == contract_ops, (
        f"contract→openapi drift: missing {sorted(contract_api - contract_ops)}"
    )
    text = SERVER.read_text(encoding="utf-8")
    registered = set(re.findall(r"@\['([^']+)';", text))
    registered.discard("/")
    # Also check CLI help generated from contract exists and is fresh (handled by generate_surface --check)
    help_path = ROOT / "docs" / "surface" / "cli-help.md"
    assert help_path.exists(), "docs/surface/cli-help.md missing — run generate_surface.vsh"
    help_text = help_path.read_text(encoding="utf-8")
    for name in contract_api:
        assert f"`{name}`" in help_text, f"CLI help missing contract command {name!r}"


def _server_sub_allowlists():
    text = SUB_ROUTES.read_text(encoding="utf-8")
    m = re.search(r"const sub_route_allowlist = \{(.*?)\n\}", text, re.DOTALL)
    assert m, "sub_route_allowlist const missing in sub_routes.v"
    out = {}
    for family, items in re.findall(r"'([a-z]+)':\s*\[(.*?)\]", m.group(1), re.DOTALL):
        out[family] = re.findall(r"'([^']+)'", items)
    return out


def _server_dto_fields(struct_name):
    text = SUB_ROUTES.read_text(encoding="utf-8")
    m = re.search(rf"struct {struct_name} \{{(.*?)\}}", text, re.DOTALL)
    assert m, f"struct {struct_name} missing in sub_routes.v"
    fields = {}
    for line in m.group(1).splitlines():
        parts = line.split()
        if len(parts) >= 2 and not parts[0].startswith("//"):
            fields[parts[0]] = V_TO_SCHEMA_TYPE[parts[1]]
    return fields


def test_sub_route_allowlists_match_contract():
    """The server's per-family :sub allowlist is exactly the contract's
    api_subcommands, which is exactly the OpenAPI `sub` enum."""
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    by_name = {c["name"]: c for c in data.get("commands", [])}
    server = _server_sub_allowlists()
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    assert set(server) == {fam for fam, _ in SUB_ROUTE_FAMILIES.values()}
    for cmd_name, (family, _) in SUB_ROUTE_FAMILIES.items():
        contract_subs = by_name[cmd_name].get("api_subcommands")
        assert contract_subs, f"{cmd_name}: api_subcommands missing in contract"
        assert server[family] == contract_subs, (
            f"{cmd_name}: server allowlist {server[family]} != contract {contract_subs}"
        )
        path = f"/api/v1/{family}/{{sub}}"
        params = spec["paths"][path]["post"]["parameters"]
        sub_param = next(p for p in params if p["name"] == "sub")
        assert sub_param["schema"]["enum"] == contract_subs, f"{path}: OpenAPI sub enum drift"


def test_sub_route_bodies_match_contract():
    """Every typed DTO field (name + type) is declared as a contract api_body
    field and an OpenAPI requestBody property, and no DTO has a subcommand."""
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    by_name = {c["name"]: c for c in data.get("commands", [])}
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    for cmd_name, (family, struct_name) in SUB_ROUTE_FAMILIES.items():
        dto = _server_dto_fields(struct_name)
        assert "subcommand" not in dto, f"{struct_name} must not carry a subcommand"
        contract = {}
        for spec_field in by_name[cmd_name].get("api_body", []):
            name, typ = spec_field.split(":", 1)
            contract[name] = typ.split("=", 1)[0]
        assert dto == contract, f"{cmd_name}: DTO {dto} != contract api_body {contract}"
        schema = spec["paths"][f"/api/v1/{family}/{{sub}}"]["post"]["requestBody"]["content"][
            "application/json"
        ]["schema"]
        assert set(schema["properties"]) == set(contract), f"{family}: requestBody drift"


API_SCHEMAS = ROOT / "docs" / "compatibility" / "api-schemas.yaml"
V_STRUCT_DIRS = [ROOT / "modules" / "agent_toolkit_server", ROOT / "modules" / "agent_toolkit_core"]
V_SCALARS = {"string": "string", "bool": "boolean", "int": "integer", "i64": "integer",
             "u64": "integer", "f64": "number"}


def _v_struct_sources():
    out = {}
    for d in V_STRUCT_DIRS:
        for f in sorted(d.glob("*.v")):
            if f.name.endswith("_test.v"):
                continue
            text = f.read_text(encoding="utf-8")
            for m in re.finditer(r"^(?:pub )?struct (\w+) \{\n(.*?)^\}", text, re.DOTALL | re.MULTILINE):
                out.setdefault(m.group(1), m.group(2))
    return out


def _v_type_to_schema(vtype, struct_to_schema):
    if vtype.startswith("[]"):
        return _v_type_to_schema(vtype[2:], struct_to_schema) + "[]"
    if vtype.startswith("map[string]"):
        return f"map<{_v_type_to_schema(vtype[len('map[string]'):], struct_to_schema)}>"
    if vtype in V_SCALARS:
        return V_SCALARS[vtype]
    if vtype in struct_to_schema:
        return "#" + struct_to_schema[vtype]
    return f"<unmapped {vtype}>"


def _v_json_fields(body, struct_to_schema):
    fields = {}
    for raw in body.splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.endswith(":"):
            continue
        attrs = re.search(r"@\[(.*?)\]", line)
        attr = attrs.group(1) if attrs else ""
        if "skip" in attr.split(";") or "json: '-'" in attr:
            continue
        decl = line.split("@[")[0].split("=")[0].split("//")[0].split()
        if len(decl) < 2:
            continue
        name, vtype = decl[0], decl[1]
        rename = re.search(r"json:\s*'([^']+)'", attr)
        fields[rename.group(1) if rename else name] = _v_type_to_schema(vtype, struct_to_schema)
    return fields


def test_response_schemas_match_v_structs():
    """Every api-schemas.yaml schema has exactly the JSON fields (name + type)
    that its V struct encodes, so typed clients never drift from the server."""
    data = yaml.safe_load(API_SCHEMAS.read_text(encoding="utf-8"))
    schemas = data["schemas"]
    struct_to_schema = {s.get("v_struct", s["name"]): s["name"] for s in schemas}
    sources = _v_struct_sources()
    for s in schemas:
        struct = s.get("v_struct", s["name"])
        assert struct in sources, f"schema {s['name']}: V struct {struct} not found"
        v_fields = _v_json_fields(sources[struct], struct_to_schema)
        declared = {}
        for spec in s["fields"]:
            name, typ = spec.split(":", 1)
            declared[name.rstrip("?")] = typ.split("=", 1)[0]
        assert v_fields == declared, f"schema {s['name']} != struct {struct}: {v_fields} vs {declared}"


def test_native_endpoints_match_route_methods():
    """Each api-schemas.yaml native endpoint is served with that HTTP method."""
    data = yaml.safe_load(API_SCHEMAS.read_text(encoding="utf-8"))
    text = SERVER.read_text(encoding="utf-8")
    served = {}
    for path, methods in re.findall(r"@\['([^']+)';\s*([^\]]+)\]", text):
        served.setdefault(path, set()).update(m.strip() for m in methods.split(";"))
    for entry in data["native"]:
        route = entry["path"].replace("{", ":").replace("}", "")
        assert entry["method"] in served.get(route, set()), (
            f"{entry['method'].upper()} {entry['path']} ({entry['op']}) has no route attribute"
        )
