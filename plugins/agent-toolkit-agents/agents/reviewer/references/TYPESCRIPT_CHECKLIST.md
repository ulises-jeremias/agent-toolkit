# TypeScript Review Checklist — from `typescript-reviewer` specialist (archived #865)

> **Provenance:** Migrated from `agents/typescript-reviewer/AGENT.md` (pre-865). Converted to reference per agent-vs-skill rule: procedural checklist, narrow TS capability loaded inline — `reviewer` (holistic) + `quality/deep-review` covers invocation. See `docs/AGENT_TAXONOMY.md` §3/§8 migration map.

Use when stack is TypeScript/JavaScript and deep type-safety review is warranted. Invoke via `reviewer` → `quality/deep-review` or `quality/deslop` with this checklist. Do not invoke as standalone specialist.

## When to apply
- `tsconfig.json` `strict: true` bump or new TS errors
- PR touches `types/`, `schemas/`, generics, utility types, or API boundaries
- Reviewer flags `any` / `as` / `!` / `Object` smells

## Checklist

**Type safety**
- [ ] No `any` — use `unknown` then narrow; `any` only at system boundary with comment
- [ ] No unchecked `as` assertions except API parsing; prefer type guards (`is` return)
- [ ] `strict: true` enabled; no `skipLibCheck` masking
- [ ] Discriminated unions for state vs boolean/nullable flags
- [ ] No `!` non-null assertions without control-flow proof; prefer `NonNullable<T>` or guard

**Modern patterns**
```typescript
// Discriminated union
type Result<T> = { ok: true; value: T } | { ok: false; error: Error };
// Const assertion
const ROLES = ['admin', 'user', 'guest'] as const;
type Role = typeof ROLES[number];
```

**Utility types**
- `Partial<T>`, `Required<T>`, `Readonly<T>` — structural transforms
- `Record<K,V>`, `Pick<T,K>`, `Omit<T,K>` — shape selection
- `ReturnType<T>`, `Parameters<T>` — function extraction
- `NonNullable<T>` — strip null/undefined

**Generics**
```typescript
// Good: constrained
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] { return obj[key]; }
// Bad: loses type info
function getProperty(obj: any, key: string): any { return obj[key]; }
```

**Narrowing**
- `is` guards over `as`; `in` for property checks; `instanceof` for classes; exhaustive `switch` with `never`

**Common smells**
- Missing null checks in strict mode
- Implicit `any` from untyped third-party libs
- `Object` vs `object` vs `Record<string, unknown>`

## Output
Cite `file:line`, explain why type matters, show corrected snippet. Delegated by `reviewer`; handoff to `implementer` for fix, `qa-engineer` if runtime proof needed.

## Caller / handoff
- **Caller:** `reviewer` (or `qa-engineer` for TS-heavy E2E code) via `quality/deep-review` / `quality/deslop` when stack is TS
- **Handoff:** `implementer` applies fix; `platform-engineer` if `tsc`/`build-error-resolver` diagnosis needed
