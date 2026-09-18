# Beta adapter verification snapshot (2026-09)

**Issue:** #612  
**Scope:** Codex promotion to stable; Cursor added as sole beta adapter.

## Codex (promoted to stable)

- Surfaces verified against OpenAI Codex docs: `AGENTS.md`, `.codex/config.toml` MCP, subagents, hooks, `.agents/skills/`.
- Coverage: `packages/cli/internal/adapter/codex_test.go`, adapter capabilities (`SupportStable`), ADR-009.

## Cursor (beta)

- Emits: `.cursor/skills/`, `.cursor/mcp.json`, `.cursor/hooks.json`, hook scripts under `.cursor/hooks/lazyai/`.
- Does not emit: agent profiles, `.mdc` rules.
- Coverage: `cursor_test.go`, golden `testdata/golden/cursor-only/`.
- **Pending:** maintainer manual smoke in Cursor IDE/CLI (MCP list, skill discovery, hook registration).

## EC-006

Exactly one adapter below stable: **cursor**. Enforced by `TestNoBetaAdaptersRemain` in `capabilities_test.go`.
