"""
Author: RawNuke
Copyright (c) 2026 RawNuke. All rights reserved.

Context-budget analysis for Workspace Packs and Profiles.

Estimates the character and approximate token footprint of the composed
context for a pack, profile, or the full workspace. Returns warnings and
actionable suggestions when the footprint is large.

Usage (library):
    from agent_toolkit.cli.context_budget import analyze_workspace
    result = analyze_workspace(ws_root, pack_ref=None, profile_ref=None)

Token estimates are approximate (chars / 4 heuristic for English text).
No LLM or network access is needed.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

_TOKENS_PER_CHAR = 0.25

_RISK_LOW = 20_000
_RISK_MEDIUM = 40_000

_LARGE_SECTION_CHARS = 5_000


@dataclass
class SectionFootprint:
    """Measured footprint of one workspace component."""

    kind: str
    label: str
    chars: int
    estimated_tokens: int
    path: str = ""

    def to_dict(self) -> dict:
        return {
            "kind": self.kind,
            "label": self.label,
            "chars": self.chars,
            "estimated_tokens": self.estimated_tokens,
            "path": self.path,
        }


@dataclass
class BudgetResult:
    """Full result of a context-budget analysis."""

    workspace: str
    sections: list[SectionFootprint] = field(default_factory=list)
    total_chars: int = 0
    total_tokens: int = 0
    risk: str = "LOW"
    warnings: list[str] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    target: str = ""

    def to_dict(self) -> dict:
        return {
            "workspace": self.workspace,
            "target": self.target,
            "sections": [s.to_dict() for s in self.sections],
            "total_chars": self.total_chars,
            "estimated_tokens": self.total_tokens,
            "risk": self.risk,
            "warnings": self.warnings,
            "suggestions": self.suggestions,
        }


def _chars_to_tokens(chars: int) -> int:
    return int(chars * _TOKENS_PER_CHAR)


def _risk_level(tokens: int) -> str:
    if tokens >= _RISK_MEDIUM:
        return "HIGH"
    if tokens >= _RISK_LOW:
        return "MEDIUM"
    return "LOW"


def _read_safe(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


def _parse_yaml_safe(path: Path) -> dict:
    text = _read_safe(path)
    if not text:
        return {}
    try:
        import yaml

        loaded = yaml.safe_load(text)
        return loaded if isinstance(loaded, dict) else {}
    except ImportError:
        from agent_toolkit.loop.runner import _parse_simple_yaml

        return _parse_simple_yaml(text)


def _parse_frontmatter_text(content: str) -> dict:
    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    end = next((i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if end is None:
        return {}
    yaml_block = "\n".join(lines[1:end])
    try:
        import yaml

        return yaml.safe_load(yaml_block) or {}
    except ImportError:
        from agent_toolkit.loop.runner import _parse_simple_yaml

        return _parse_simple_yaml(yaml_block)


def _extract_body_text(content: str) -> str:
    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        return content
    end = next((i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if end is None:
        return content
    return "\n".join(lines[end + 1 :]).strip()


def _detect_duplicates(sections: list[SectionFootprint]) -> list[str]:
    warnings: list[str] = []
    for i, a in enumerate(sections):
        for b in sections[i + 1 :]:
            if a.kind == b.kind and a.chars > 0 and a.chars == b.chars:
                warnings.append(
                    f"Duplicate identical blocks: {a.label} and {b.label} ({a.chars} chars each)"
                )
    return warnings


def _detect_large_sections(sections: list[SectionFootprint]) -> list[str]:
    warnings: list[str] = []
    for s in sections:
        if s.chars > _LARGE_SECTION_CHARS:
            warnings.append(
                f"Large section: {s.label} ({s.chars:,} chars, ~{s.estimated_tokens:,} tokens)"
            )
    return warnings


def _skill_count_from_pack(pack_data: dict) -> int:
    skills = pack_data.get("skills") or {}
    if isinstance(skills, dict):
        return len([k for k, v in skills.items() if v.get("enabled", True)])
    return 0


def _agent_count_from_pack(pack_data: dict) -> int:
    agents = pack_data.get("agents") or {}
    if isinstance(agents, dict):
        return len([k for k, v in agents.items() if v.get("enabled", True)])
    return 0


def analyze_workspace(
    ws_root: Path,
    pack_ref: str | None = None,
    profile_ref: str | None = None,
) -> BudgetResult:
    result = BudgetResult(workspace=str(ws_root))

    if pack_ref:
        pack_path = _resolve_pack_path(ws_root, pack_ref)
        if pack_path is None:
            result.warnings.append(f"Pack not found: {pack_ref}")
            return result
        result.target = f"pack:{pack_ref}"
        _analyze_pack(ws_root, pack_path, result)
    elif profile_ref:
        result.target = f"profile:{profile_ref}"
        _analyze_profile(ws_root, profile_ref, result)
    else:
        result.target = "workspace"
        _analyze_full_workspace(ws_root, result)

    result.total_chars = sum(s.chars for s in result.sections)
    result.total_tokens = _chars_to_tokens(result.total_chars)
    result.risk = _risk_level(result.total_tokens)

    dupe_warnings = _detect_duplicates(result.sections)
    large_warnings = _detect_large_sections(result.sections)
    _build_suggestions(result)

    result.warnings.extend(dupe_warnings)
    result.warnings.extend(large_warnings)

    skill_count = 0
    agent_count = 0
    for s in result.sections:
        if hasattr(s, "skill_count"):
            skill_count += s.skill_count if hasattr(s, "skill_count") else 0
            agent_count += s.agent_count if hasattr(s, "agent_count") else 0

    return result


def _resolve_pack_path(ws_root: Path, pack_arg: str) -> Path | None:
    candidate = Path(pack_arg)
    if candidate.is_absolute():
        return candidate if candidate.is_file() else None
    for rel in (pack_arg, f"packs/{pack_arg}", f"packs/{pack_arg}.yaml"):
        path = ws_root / rel
        if path.is_file():
            return path
    return None


def _resolve_profile_path(ws_root: Path, profile_name: str) -> Path | None:
    for rel in (f"profiles/{profile_name}.yaml", f"profiles/{profile_name}"):
        path = ws_root / rel
        if path.is_file():
            return path
    return None


def _analyze_pack(ws_root: Path, pack_path: Path, result: BudgetResult) -> None:
    data = _parse_yaml_safe(pack_path)
    text = _read_safe(pack_path)
    tokens = _chars_to_tokens(len(text))
    result.sections.append(
        SectionFootprint(
            kind="pack_yaml",
            label=f"pack:{pack_path.name}",
            chars=len(text),
            estimated_tokens=tokens,
            path=str(pack_path),
        )
    )

    name = data.get("name") or pack_path.stem
    description = data.get("description", "")
    notes = data.get("notes", "")
    if description:
        result.sections.append(
            SectionFootprint(
                kind="pack_description",
                label=f"pack:{name} description",
                chars=len(description),
                estimated_tokens=_chars_to_tokens(len(description)),
                path=str(pack_path),
            )
        )
    if isinstance(notes, str) and notes.strip():
        result.sections.append(
            SectionFootprint(
                kind="pack_notes",
                label=f"pack:{name} notes",
                chars=len(notes),
                estimated_tokens=_chars_to_tokens(len(notes)),
                path=str(pack_path),
            )
        )

    skills = data.get("skills") or {}
    if isinstance(skills, dict):
        enabled_skills = [k for k, v in skills.items() if v.get("enabled", True)]
        if enabled_skills:
            result.sections.append(
                SectionFootprint(
                    kind="pack_skills",
                    label=f"pack:{name} skills",
                    chars=len(str(enabled_skills)),
                    estimated_tokens=0,
                    path=str(pack_path),
                )
            )

    agents = data.get("agents") or {}
    if isinstance(agents, dict):
        enabled_agents = [k for k, v in agents.items() if v.get("enabled", True)]
        if enabled_agents:
            result.sections.append(
                SectionFootprint(
                    kind="pack_agents",
                    label=f"pack:{name} agents",
                    chars=len(str(enabled_agents)),
                    estimated_tokens=0,
                    path=str(pack_path),
                )
            )

    referenced_pack = data.get("pack")
    if isinstance(referenced_pack, str):
        resolved = _resolve_pack_path(ws_root, referenced_pack)
        if resolved and resolved != pack_path:
            _analyze_pack(ws_root, resolved, result)

    persona_name = data.get("persona")
    if isinstance(persona_name, str):
        persona_path = ws_root / "personas" / f"{persona_name}.md"
        if persona_path.is_file():
            _analyze_persona(ws_root, persona_name, result)


def _analyze_profile(ws_root: Path, profile_name: str, result: BudgetResult) -> None:
    profile_path = _resolve_profile_path(ws_root, profile_name)
    if profile_path is None:
        result.warnings.append(f"Profile not found: {profile_name}")
        return

    data = _parse_yaml_safe(profile_path)
    text = _read_safe(profile_path)
    result.sections.append(
        SectionFootprint(
            kind="profile_yaml",
            label=f"profile:{profile_name}",
            chars=len(text),
            estimated_tokens=_chars_to_tokens(len(text)),
            path=str(profile_path),
        )
    )

    pack_ref = data.get("pack")
    if isinstance(pack_ref, str):
        pack_path = _resolve_pack_path(ws_root, pack_ref)
        if pack_path:
            _analyze_pack(ws_root, pack_path, result)
        else:
            result.warnings.append(f"Referenced pack not found: {pack_ref}")

    persona_name = data.get("persona")
    if isinstance(persona_name, str):
        _analyze_persona(ws_root, persona_name, result)


def _analyze_persona(ws_root: Path, persona_name: str, result: BudgetResult) -> None:
    persona_path = ws_root / "personas" / f"{persona_name}.md"
    if not persona_path.is_file():
        result.warnings.append(f"Persona not found: {persona_name}")
        return

    content = _read_safe(persona_path)
    frontmatter = _parse_frontmatter_text(content)
    body = _extract_body_text(content)

    result.sections.append(
        SectionFootprint(
            kind="persona_frontmatter",
            label=f"persona:{persona_name} constraints",
            chars=len(str(frontmatter)),
            estimated_tokens=_chars_to_tokens(len(str(frontmatter))),
            path=str(persona_path),
        )
    )

    if body:
        result.sections.append(
            SectionFootprint(
                kind="persona_body",
                label=f"persona:{persona_name} instructions",
                chars=len(body),
                estimated_tokens=_chars_to_tokens(len(body)),
                path=str(persona_path),
            )
        )


def _analyze_full_workspace(ws_root: Path, result: BudgetResult) -> None:
    agents_md = ws_root / "AGENTS.md"
    if agents_md.is_file():
        content = _read_safe(agents_md)
        result.sections.append(
            SectionFootprint(
                kind="agents_md",
                label="AGENTS.md",
                chars=len(content),
                estimated_tokens=_chars_to_tokens(len(content)),
                path=str(agents_md),
            )
        )

    packs_dir = ws_root / "packs"
    if packs_dir.is_dir():
        for yaml_file in sorted(packs_dir.glob("*.yaml")):
            _analyze_pack(ws_root, yaml_file, result)

    profiles_dir = ws_root / "profiles"
    if profiles_dir.is_dir():
        for yaml_file in sorted(profiles_dir.glob("*.yaml")):
            profile_data = _parse_yaml_safe(yaml_file)
            profile_name = profile_data.get("name") or yaml_file.stem
            text = _read_safe(yaml_file)
            result.sections.append(
                SectionFootprint(
                    kind="profile_yaml",
                    label=f"profile:{profile_name}",
                    chars=len(text),
                    estimated_tokens=_chars_to_tokens(len(text)),
                    path=str(yaml_file),
                )
            )

            pack_ref = profile_data.get("pack")
            if isinstance(pack_ref, str):
                pack_path = _resolve_pack_path(ws_root, pack_ref)
                if pack_path:
                    _analyze_pack(ws_root, pack_path, result)

            persona_name = profile_data.get("persona")
            if isinstance(persona_name, str):
                _analyze_persona(ws_root, persona_name, result)

    personas_dir = ws_root / "personas"
    if personas_dir.is_dir():
        for md_file in sorted(personas_dir.glob("*.md")):
            persona_name = md_file.stem
            _analyze_persona(ws_root, persona_name, result)


def _build_suggestions(result: BudgetResult) -> None:
    skill_sections = [s for s in result.sections if s.kind == "pack_skills"]
    agent_sections = [s for s in result.sections if s.kind == "pack_agents"]
    large_instruction = [
        s
        for s in result.sections
        if s.kind in ("persona_body", "pack_notes") and s.chars > _LARGE_SECTION_CHARS
    ]
    persona_count = len({s.path for s in result.sections if s.kind == "persona_body"})

    if skill_sections:
        result.suggestions.append("Consider reducing the number of enabled skills per pack.")
    if agent_sections:
        result.suggestions.append("Consider reducing the number of enabled agents per pack.")
    if large_instruction:
        result.suggestions.append(
            "Split large instruction sections into optional referenced files."
        )
    if persona_count > 2:
        result.suggestions.append(
            "Prefer a narrower profile set; more than 2 personas increases context footprint."
        )
    if result.total_tokens >= _RISK_MEDIUM:
        result.suggestions.append(
            "Split the pack into smaller, focused packs for different scenarios."
        )
