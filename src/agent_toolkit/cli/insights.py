"""
insights — AI tool usage insights for agent-toolkit.

Usage:
    agent-toolkit insights opencode [--days N] [--output PATH]
    agent-toolkit insights cursor [--output PATH]
    agent-toolkit insights claude [--days N] [--output PATH]

Subcommands:
    opencode    Analyse OpenCode sessions from ~/.local/share/opencode/opencode.db
    cursor      Analyse Cursor agent transcripts from ~/.cursor/projects/
    claude      Analyse Claude Code usage from ~/.claude/usage-data/ JSONL files
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import sys as _sys
if _sys.platform == 'win32':
    try:
        _sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        _sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

OPENCODE_DB     = Path.home() / ".local" / "share" / "opencode" / "opencode.db"
CURSOR_PROJECTS = Path.home() / ".cursor" / "projects"
CLAUDE_USAGE    = Path.home() / ".claude" / "usage-data"


# ── colors ────────────────────────────────────────────────────────────────────

_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def _blue(t: str) -> str:  return _c("1;34", t)
def _cyan(t: str) -> str:  return _c("0;36", t)
def _green(t: str) -> str: return _c("1;32", t)


# ── OpenCode ──────────────────────────────────────────────────────────────────

def _opencode_stats(db_path: Path, days: int | None = None) -> dict:
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    where = ""
    if days:
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
        where = f"AND datetime(time_created/1000,'unixepoch') >= '{cutoff}'"

    cur.execute(f"""
        SELECT
            COUNT(*) total_sessions,
            COALESCE(SUM(cost), 0) total_cost,
            COALESCE(SUM(tokens_input), 0) total_tokens_in,
            COALESCE(SUM(tokens_output), 0) total_tokens_out,
            MIN(datetime(time_created/1000,'unixepoch')) first_session,
            MAX(datetime(time_updated/1000,'unixepoch')) last_session
        FROM session
        WHERE time_archived IS NULL {where}
    """)
    agg = dict(cur.fetchone())

    cur.execute(f"""
        SELECT
            COALESCE(json_extract(model,'$.id'), 'unknown') model_id,
            COALESCE(json_extract(model,'$.providerID'), 'unknown') provider,
            COUNT(*) sessions,
            COALESCE(SUM(cost), 0) cost,
            COALESCE(SUM(tokens_input) + SUM(tokens_output), 0) tokens
        FROM session
        WHERE time_archived IS NULL {where}
        GROUP BY model_id
        ORDER BY sessions DESC
        LIMIT 10
    """)
    agg["by_model"] = [dict(r) for r in cur.fetchall()]

    # Home dir replacement for directory paths
    home = str(Path.home())
    cur.execute(f"""
        SELECT
            REPLACE(directory, '{home}', '~') as dir,
            COUNT(*) sessions,
            COALESCE(SUM(cost), 0) cost,
            COALESCE(SUM(tokens_input) + SUM(tokens_output), 0) tokens
        FROM session
        WHERE time_archived IS NULL {where}
        GROUP BY directory
        ORDER BY sessions DESC
        LIMIT 10
    """)
    agg["by_directory"] = [dict(r) for r in cur.fetchall()]

    # Recent sessions (last 10 titles)
    cur.execute(f"""
        SELECT title, datetime(time_created/1000,'unixepoch') created
        FROM session
        WHERE time_archived IS NULL {where}
        ORDER BY time_created DESC
        LIMIT 10
    """)
    agg["recent_sessions"] = [dict(r) for r in cur.fetchall()]

    con.close()
    return agg


def _opencode_markdown(stats: dict, days: int | None) -> str:
    period = f"last {days} days" if days else "all time"
    total_tokens = (stats.get("total_tokens_in") or 0) + (stats.get("total_tokens_out") or 0)
    lines = [
        f"# OpenCode Usage Insights ({period})",
        "",
        "## Stats",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Sessions | {stats.get('total_sessions', 0):,} |",
        f"| Total Cost | ${stats.get('total_cost', 0):,.4f} |",
        f"| Total Tokens | {total_tokens:,} |",
        f"| Tokens In | {stats.get('total_tokens_in', 0):,} |",
        f"| Tokens Out | {stats.get('total_tokens_out', 0):,} |",
        f"| Date Range | {stats.get('first_session', 'N/A')[:10]} → {stats.get('last_session', 'N/A')[:10]} |",
        "",
    ]

    by_dir = stats.get("by_directory", [])
    if by_dir:
        lines += [
            "## Top 5 Directories by Session Count",
            "",
            "| Directory | Sessions | Cost |",
            "|-----------|----------|------|",
        ]
        for row in by_dir[:5]:
            lines.append(f"| `{row['dir']}` | {row['sessions']} | ${row.get('cost', 0):,.4f} |")
        lines.append("")

    by_model = stats.get("by_model", [])
    if by_model:
        lines += [
            "## Top 5 Models by Usage",
            "",
            "| Model | Provider | Sessions | Tokens |",
            "|-------|----------|----------|--------|",
        ]
        for row in by_model[:5]:
            lines.append(
                f"| `{row['model_id']}` | {row['provider']} | {row['sessions']} | {row.get('tokens', 0):,} |"
            )
        lines.append("")

    recent = stats.get("recent_sessions", [])
    if recent:
        lines += ["## Recent Sessions (last 10)", ""]
        for s in recent:
            title   = (s.get("title") or "(untitled)")[:80]
            created = (s.get("created") or "")[:10]
            lines.append(f"- {created}  {title}")
        lines.append("")

    return "\n".join(lines)


def _opencode_html(stats: dict, days: int | None) -> str:
    period = f"last {days} days" if days else "all time"
    total_tokens = (stats.get("total_tokens_in") or 0) + (stats.get("total_tokens_out") or 0)
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M")

    def _th(*cols: str) -> str:
        return "<tr>" + "".join(f"<th>{c}</th>" for c in cols) + "</tr>"

    def _tr(*cols: str) -> str:
        return "<tr>" + "".join(f"<td>{c}</td>" for c in cols) + "</tr>"

    stats_rows = "".join([
        _tr("Sessions",     f"{stats.get('total_sessions', 0):,}"),
        _tr("Total Cost",   f"${stats.get('total_cost', 0):,.4f}"),
        _tr("Total Tokens", f"{total_tokens:,}"),
        _tr("Tokens In",    f"{stats.get('total_tokens_in', 0):,}"),
        _tr("Tokens Out",   f"{stats.get('total_tokens_out', 0):,}"),
        _tr("Date Range",   f"{stats.get('first_session','N/A')[:10]} &rarr; {stats.get('last_session','N/A')[:10]}"),
    ])

    dir_rows = ""
    for row in (stats.get("by_directory") or [])[:5]:
        dir_rows += _tr(f"<code>{row['dir']}</code>", str(row["sessions"]), f"${row.get('cost', 0):,.4f}")

    model_rows = ""
    for row in (stats.get("by_model") or [])[:5]:
        model_rows += _tr(
            f"<code>{row['model_id']}</code>",
            row["provider"],
            str(row["sessions"]),
            f"{row.get('tokens', 0):,}",
        )

    recent_items = ""
    for s in (stats.get("recent_sessions") or []):
        title   = (s.get("title") or "(untitled)")[:80]
        created = (s.get("created") or "")[:10]
        recent_items += f"<li><span class='date'>{created}</span> {title}</li>"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>OpenCode Usage Insights</title>
<style>
  :root {{
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #e6edf3; --muted: #8b949e; --accent: #58a6ff; --green: #3fb950;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text);
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', monospace;
          line-height: 1.6; padding: 2rem 1rem; }}
  .container {{ max-width: 860px; margin: 0 auto; }}
  h1 {{ font-size: 1.8rem; margin-bottom: 0.25rem; }}
  h2 {{ font-size: 1.2rem; color: var(--accent); margin: 2rem 0 1rem;
        border-bottom: 1px solid var(--border); padding-bottom: 0.5rem; }}
  .subtitle {{ color: var(--muted); font-size: 0.9rem; margin-bottom: 2rem; }}
  table {{ width: 100%; border-collapse: collapse; margin-bottom: 1.5rem; }}
  th {{ text-align: left; padding: 0.5rem 0.75rem; color: var(--muted);
        font-size: 0.85rem; border-bottom: 1px solid var(--border); }}
  td {{ padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border);
        font-size: 0.9rem; }}
  code {{ background: #1f2937; padding: 0.1rem 0.35rem; border-radius: 4px; font-size: 0.82rem; }}
  ul {{ list-style: none; padding: 0; }}
  li {{ padding: 0.35rem 0; border-bottom: 1px solid var(--border); font-size: 0.9rem; }}
  .date {{ color: var(--muted); margin-right: 0.75rem; font-size: 0.82rem; }}
</style>
</head>
<body>
<div class="container">
  <h1>OpenCode Usage Insights</h1>
  <p class="subtitle">Period: {period} &mdash; Generated {generated_at}</p>

  <h2>Stats</h2>
  <table><thead>{_th("Metric", "Value")}</thead><tbody>{stats_rows}</tbody></table>

  <h2>Top 5 Directories</h2>
  <table><thead>{_th("Directory", "Sessions", "Cost")}</thead><tbody>{dir_rows or "<tr><td colspan='3'>No data</td></tr>"}</tbody></table>

  <h2>Top 5 Models</h2>
  <table><thead>{_th("Model", "Provider", "Sessions", "Tokens")}</thead><tbody>{model_rows or "<tr><td colspan='4'>No data</td></tr>"}</tbody></table>

  <h2>Recent Sessions</h2>
  <ul>{recent_items or "<li>No recent sessions</li>"}</ul>
</div>
</body>
</html>"""


def _sub_opencode(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit insights opencode", add_help=True)
    p.add_argument("--days",   type=int, default=None, help="Limit to last N days")
    p.add_argument("--output", metavar="PATH",         help="Save HTML report to PATH")
    args = p.parse_args(argv)

    if not OPENCODE_DB.exists():
        print(f"OpenCode database not found: {OPENCODE_DB}", file=sys.stderr)
        return 1

    try:
        stats = _opencode_stats(OPENCODE_DB, args.days)
    except Exception as exc:
        print(f"Error reading OpenCode database: {exc}", file=sys.stderr)
        return 1

    if args.output:
        html = _opencode_html(stats, args.days)
        out_path = Path(args.output)
        out_path.write_text(html, encoding="utf-8")
        print(f"HTML report saved to: {out_path}")
    else:
        print(_opencode_markdown(stats, args.days))

    return 0


# ── Cursor ────────────────────────────────────────────────────────────────────

def _cursor_stats(projects_dir: Path) -> dict:
    project_counts: dict[str, int] = {}
    sample_tasks: list[dict] = []

    if not projects_dir.is_dir():
        return {"total_transcripts": 0, "total_projects": 0, "by_project": {}, "recent_tasks": []}

    for project_dir in sorted(projects_dir.iterdir()):
        transcripts_dir = project_dir / "agent-transcripts"
        if not transcripts_dir.exists():
            continue
        project_name = project_dir.name
        jsonl_files = sorted(
            transcripts_dir.rglob("*.jsonl"),
            key=lambda f: f.stat().st_mtime,
            reverse=True,
        )
        project_counts[project_name] = len(jsonl_files)

        # Sample task descriptions from recent files
        for jf in jsonl_files[:3]:
            try:
                lines = jf.read_text(errors="replace").splitlines()
                descriptions: list[str] = []
                for line in lines:
                    try:
                        obj = json.loads(line)
                        role = obj.get("role") or (obj.get("message") or {}).get("role")
                        if role == "user":
                            content = obj.get("message", {}).get("content", [])
                            for part in content:
                                if isinstance(part, dict) and part.get("type") == "text":
                                    txt = part.get("text", "")
                                    txt = re.sub(r"<timestamp>[^<]*</timestamp>", "", txt).strip()
                                    uq = re.search(r"<user_query>(.*?)</user_query>", txt, re.DOTALL)
                                    if uq:
                                        txt = uq.group(1).strip()
                                    if txt:
                                        descriptions.append(txt[:120])
                                        break
                    except Exception:
                        continue
                    if descriptions:
                        break
                if descriptions:
                    sample_tasks.append({
                        "project": project_name,
                        "description": descriptions[0],
                        "mtime": datetime.fromtimestamp(jf.stat().st_mtime).strftime("%Y-%m-%d"),
                    })
            except Exception:
                continue

    # Sort by count desc
    by_project = dict(sorted(project_counts.items(), key=lambda x: -x[1]))
    total = sum(project_counts.values())

    # Sort tasks by recency (approximate via project order)
    sample_tasks.sort(key=lambda t: t["mtime"], reverse=True)

    return {
        "total_transcripts": total,
        "total_projects":    len(project_counts),
        "by_project":        by_project,
        "recent_tasks":      sample_tasks[:20],
    }


def _cursor_markdown(stats: dict) -> str:
    lines = [
        "# Cursor Usage Insights",
        "",
        "## Stats",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Total Transcripts | {stats.get('total_transcripts', 0):,} |",
        f"| Projects | {stats.get('total_projects', 0):,} |",
        "",
    ]

    by_project = stats.get("by_project", {})
    if by_project:
        lines += [
            "## Top Projects by Transcript Count",
            "",
            "| Project | Transcripts |",
            "|---------|-------------|",
        ]
        for name, count in list(by_project.items())[:10]:
            lines.append(f"| `{name}` | {count} |")
        lines.append("")

    recent = stats.get("recent_tasks", [])
    if recent:
        lines += ["## Recent Tasks (sampled)", ""]
        for t in recent[:10]:
            lines.append(f"- {t['mtime']}  [{t['project']}]  {t['description']}")
        lines.append("")

    return "\n".join(lines)


def _cursor_html(stats: dict) -> str:
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M")

    def _tr(*cols: str) -> str:
        return "<tr>" + "".join(f"<td>{c}</td>" for c in cols) + "</tr>"

    def _th(*cols: str) -> str:
        return "<tr>" + "".join(f"<th>{c}</th>" for c in cols) + "</tr>"

    stats_rows = "".join([
        _tr("Total Transcripts", f"{stats.get('total_transcripts', 0):,}"),
        _tr("Projects",          f"{stats.get('total_projects', 0):,}"),
    ])

    project_rows = ""
    for name, count in list((stats.get("by_project") or {}).items())[:10]:
        project_rows += _tr(f"<code>{name}</code>", str(count))

    task_items = ""
    for t in (stats.get("recent_tasks") or [])[:10]:
        task_items += f"<li><span class='date'>{t['mtime']}</span> <span class='proj'>[{t['project']}]</span> {t['description']}</li>"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Cursor Usage Insights</title>
<style>
  :root {{
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #e6edf3; --muted: #8b949e; --accent: #58a6ff;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text);
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', monospace;
          line-height: 1.6; padding: 2rem 1rem; }}
  .container {{ max-width: 860px; margin: 0 auto; }}
  h1 {{ font-size: 1.8rem; margin-bottom: 0.25rem; }}
  h2 {{ font-size: 1.2rem; color: var(--accent); margin: 2rem 0 1rem;
        border-bottom: 1px solid var(--border); padding-bottom: 0.5rem; }}
  .subtitle {{ color: var(--muted); font-size: 0.9rem; margin-bottom: 2rem; }}
  table {{ width: 100%; border-collapse: collapse; margin-bottom: 1.5rem; }}
  th {{ text-align: left; padding: 0.5rem 0.75rem; color: var(--muted);
        font-size: 0.85rem; border-bottom: 1px solid var(--border); }}
  td {{ padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border); font-size: 0.9rem; }}
  code {{ background: #1f2937; padding: 0.1rem 0.35rem; border-radius: 4px; font-size: 0.82rem; }}
  ul {{ list-style: none; padding: 0; }}
  li {{ padding: 0.35rem 0; border-bottom: 1px solid var(--border); font-size: 0.9rem; }}
  .date {{ color: var(--muted); margin-right: 0.5rem; font-size: 0.82rem; }}
  .proj {{ color: var(--accent); margin-right: 0.5rem; font-size: 0.82rem; }}
</style>
</head>
<body>
<div class="container">
  <h1>Cursor Usage Insights</h1>
  <p class="subtitle">Generated {generated_at}</p>

  <h2>Stats</h2>
  <table><thead>{_th("Metric", "Value")}</thead><tbody>{stats_rows}</tbody></table>

  <h2>Top Projects</h2>
  <table><thead>{_th("Project", "Transcripts")}</thead><tbody>{project_rows or "<tr><td colspan='2'>No data</td></tr>"}</tbody></table>

  <h2>Recent Tasks</h2>
  <ul>{task_items or "<li>No tasks found</li>"}</ul>
</div>
</body>
</html>"""


def _sub_cursor(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit insights cursor", add_help=True)
    p.add_argument("--output", metavar="PATH", help="Save HTML report to PATH")
    args = p.parse_args(argv)

    if not CURSOR_PROJECTS.exists():
        print(f"Cursor projects directory not found: {CURSOR_PROJECTS}", file=sys.stderr)
        print("No Cursor data available.", file=sys.stderr)
        return 1

    stats = _cursor_stats(CURSOR_PROJECTS)

    if args.output:
        html = _cursor_html(stats)
        out_path = Path(args.output)
        out_path.write_text(html, encoding="utf-8")
        print(f"HTML report saved to: {out_path}")
    else:
        print(_cursor_markdown(stats))

    return 0


# ── Claude Code ───────────────────────────────────────────────────────────────

def _claude_stats(usage_dir: Path, days: int | None = None) -> dict:
    if not usage_dir.is_dir():
        return {}

    cutoff: datetime | None = None
    if days:
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    total_sessions = 0
    total_messages = 0
    total_tool_calls = 0
    first_ts: str | None = None
    last_ts:  str | None = None
    jsonl_files = sorted(usage_dir.rglob("*.jsonl"), key=lambda f: f.stat().st_mtime)

    for jf in jsonl_files:
        try:
            for line in jf.read_text(errors="replace").splitlines():
                if not line.strip():
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue

                ts = obj.get("timestamp") or obj.get("created_at") or obj.get("time")
                if ts and cutoff:
                    try:
                        # Parse ISO timestamp
                        ts_dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                        if ts_dt < cutoff:
                            continue
                    except Exception:
                        pass

                # Count events
                event_type = obj.get("type") or obj.get("event")
                if event_type in ("session_start", "session"):
                    total_sessions += 1
                    if ts:
                        if first_ts is None or ts < first_ts:
                            first_ts = ts
                        if last_ts is None or ts > last_ts:
                            last_ts = ts

                if event_type in ("message", "assistant_message", "human_message"):
                    total_messages += 1

                # Tool calls are often nested
                tool_uses = obj.get("tool_uses") or []
                if isinstance(tool_uses, list):
                    total_tool_calls += len(tool_uses)

                content = obj.get("content") or []
                if isinstance(content, list):
                    total_tool_calls += sum(
                        1 for c in content
                        if isinstance(c, dict) and c.get("type") == "tool_use"
                    )

        except Exception:
            continue

    return {
        "total_sessions":   total_sessions,
        "total_messages":   total_messages,
        "total_tool_calls": total_tool_calls,
        "first_session":    (first_ts or "")[:10],
        "last_session":     (last_ts or "")[:10],
        "files_scanned":    len(jsonl_files),
        "note": (
            "Claude Code usage data is limited without the /insights skill. "
            "Counts reflect what is available in JSONL files."
        ),
    }


def _claude_markdown(stats: dict, days: int | None) -> str:
    period = f"last {days} days" if days else "all time"
    lines = [
        f"# Claude Code Usage Insights ({period})",
        "",
        "## Stats",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Sessions | {stats.get('total_sessions', 0):,} |",
        f"| Messages | {stats.get('total_messages', 0):,} |",
        f"| Tool Calls | {stats.get('total_tool_calls', 0):,} |",
        f"| Date Range | {stats.get('first_session', 'N/A')} → {stats.get('last_session', 'N/A')} |",
        f"| JSONL Files Scanned | {stats.get('files_scanned', 0)} |",
        "",
        f"> **Note:** {stats.get('note', '')}",
        "",
    ]
    return "\n".join(lines)


def _claude_html(stats: dict, days: int | None) -> str:
    period = f"last {days} days" if days else "all time"
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M")

    def _tr(*cols: str) -> str:
        return "<tr>" + "".join(f"<td>{c}</td>" for c in cols) + "</tr>"

    def _th(*cols: str) -> str:
        return "<tr>" + "".join(f"<th>{c}</th>" for c in cols) + "</tr>"

    rows = "".join([
        _tr("Sessions",           f"{stats.get('total_sessions', 0):,}"),
        _tr("Messages",           f"{stats.get('total_messages', 0):,}"),
        _tr("Tool Calls",         f"{stats.get('total_tool_calls', 0):,}"),
        _tr("Date Range",         f"{stats.get('first_session','N/A')} &rarr; {stats.get('last_session','N/A')}"),
        _tr("JSONL Files Scanned", str(stats.get("files_scanned", 0))),
    ])

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude Code Usage Insights</title>
<style>
  :root {{
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #e6edf3; --muted: #8b949e; --accent: #58a6ff;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text);
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', monospace;
          line-height: 1.6; padding: 2rem 1rem; }}
  .container {{ max-width: 860px; margin: 0 auto; }}
  h1 {{ font-size: 1.8rem; margin-bottom: 0.25rem; }}
  h2 {{ font-size: 1.2rem; color: var(--accent); margin: 2rem 0 1rem;
        border-bottom: 1px solid var(--border); padding-bottom: 0.5rem; }}
  .subtitle {{ color: var(--muted); font-size: 0.9rem; margin-bottom: 2rem; }}
  .note {{ background: #1c2128; border-left: 3px solid var(--accent);
           padding: 0.75rem 1rem; margin-top: 1rem; color: var(--muted);
           font-size: 0.88rem; border-radius: 0 4px 4px 0; }}
  table {{ width: 100%; border-collapse: collapse; margin-bottom: 1.5rem; }}
  th {{ text-align: left; padding: 0.5rem 0.75rem; color: var(--muted);
        font-size: 0.85rem; border-bottom: 1px solid var(--border); }}
  td {{ padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border); font-size: 0.9rem; }}
</style>
</head>
<body>
<div class="container">
  <h1>Claude Code Usage Insights</h1>
  <p class="subtitle">Period: {period} &mdash; Generated {generated_at}</p>

  <h2>Stats</h2>
  <table><thead>{_th("Metric", "Value")}</thead><tbody>{rows}</tbody></table>

  <div class="note">{stats.get('note', '')}</div>
</div>
</body>
</html>"""


def _sub_claude(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit insights claude", add_help=True)
    p.add_argument("--days",   type=int, default=None, help="Limit to last N days")
    p.add_argument("--output", metavar="PATH",         help="Save HTML report to PATH")
    args = p.parse_args(argv)

    if not CLAUDE_USAGE.exists():
        print(f"Claude usage data not found: {CLAUDE_USAGE}", file=sys.stderr)
        print("Limited data available without the /insights skill.", file=sys.stderr)
        return 1

    stats = _claude_stats(CLAUDE_USAGE, args.days)

    if args.output:
        html = _claude_html(stats, args.days)
        out_path = Path(args.output)
        out_path.write_text(html, encoding="utf-8")
        print(f"HTML report saved to: {out_path}")
    else:
        print(_claude_markdown(stats, args.days))

    return 0


# ── help ─────────────────────────────────────────────────────────────────────

def _sub_help(_argv: list[str]) -> int:
    print(f"""
{_blue('agent-toolkit insights')} — AI tool usage insights

{_cyan('Usage:')}
  agent-toolkit insights opencode [--days N] [--output PATH]
  agent-toolkit insights cursor   [--output PATH]
  agent-toolkit insights claude   [--days N] [--output PATH]

{_cyan('Subcommands:')}
  opencode   Analyse OpenCode sessions from ~/.local/share/opencode/opencode.db
  cursor     Analyse Cursor agent transcripts from ~/.cursor/projects/
  claude     Analyse Claude Code usage from ~/.claude/usage-data/ JSONL files

{_cyan('Options:')}
  --days N       Limit analysis to last N days (opencode, claude)
  --output PATH  Save HTML report to PATH (all subcommands)
                 Without --output: prints Markdown to stdout

{_cyan('Examples:')}
  agent-toolkit insights opencode
  agent-toolkit insights opencode --days 30
  agent-toolkit insights opencode --output ~/opencode-report.html
  agent-toolkit insights cursor   --output ~/cursor-report.html
  agent-toolkit insights claude   --days 7
""")
    return 0


# ── entry point ───────────────────────────────────────────────────────────────

def cmd_insights(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help", "help"):
        return _sub_help([])

    subcommand = argv[0]
    rest = argv[1:]

    dispatch = {
        "opencode": _sub_opencode,
        "cursor":   _sub_cursor,
        "claude":   _sub_claude,
        "help":     _sub_help,
    }

    fn = dispatch.get(subcommand)
    if fn is None:
        print(f"Unknown subcommand: {subcommand}", file=sys.stderr)
        print("Run 'agent-toolkit insights help' for usage.", file=sys.stderr)
        return 1

    return fn(rest)
