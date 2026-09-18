# Research: Cursor CLI / IDE adapter (skills, MCP, hooks)

**Issue:** #612  
**Date:** 2026-09-17  
**Status:** research-complete (docs-sourced; runtime smoke pending)  
**Delivery:** Single PR (spec + implementation)

---

## Problem Statement

LazyAI compiles canonical `.ai/` sources into eight native targets (`opencode`, `claude-code`, `copilot`, `pi`, `omp`, `kiro`, `antigravity`, `codex`). **Cursor is not a compile target.** Users who run Cursor alongside other tools must maintain `.cursor/*` manually or rely on duplicated outputs from other adapters (e.g. Codex writing `.agents/skills/` that Cursor also reads).

The product goal for this work is **intersection-only coverage**: skills, MCP, and lifecycle hooks—the same conceptual surfaces LazyAI already unifies elsewhere—without emitting Cursor-only concepts (`.mdc` rules, steering-like files) or faking agent profiles where Cursor has no native equivalent.

---

## Current LazyAI State (repo evidence)

| Area | Cursor today |
|---|---|
| `SupportedToolIDs` | Absent — `packages/cli/internal/types/types.go` |
| Adapter registry | No `CursorAdapter` — `packages/cli/internal/adapter/registry.go` |
| Migration detect | `DetectCursorSetup()` only checks `.cursor/` exists — `packages/cli/internal/migration/detector.go` |
| `DetectionPatterns` | No `cursor` entry |
| `bin/inject` | No `--surface cursor` — `bin/inject` |
| `.agents/config/cli-adapters.yml` | No cursor entry |
| Prior specs | `specs/021-parity-verification/compozy-analysis.md` lists Cursor as P2 “observed/managed” wave; `specs/028-fake-projects-testing-plan/spec.md` lists `cursor` in test matrix only |

**Conclusion:** Detection is informational; there is no compile/install path.

---

## Product Boundary (must preserve)

From `docs/concepts/harness-principles.md`:

- LazyAI is a **compile-time asset manager**; host tools execute.
- **Adapter honesty over fake parity** — emit only verified native surfaces.
- Canonical shared layer: **`AGENTS.md`**, skills (Agent Skills), hooks (policy scripts + native config), MCP (`.ai/mcp.json` → per-tool).

**Explicit non-goals for Cursor (aligned with maintainer intent):**

- **Rules `.mdc`** — Cursor-native; analogous in *role* to Kiro steering or Claude `.claude/rules/`, but **not** a LazyAI-unified asset kind. LazyAI does not emit Kiro steering today (`docs/adapters/kiro.md`: “No specs or steering”).
- **Custom agent profiles** — no documented `.cursor/agents/` surface comparable to Claude/Kiro JSON agents. Specialist content remains in shared `AGENTS.md` + skills.

---

## Official Cursor Surfaces (source-verified)

Sources: [Cursor MCP](https://cursor.com/docs/mcp), [Cursor Skills](https://cursor.com/docs/skills), [Cursor Hooks](https://cursor.com/docs/hooks).

### MCP

| Scope | Path | Shape |
|---|---|---|
| Project | `.cursor/mcp.json` | Top-level `mcpServers` object |
| Global | `~/.cursor/mcp.json` | Same schema |

Variable substitution supported in `command`, `args`, `env`, `url`, `headers` (`${workspaceFolder}`, `${env:NAME}`, etc.).

**LazyAI mapping:** Same conceptual job as Claude Code’s `.mcp.json` / `mcpServers` emission (`toClaudeCodeMcp` in `mcp_compiler.go`). Only the output path changes (`.cursor/mcp.json`).

### Skills (Agent Skills compatible)

| Scope | Path |
|---|---|
| Project | `.cursor/skills/<name>/SKILL.md` |
| Global | `~/.cursor/skills/<name>/SKILL.md` |

Cursor also discovers `.agents/skills/`, Claude/Codex skill dirs, and nested monorepo `.cursor/skills/` trees. For LazyAI **managed output**, use **`.cursor/skills/`** when target is `cursor` so lockfile ownership is clear (YAGNI: no cross-target dedup with Codex in v1).

Required frontmatter: `name`, `description`. Optional: `paths`, `disable-model-invocation`.

**LazyAI mapping:** Same as other adapters — `CopyLibraryDirectory` from `library/skills/` with `ShapeDirPerItem` (see `output_mapping.go` Codex/Copilot patterns).

### Hooks

| Scope | Config | Script CWD |
|---|---|---|
| Project | `.cursor/hooks.json` | Project root; use **`.cursor/hooks/...`** in `command` paths |
| Global | `~/.cursor/hooks.json` | `~/.cursor/`; use `./hooks/...` paths |

Schema: `"version": 1`, event keys map to hook definition arrays (e.g. `beforeShellExecution`, `preToolUse`, `sessionStart`, …).

**LazyAI mapping:** Static `library/cursor/hooks.json` + `library/cursor/hooks/lazyai/*.sh` (same policy scripts as Codex/Copilot), **not** a runtime translation from Claude `PreToolUse` JSON. Initial hook: canonical `block-destructive-shell` mapped to an appropriate shell gate event (`beforeShellExecution` with matcher, or `preToolUse` — see plan verification task).

### Root instructions

Cursor loads project **`AGENTS.md`** (same pattern as OpenCode/Codex). LazyAI already scaffolds `AGENTS.md` via `scaffold/` — **no Cursor-specific duplicate** in the adapter.

### Custom agents

No official “custom agent file” path analogous to `.claude/agents/*.md` or `.kiro/agents/*.json` was identified in Cursor docs reviewed for this research. Subagent/cloud agent behavior is product/runtime concern, not a repo-local profile directory LazyAI should invent.

**LazyAI behavior:** Do not emit agent files. Do not log on every `Install`. Optional **`doctor` info** when `cursor` ∈ targets (see plan).

---

## Reference Adapters (implementation templates)

| Concern | Closest existing code |
|---|---|
| Hooks + JSON config | `packages/cli/internal/adapter/codex.go` + `library/codex/hooks.json` |
| MCP `mcpServers` JSON | `mcp_compiler.go` → `compileCopilotMCP` / VS Code path |
| Skills dir-per-item | `codex.go` (`.agents/skills/`) or `copilot.go` (`.github/skills/`) — Cursor uses `.cursor/skills/` |
| No custom agents | `antigravity.go` (skills/hooks only; no agent files) |
| Capabilities honesty | `capabilities.go` — declare false for unsupported bools |

---

## Schema / manifest drift (incidental fix)

`packages/cli/internal/schema/lazyai.schema.json` `targets` enum lists eight tools but **omits `codex`**, while Go code accepts `codex`. Adding `cursor` should include **`codex`** in the same change to keep JSON schema aligned with `SupportedToolIDs`.

---

## Unknowns and resolution

| Unknown | Blocking? | Resolution |
|---|---|---|
| Exact hook event for destructive shell block | Low | Match Copilot/Codex intent; validate JSON against Cursor hooks doc; adjust `library/cursor/hooks.json` in PR |
| Runtime smoke with Cursor CLI/IDE | Medium | Manual: open project after `lazyai-cli compile`, confirm MCP/skills/hooks visible; mark adapter **beta** until done |
| Global scope writes to `~/.cursor` | Low | Follow `globalpaths` + existing safety flags on manifest; test `scope_test.go` |
| Cloud Agents picking up project hooks | Info only | Project `.cursor/hooks.json` documented as supported for cloud agents; user-level hooks not |

---

## Sources

- LazyAI: `docs/concepts/harness-principles.md`, `docs/adapters/kiro.md`, `packages/cli/internal/adapter/codex.go`, `packages/cli/internal/migration/detector.go`
- Cursor: https://cursor.com/docs/mcp , https://cursor.com/docs/skills , https://cursor.com/docs/hooks
- Prior internal notes: `specs/021-parity-verification/compozy-analysis.md` (Cursor as adjacent tool, P2)
