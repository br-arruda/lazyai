# ADR-009: Nine-Target Compile Contract, Codex Stable, Cursor Beta

**Date:** 2026-09-17  
**Status:** Accepted — implemented in issue #612  
**Deciders:** LazyAI maintainers

> **Purpose.** Supersede the target enumeration and Codex rejection in ADR-006. The supported compile target set is nine tools; Codex is a stable adapter; Cursor is the single beta adapter (EC-006 single-beta slot).

---

## Context

After spec 029, ADR-006 froze seven compile targets and rejected Codex. The codebase later added Codex as an eighth adapter (beta) and README documented eight targets, while `lazyai.schema.json` still omitted `codex`. Issue #612 adds Cursor as a ninth target with skills, MCP, and hooks only.

Maintainers also decided to promote Codex to **stable** and assign the lone **beta** slot to Cursor until manual Cursor IDE/CLI smoke is recorded.

**Related artifacts:**

- Issue: [#612](https://github.com/rluisb/lazyai/issues/612)
- Spec: [`specs/issues/612-cursor-cli-adapter/`](../issues/612-cursor-cli-adapter/)
- Partially superseded: [`006-manifest-driven-compile-and-seven-target-contract.md`](006-manifest-driven-compile-and-seven-target-contract.md) (target set and Codex only)
- Workflow boundary unchanged: [`007-workflow-runtime-ownership.md`](007-workflow-runtime-ownership.md)

---

## Decision

1. **Supported compile targets (nine):** `opencode`, `claude`, `copilot`, `pi`, `omp`, `antigravity`, `kiro`, **`codex`**, **`cursor`**.
2. **Codex:** accepted compile target; adapter **SupportStable** (docs + unit/golden coverage; optional Codex CLI smoke in release validation).
3. **Cursor:** accepted compile target; adapter **SupportBeta**; emits `.cursor/skills/`, `.cursor/mcp.json`, `.cursor/hooks.json` + scripts; **does not** emit `.mdc` rules or custom agent profile files. Root instructions remain shared `AGENTS.md` from the scaffold.
4. **EC-006:** at most one adapter below stable; after this ADR that adapter is **cursor** only.
5. **Default manifest:** `aimanifest.Default()` keeps eight targets (includes `codex`, excludes `cursor`); Cursor is opt-in via manifest or `--tools cursor`.
6. **ADR-006 remains authoritative** for manifest + lockfile contract, binary name `lazyai-cli`, and compile idempotency model.

---

## Consequences

**Positive:**

- Code, schema, README, and ADRs align on nine targets.
- Codex promotion clears beta debt before Cursor ships.
- Single-beta policy stays test-pinned in `capabilities_test.go`.

**Negative / accepted:**

- ADR-006 historical "seven targets" text is stale; readers must follow ADR-009 for target enumeration.
- Cursor beta lacks full runtime smoke until maintainers record manual validation.

---

## Implementation Pointer

- Adapter: `packages/cli/internal/adapter/cursor.go`
- Capabilities: `packages/cli/internal/adapter/capabilities.go`
- Types: `packages/cli/internal/types/types.go` (`ToolIdCursor`)
- Schema enum: `packages/cli/internal/schema/lazyai.schema.json`
- Library assets: `packages/cli/library/cursor/`

---

## Follow-up

- Promote Cursor to stable after documented Cursor IDE/CLI smoke (update capability matrix + this ADR note).
- If a tenth target is added, supersede this ADR explicitly.
