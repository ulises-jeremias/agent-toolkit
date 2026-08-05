"""Map Claude Code tool names to the platform-neutral AbstractTool vocabulary."""
from __future__ import annotations

from agent_toolkit.compiler.model import AbstractTool

CLAUDE_TOOL_MAP: dict[str, AbstractTool] = {
    "Read": AbstractTool.FS_READ,
    "Grep": AbstractTool.FS_SEARCH,
    "Glob": AbstractTool.FS_SEARCH,
    "Write": AbstractTool.FS_WRITE,
    "Edit": AbstractTool.FS_WRITE,
    "Bash": AbstractTool.SHELL_EXECUTE,
    "WebSearch": AbstractTool.WEB_SEARCH,
    "WebFetch": AbstractTool.WEB_FETCH,
    "Task": AbstractTool.AGENT_DELEGATE,
    "AskUserQuestion": AbstractTool.USER_ASK,
    "Git": AbstractTool.GIT_READ,
    "GitCommit": AbstractTool.GIT_WRITE,
    "GitPush": AbstractTool.GIT_WRITE,
}


def parse_claude_tool_names(tools_value: str | list[str] | None) -> list[str]:
    """Parse a frontmatter ``tools`` field into normalized Claude tool names."""
    if tools_value is None:
        return []
    if isinstance(tools_value, list):
        return [str(t).strip() for t in tools_value if str(t).strip()]
    return [t.strip() for t in str(tools_value).split(",") if t.strip()]


def map_claude_tools(
    names: list[str],
) -> tuple[list[AbstractTool], list[str]]:
    """Map Claude tool names to abstract tools.

    Returns (mapped_tools, unknown_names). Preserves order; deduplicates abstract tools.
    """
    mapped: list[AbstractTool] = []
    unknown: list[str] = []
    seen: set[AbstractTool] = set()

    for name in names:
        abstract = CLAUDE_TOOL_MAP.get(name)
        if abstract is None:
            unknown.append(name)
            continue
        if abstract not in seen:
            mapped.append(abstract)
            seen.add(abstract)

    return mapped, unknown
