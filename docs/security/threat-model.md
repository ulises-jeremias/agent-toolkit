# Threat Model — agent-toolkit

**Version:** 1.0  **Date:** 2026-08-04

## Trust Boundaries

```
[User] ──owns──> [AI Tool] ──loads──> [agent-toolkit plugin]
                                              │
                                    ┌─────────┴──────────┐
                                    │   Trust boundary:   │
                                    │   plugin contents   │
                                    │   must be safe to   │
                                    │   load by default   │
                                    └─────────────────────┘
```

## Asset Classification

| Asset | Sensitivity | Protection |
|-------|-------------|------------|
| Skill instructions | Public | Open repo |
| Agent personas | Public | Open repo |
| User API keys | Secret | Never in repo |
| MCP server URLs | Config | ${ENV_VAR} only |
| Hook scripts | Trusted | Reviewed in repo |
| Installation receipts | Internal | No secrets |

## Threat Categories

### T1: Credential exposure
- **Threat:** API keys, tokens, private URLs committed to repo
- **Controls:** Gitleaks scanning, .gitleaks.toml, opencode.json template-only
- **Status:** DEFECT-002 fixed (removed private URLs from opencode.json)

### T2: Permission bypass
- **Threat:** Plugin ships dangerous defaults that bypass user consent
- **Controls:** Remove all `skipDangerousModePermissionPrompt` from distributed files
- **Status:** DEFECT-001 fixed

### T3: Hook injection
- **Threat:** Hook scripts execute attacker-controlled input unsafely
- **Controls:** Hook scripts must use structured JSON stdin, no `eval`, no interpolation
- **Status:** No hooks shipped yet; controls in place when added

### T4: Path traversal
- **Threat:** Generated artifacts escape the repository boundary
- **Controls:** Compiler validates all output paths; no `..` in generated paths
- **Status:** Compiler validates output root

### T5: Supply chain
- **Threat:** Malicious code introduced via dependencies or compromised source
- **Controls:** Pinned deps, SBOM, Gitleaks, Trivy, minimal dep surface

## Security Controls Summary

- ✅ No secrets in source files
- ✅ No private hostnames  
- ✅ No dangerous permission bypass defaults
- ✅ No automatic permission approval
- ✅ No external HTTP hooks by default
- ✅ MCP uses ${ENV_VAR} for credentials
- ✅ Secret scanning in CI (Gitleaks)
- ✅ Dependency scanning in CI (Trivy)
