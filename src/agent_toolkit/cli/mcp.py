"""
mcp — MCP (Model Context Protocol) provider management.

Usage:
    agent-toolkit mcp <subcommand> [args]

Subcommands:
    list                   List available MCP providers
    setup <provider>       Interactive wizard to configure a provider
    doctor [provider]      Check env vars and connectivity for provider(s)

Options:
    --help    Show this help message
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Toolkit directory & config paths
# ---------------------------------------------------------------------------

def _find_toolkit_dir() -> Path | None:
    candidate = Path(__file__).resolve()
    for _ in range(10):
        candidate = candidate.parent
        if (candidate / "profiles").is_dir():
            return candidate
    return None


def _mcp_config_path() -> Path:
    return Path.home() / ".config" / "agent-toolkit" / "mcp-config.json"


def _templates_dir(toolkit_dir: Path) -> Path:
    return toolkit_dir / "mcp" / "templates"


# ---------------------------------------------------------------------------
# Config I/O
# ---------------------------------------------------------------------------

def _load_config() -> dict:
    path = _mcp_config_path()
    if not path.exists():
        return {"providers": {}}
    try:
        return json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return {"providers": {}}


def _save_config(cfg: dict) -> None:
    path = _mcp_config_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(cfg, indent=2) + "\n")
    except (PermissionError, OSError) as exc:
        print(f"  ✗  Failed to save config: {exc}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Template parsing
# ---------------------------------------------------------------------------

def _extract_env_vars(template: dict) -> list[str]:
    """Extract ${ENV_VAR} names from all string values in a dict (recursive)."""
    pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
    found: list[str] = []

    def _walk(obj: object) -> None:
        if isinstance(obj, str):
            for m in pattern.finditer(obj):
                name = m.group(1)
                if name not in found:
                    found.append(name)
        elif isinstance(obj, dict):
            for v in obj.values():
                _walk(v)
        elif isinstance(obj, list):
            for item in obj:
                _walk(item)

    _walk(template)
    return found


def _load_template(templates_dir: Path, provider: str) -> dict | None:
    """Load and parse a provider's config.template.json."""
    template_file = templates_dir / provider / "config.template.json"
    if not template_file.exists():
        return None
    try:
        return json.loads(template_file.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        print(f"  ✗  Cannot read template {template_file}: {exc}", file=sys.stderr)
        return None


def _load_readme(templates_dir: Path, provider: str) -> str:
    readme = templates_dir / provider / "README.md"
    if readme.exists():
        try:
            return readme.read_text().strip()
        except OSError:
            pass
    return ""


# ---------------------------------------------------------------------------
# Connectivity tests
# ---------------------------------------------------------------------------

def _test_github(token: str) -> tuple[bool, str]:
    try:
        req = urllib.request.Request("https://api.github.com/user")
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("User-Agent", "agent-toolkit-mcp/1")
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read())
            return True, f"Authenticated as: {data.get('login', 'unknown')}"
    except urllib.error.HTTPError as exc:
        return False, f"HTTP {exc.code}: {exc.reason}"
    except Exception as exc:
        return False, str(exc)


def _test_connectivity(provider: str, env_vals: dict[str, str]) -> tuple[bool, str]:
    """Run a lightweight connectivity test if we know how for this provider."""
    if provider == "github":
        token = env_vals.get("GITHUB_TOKEN", "")
        if token:
            return _test_github(token)
        return False, "GITHUB_TOKEN not provided"
    # For other providers we just confirm env vars are set
    return True, "env vars provided (connectivity test not available for this provider)"


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def _cmd_list(toolkit_dir: Path | None) -> int:
    """List available MCP providers from mcp/templates/."""
    if toolkit_dir is None:
        print("  ✗  Cannot locate toolkit directory", file=sys.stderr)
        return 1

    tdir = _templates_dir(toolkit_dir)
    if not tdir.is_dir():
        print(f"  ✗  MCP templates directory not found: {tdir}", file=sys.stderr)
        return 1

    providers = sorted(p.name for p in tdir.iterdir() if p.is_dir())
    if not providers:
        print("  ⚠  No MCP provider templates found")
        return 0

    cfg = _load_config()
    configured = cfg.get("providers", {})

    print()
    print("Available MCP providers")
    print()
    col_name = max(len(p) for p in providers) + 2

    header = f"  {'Provider':<{col_name}}  {'Status':<12}  Required env vars"
    print(header)
    print("  " + "-" * (len(header) - 2))

    for provider in providers:
        template = _load_template(tdir, provider)
        env_vars = _extract_env_vars(template) if template else []
        env_str = ", ".join(env_vars) if env_vars else "(none)"

        prov_cfg = configured.get(provider, {})
        if prov_cfg.get("enabled"):
            status = "✓ configured"
        elif prov_cfg:
            status = "- disabled"
        else:
            status = "  not setup"

        print(f"  {provider:<{col_name}}  {status:<12}  {env_str}")

    print()
    print("Run: agent-toolkit mcp setup <provider>")
    print()
    return 0


def _cmd_setup(provider: str, toolkit_dir: Path | None) -> int:
    """Interactive wizard to configure an MCP provider."""
    if toolkit_dir is None:
        print("  ✗  Cannot locate toolkit directory", file=sys.stderr)
        return 1

    tdir = _templates_dir(toolkit_dir)
    template = _load_template(tdir, provider)
    if template is None:
        providers = sorted(p.name for p in tdir.iterdir() if p.is_dir()) if tdir.is_dir() else []
        print(f"  ✗  Provider '{provider}' not found.", file=sys.stderr)
        if providers:
            print(f"  Available: {', '.join(providers)}", file=sys.stderr)
        return 1

    env_vars = _extract_env_vars(template)
    readme = _load_readme(tdir, provider)

    print()
    print(f"MCP setup: {provider}")
    print()

    if readme:
        # Print the first paragraph of the README as a hint
        first_para = readme.split("\n\n")[0]
        for line in first_para.splitlines():
            print(f"  {line}")
        print()

    if not env_vars:
        print("  ⚠  No environment variables required for this provider.")
    else:
        print(f"  Required env vars: {', '.join(env_vars)}")
        print()

    # Collect env var values
    import getpass
    env_vals: dict[str, str] = {}
    token_words = ("TOKEN", "KEY", "SECRET", "PASSWORD", "PASS")

    for var in env_vars:
        current = os.environ.get(var, "")
        is_sensitive = any(w in var.upper() for w in token_words)

        if current:
            hint = f"[already set in env"
            if is_sensitive:
                hint += ", press Enter to keep]"
            else:
                hint += f" = {current!r}, press Enter to keep]"
        else:
            hint = "[required]"

        prompt = f"  {var} {hint}: "

        try:
            if is_sensitive:
                value = getpass.getpass(prompt) or current
            else:
                value = input(prompt).strip() or current
        except (EOFError, KeyboardInterrupt):
            print()
            print("  ⚠  Setup cancelled")
            return 1

        env_vals[var] = value

    # Validate / test connectivity
    print()
    print("  Testing connectivity...")
    ok, detail = _test_connectivity(provider, env_vals)
    if ok:
        print(f"  ✓  {detail}")
    else:
        print(f"  ⚠  Connectivity check failed: {detail}")
        print("     Saving configuration anyway — double-check your credentials.")

    # Save config: store env var names (not plaintext values)
    cfg = _load_config()
    cfg.setdefault("providers", {})[provider] = {
        "enabled": True,
        "required_env": env_vars,
        "validated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    _save_config(cfg)
    print(f"  ✓  Saved to {_mcp_config_path()}")
    print()

    # Next steps per tool
    print("── Next steps ──")
    print()
    print("  Export env vars in your shell profile (e.g. ~/.zshrc / ~/.bashrc):")
    print()
    for var in env_vars:
        print(f"    export {var}=\"<your-value>\"")
    print()
    print("  Then configure each AI tool:")
    print("    Claude Code  → add MCP server to ~/.claude/settings.json")
    print("    Cursor       → add MCP server in Cursor Settings → MCP")
    print("    OpenCode     → add entry to ~/.config/opencode/opencode.json")
    print()
    print(f"  See: mcp/templates/{provider}/README.md for full instructions")
    print()
    return 0


def _cmd_doctor_provider(provider: str, toolkit_dir: Path | None) -> tuple[int, int, int]:
    """Check a single provider. Returns (ok, warn, err) counts."""
    n_ok = n_warn = n_err = 0

    if toolkit_dir:
        tdir = _templates_dir(toolkit_dir)
        template = _load_template(tdir, provider)
        env_vars = _extract_env_vars(template) if template else []
    else:
        env_vars = []

    cfg = _load_config()
    prov_cfg = cfg.get("providers", {}).get(provider, {})
    if not prov_cfg:
        print(f"  ⚠  {provider}: not configured (run: agent-toolkit mcp setup {provider})")
        n_warn += 1
    else:
        enabled = prov_cfg.get("enabled", False)
        validated = prov_cfg.get("validated_at", "never")
        icon = "✓" if enabled else "⚠"
        print(f"  {icon}  {provider}: enabled={enabled}, validated_at={validated}")
        if enabled:
            n_ok += 1
        else:
            n_warn += 1

    # Check env vars
    for var in env_vars:
        if os.environ.get(var):
            print(f"  ✓  {var}: set")
            n_ok += 1
        else:
            print(f"  ✗  {var}: not set in environment")
            n_err += 1

    # Connectivity test
    env_vals = {v: os.environ.get(v, "") for v in env_vars}
    if all(env_vals.values()):
        ok, detail = _test_connectivity(provider, env_vals)
        if ok:
            print(f"  ✓  connectivity: {detail}")
            n_ok += 1
        else:
            print(f"  ⚠  connectivity: {detail}")
            n_warn += 1

    return n_ok, n_warn, n_err


def _cmd_doctor(providers_arg: list[str], toolkit_dir: Path | None) -> int:
    """Check MCP provider configuration and connectivity."""
    cfg = _load_config()
    configured_providers = list(cfg.get("providers", {}).keys())

    if providers_arg:
        targets = providers_arg
    elif configured_providers:
        targets = configured_providers
    else:
        print("  ⚠  No MCP providers configured. Run: agent-toolkit mcp list")
        return 0

    print()
    print("MCP doctor")

    total_ok = total_warn = total_err = 0
    for provider in targets:
        print(f"\n── {provider} ──")
        n_ok, n_warn, n_err = _cmd_doctor_provider(provider, toolkit_dir)
        total_ok += n_ok
        total_warn += n_warn
        total_err += n_err

    print()
    print(f"── Summary: {total_ok} ok, {total_warn} warnings, {total_err} errors ──")
    print()
    return 1 if total_err else 0


# ---------------------------------------------------------------------------
# Argument parsing & dispatch
# ---------------------------------------------------------------------------

def cmd_mcp(args: list[str]) -> int:
    """MCP provider management entry point.

    Returns 0 on success, 1 on failure.
    """
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    toolkit_dir = _find_toolkit_dir()
    subcommand = args[0]
    rest = args[1:]

    if subcommand == "list":
        return _cmd_list(toolkit_dir)

    elif subcommand == "setup":
        if not rest:
            print("  ✗  Usage: agent-toolkit mcp setup <provider>", file=sys.stderr)
            return 1
        return _cmd_setup(rest[0], toolkit_dir)

    elif subcommand == "doctor":
        return _cmd_doctor(rest, toolkit_dir)

    else:
        print(f"  ✗  Unknown subcommand: {subcommand}", file=sys.stderr)
        print("  Valid subcommands: list, setup, doctor", file=sys.stderr)
        return 1
