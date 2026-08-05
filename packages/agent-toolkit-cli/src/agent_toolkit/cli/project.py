"""
project — Project-first lifecycle: init, clone, list, add, remove, sync, scan.

Usage:
    agent-toolkit project <subcommand> [args]

Subcommands:
    init [--workspace PATH]               Initialize projects/ and projects.yaml
    clone owner/repo [--workspace PATH]   Clone a GitHub repo and create a symlink
    list [--workspace PATH]               List all symlinked projects
    add <path> [--workspace PATH]         Symlink an already-cloned repo
    remove <name> [--workspace PATH]      Remove symlink (keeps the actual repo)
    sync [--workspace PATH]               Sync projects.yaml from projects/ symlinks
    scan [--workspace PATH]               Check project/repo consistency

Structure:
    <workspace>/repos/github.com/<owner>/<repo>/   (gitignored)
    <workspace>/projects/<repo> -> ../repos/...    (gitignored)

Options:
    --help    Show this help message
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import sys as _sys
if _sys.platform == 'win32':
    try:
        _sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        _sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def _blue(t: str) -> str:   return _c("1;34", t)
def _green(t: str) -> str:  return _c("1;32", t)
def _yellow(t: str) -> str: return _c("1;33", t)
def _cyan(t: str) -> str:   return _c("0;36", t)
def _dim(t: str) -> str:    return _c("0;37", t)


# ---------------------------------------------------------------------------
# Workspace root detection
# ---------------------------------------------------------------------------

def _find_workspace(override: str | None = None) -> Path | None:
    """Locate workspace root via env, override, or walking up from CWD."""
    if override:
        p = Path(override).expanduser().resolve()
        return p if p.is_dir() else None

    env = os.environ.get("AGENT_TOOLKIT_WORKSPACE")
    if env:
        p = Path(env).expanduser().resolve()
        return p if p.is_dir() else None

    current = Path.cwd()
    for candidate in [current, *current.parents]:
        if (candidate / "AGENTS.md").exists() or (candidate / "knowledge").is_dir():
            return candidate

    return None


# ---------------------------------------------------------------------------
# projects.yaml helpers
# ---------------------------------------------------------------------------

def _projects_yaml_path(ws: Path) -> Path:
    return ws / "projects.yaml"


def _load_projects_yaml(ws: Path) -> dict:
    """Read projects.yaml as a simple dict (stdlib only — no PyYAML required)."""
    path = _projects_yaml_path(ws)
    if not path.exists():
        return {"projects": []}
    # Parse minimal YAML manually: list of mappings with name/path/source keys
    projects: list[dict] = []
    current: dict | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("- name:"):
            if current is not None:
                projects.append(current)
            current = {"name": stripped[len("- name:"):].strip()}
        elif stripped.startswith("name:") and current is None:
            current = {"name": stripped[len("name:"):].strip()}
        elif current is not None:
            for key in ("path", "source", "cloned_at"):
                if stripped.startswith(f"{key}:"):
                    current[key] = stripped[len(f"{key}:"):].strip()
    if current is not None:
        projects.append(current)
    return {"projects": projects}


def _save_projects_yaml(ws: Path, data: dict) -> None:
    """Write projects.yaml in simple YAML list format."""
    path = _projects_yaml_path(ws)
    lines = ["projects:"]
    for entry in data.get("projects", []):
        lines.append(f"  - name: {entry.get('name', '')}")
        for key in ("path", "source", "cloned_at"):
            if entry.get(key):
                lines.append(f"    {key}: {entry[key]}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _upsert_project(ws: Path, name: str, path: str, source: str = "") -> None:
    """Add or update an entry in projects.yaml."""
    from datetime import date
    data = _load_projects_yaml(ws)
    projects = data["projects"]
    for entry in projects:
        if entry.get("name") == name:
            entry["path"] = path
            if source:
                entry["source"] = source
            break
    else:
        new_entry: dict = {"name": name, "path": path, "cloned_at": date.today().isoformat()}
        if source:
            new_entry["source"] = source
        projects.append(new_entry)
    data["projects"] = projects
    _save_projects_yaml(ws, data)


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_init(args: list[str], ws: Path) -> int:
    """Initialize projects/ directory and projects.yaml manifest."""
    for arg in args:
        if arg in ("--help", "-h"):
            print("Usage: agent-toolkit project init [--workspace PATH]")
            return 0

    created: list[str] = []
    for dirname in ("projects", "repos"):
        path = ws / dirname
        if not path.is_dir():
            path.mkdir(parents=True, exist_ok=True)
            created.append(f"{dirname}/")

    yaml_path = _projects_yaml_path(ws)
    if not yaml_path.exists():
        _save_projects_yaml(ws, {"projects": []})
        created.append("projects.yaml")

    print(f"\n{_green('Project lifecycle initialized:')} {ws}\n")
    if created:
        for rel in created:
            print(f"  {_green('++')}  {rel}")
    else:
        print(_dim("  (already initialized)"))
    print()
    print(_dim("Next: agent-toolkit project clone owner/repo"))
    print()
    return 0


def cmd_sync(args: list[str], ws: Path) -> int:
    """Rebuild projects.yaml entries from projects/ symlinks."""
    for arg in args:
        if arg in ("--help", "-h"):
            print("Usage: agent-toolkit project sync [--workspace PATH]")
            return 0

    projects_dir = ws / "projects"
    if not projects_dir.is_dir():
        print("Error: projects/ not found — run 'agent-toolkit project init' first.", file=sys.stderr)
        return 1

    from datetime import date

    entries: list[dict] = []
    for link in sorted(projects_dir.iterdir()):
        if not link.is_symlink():
            continue
        target = link.resolve()
        entry: dict = {
            "name": link.name,
            "path": str(target),
            "cloned_at": date.today().isoformat(),
        }
        # Infer github.com source when under repos/github.com/
        try:
            rel = target.relative_to(ws / "repos")
            if len(rel.parts) >= 3 and rel.parts[0] == "github.com":
                entry["source"] = "/".join(rel.parts[:3])
        except ValueError:
            pass
        entries.append(entry)

    _save_projects_yaml(ws, {"projects": entries})
    print(_green(f"Synced {len(entries)} project(s) to projects.yaml"))
    return 0


def cmd_clone(args: list[str], ws: Path) -> int:
    """Clone a GitHub repo and create a symlink in projects/."""
    if not args or args[0] in ("--help", "-h"):
        print("Usage: agent-toolkit project clone owner/repo [--workspace PATH]")
        return 0

    repo_slug = args[0]
    if "/" not in repo_slug:
        print(f"Error: expected owner/repo, got: {repo_slug}", file=sys.stderr)
        return 1

    owner, repo_name = repo_slug.split("/", 1)
    repos_dir = ws / "repos" / "github.com" / owner
    target_dir = repos_dir / repo_name
    projects_dir = ws / "projects"
    link_path = projects_dir / repo_name

    # Clone if not already present
    if target_dir.is_dir():
        print(f"{_yellow('Already cloned:')} {target_dir}")
    else:
        repos_dir.mkdir(parents=True, exist_ok=True)
        # Prefer `gh repo clone` if available, fall back to git clone HTTPS
        if shutil.which("gh"):
            cmd = ["gh", "repo", "clone", f"{owner}/{repo_name}", str(target_dir)]
            verb = "gh repo clone"
        else:
            url = f"https://github.com/{owner}/{repo_name}.git"
            cmd = ["git", "clone", url, str(target_dir)]
            verb = "git clone"

        print(f"Cloning {owner}/{repo_name} via {verb} ...")
        try:
            result = subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as exc:
            print(f"Error: clone failed (exit {exc.returncode})", file=sys.stderr)
            return 1
        print(_green(f"Cloned to {target_dir}"))

    # Create symlink
    projects_dir.mkdir(parents=True, exist_ok=True)
    if link_path.is_symlink():
        link_path.unlink()
    link_path.symlink_to(target_dir)
    print(_green(f"Symlink: projects/{repo_name} -> {target_dir}"))

    # Update projects.yaml
    _upsert_project(ws, repo_name, str(target_dir), source=f"github.com/{owner}/{repo_name}")
    print(_dim(f"Updated projects.yaml"))

    return 0


def cmd_list(args: list[str], ws: Path) -> int:
    """List all symlinks in projects/ with their targets and status."""
    for arg in args:
        if arg in ("--help", "-h"):
            print("Usage: agent-toolkit project list [--workspace PATH]")
            return 0

    projects_dir = ws / "projects"
    print(f"\n{_blue('=== Projects ===')}\n")

    if not projects_dir.is_dir():
        print(_dim("  (projects/ directory not found)"))
        print()
        return 0

    links = sorted(p for p in projects_dir.iterdir() if p.is_symlink())
    if not links:
        print(_dim("  (no projects — run: agent-toolkit project clone owner/repo)"))
        print()
        return 0

    for link in links:
        try:
            target = link.readlink()
        except AttributeError:
            # Python < 3.9 fallback
            target = Path(os.readlink(str(link)))
        exists = link.resolve().exists()
        status = _green("ok") if exists else _yellow("broken")
        print(f"  [{status}]  {link.name:30s} -> {target}")

    print()
    return 0


def cmd_add(args: list[str], ws: Path) -> int:
    """Create a symlink in projects/ for an already-cloned repo."""
    if not args or args[0] in ("--help", "-h"):
        print("Usage: agent-toolkit project add <path> [--workspace PATH]")
        return 0

    repo_path = Path(args[0]).expanduser().resolve()
    if not repo_path.is_dir():
        print(f"Error: not a directory: {repo_path}", file=sys.stderr)
        return 1

    repo_name = repo_path.name
    projects_dir = ws / "projects"
    link_path = projects_dir / repo_name

    projects_dir.mkdir(parents=True, exist_ok=True)
    if link_path.is_symlink():
        existing = link_path.readlink() if hasattr(link_path, "readlink") else Path(os.readlink(str(link_path)))
        print(f"{_yellow('Replacing existing symlink:')} {existing}")
        link_path.unlink()

    link_path.symlink_to(repo_path)
    print(_green(f"Symlink: projects/{repo_name} -> {repo_path}"))

    _upsert_project(ws, repo_name, str(repo_path))
    print(_dim("Updated projects.yaml"))
    return 0


def cmd_remove(args: list[str], ws: Path) -> int:
    """Remove a symlink from projects/ without deleting the actual repo."""
    if not args or args[0] in ("--help", "-h"):
        print("Usage: agent-toolkit project remove <name> [--workspace PATH]")
        return 0

    name = args[0]
    projects_dir = ws / "projects"
    link_path = projects_dir / name

    if not link_path.is_symlink():
        print(f"Error: no symlink found for '{name}' in projects/", file=sys.stderr)
        return 1

    link_path.unlink()
    print(_green(f"Removed: projects/{name}"))
    print(_dim("(actual repo was not deleted)"))
    return 0


def cmd_scan(args: list[str], ws: Path) -> int:
    """Scan repos/ and projects/ for consistency issues."""
    for arg in args:
        if arg in ("--help", "-h"):
            print("Usage: agent-toolkit project scan [--workspace PATH]")
            return 0

    projects_dir = ws / "projects"
    repos_dir = ws / "repos"

    print(f"\n{_blue('=== Project Scan ===')}\n")

    # Check all symlinks in projects/
    print(f"{_cyan('Symlinks in projects/:')}")
    ok_links: set[str] = set()
    broken_links: list[str] = []

    if projects_dir.is_dir():
        for link in sorted(projects_dir.iterdir()):
            if not link.is_symlink():
                continue
            exists = link.resolve().exists()
            if exists:
                print(f"  {_green('ok')}      {link.name}")
                ok_links.add(link.name)
            else:
                target = os.readlink(str(link))
                print(f"  {_yellow('broken')}  {link.name} -> {target}")
                broken_links.append(link.name)
    else:
        print(_dim("  (projects/ directory not found)"))
    print()

    # Scan repos/ for directories not linked in projects/
    print(f"{_cyan('Repos in repos/ (symlink status):')}")
    unlinked: list[Path] = []

    if repos_dir.is_dir():
        for repo in sorted(repos_dir.rglob("*")):
            # Match repos/github.com/<owner>/<repo>/ (depth 3)
            try:
                rel_parts = repo.relative_to(repos_dir).parts
            except ValueError:
                continue
            if len(rel_parts) != 3:
                continue
            if not repo.is_dir():
                continue
            repo_name = rel_parts[2]
            if repo_name in ok_links:
                print(f"  {_green('linked')}    {'/'.join(rel_parts)}")
            else:
                print(f"  {_dim('no link')}   {'/'.join(rel_parts)}")
                unlinked.append(repo)
    else:
        print(_dim("  (repos/ directory not found)"))
    print()

    # Summary
    print(f"{_blue('── Summary ──')}")
    print(f"  Linked:    {len(ok_links)}")
    print(f"  Broken:    {len(broken_links)}")
    print(f"  Unlinked:  {len(unlinked)}")
    if broken_links:
        print()
        print(_yellow("  Run 'agent-toolkit project remove <name>' to clean up broken links."))
    if unlinked:
        print()
        print(_dim("  Run 'agent-toolkit project add <path>' to link unlinked repos."))
    print()
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def cmd_project(args: list[str]) -> int:
    """Router for project subcommands."""
    # Extract --workspace before routing
    workspace_path: str | None = None
    filtered_args: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--workspace" and i + 1 < len(args):
            workspace_path = args[i + 1]
            i += 2
        else:
            filtered_args.append(args[i])
            i += 1

    if not filtered_args or filtered_args[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0

    sub = filtered_args[0]
    rest = filtered_args[1:]

    ws = _find_workspace(workspace_path)
    if ws is None:
        print("Error: workspace not found.", file=sys.stderr)
        print("Set AGENT_TOOLKIT_WORKSPACE or run from inside a workspace directory.", file=sys.stderr)
        return 1

    match sub:
        case "init":
            return cmd_init(rest, ws)
        case "clone":
            return cmd_clone(rest, ws)
        case "list":
            return cmd_list(rest, ws)
        case "add":
            return cmd_add(rest, ws)
        case "remove":
            return cmd_remove(rest, ws)
        case "sync":
            return cmd_sync(rest, ws)
        case "scan":
            return cmd_scan(rest, ws)
        case _:
            print(f"Unknown project subcommand: {sub}", file=sys.stderr)
            print("Run 'agent-toolkit project --help' for usage.", file=sys.stderr)
            return 1
