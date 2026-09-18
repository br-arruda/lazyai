# Plan: Cursor adapter — skills, MCP, hooks (minimal)

**Issue:** #612  
**Date:** 2026-09-17  
**Status:** approved-for-implementation (single PR)  
**Depends on:** `research.md` (this directory)

---

## Four-point summary

| Point | Content |
|---|---|
| **WHAT** | Add `cursor` as a compile target emitting **skills**, **MCP**, and **hooks** in Cursor-native paths; shared **`AGENTS.md`** via existing scaffold. |
| **HOW** | New `CursorAdapter` following Codex (hooks) + Copilot MCP serializer (`.cursor/mcp.json`); register in types/registry/scope/globalpaths/output_mapping/capabilities; static `library/cursor/*` assets. |
| **DON'T WANT** | Rules (`.mdc`), steering, fake agents, per-install agent logs, `bin/inject` in v1, duplicating LazyAI canonical rules into Cursor-only formats. |
| **VALIDATE** | `go test ./packages/cli/internal/adapter/...`; empty-dir `init` + `compile` + `doctor`; idempotent second `compile` via lockfile. |

---

## Decision summary

1. **In scope:** `.cursor/skills/`, `.cursor/mcp.json`, `.cursor/hooks.json`, `.cursor/hooks/lazyai/*.sh`, global equivalents under `~/.cursor/`.
2. **Out of scope:** `.cursor/rules/*.mdc`, custom agent directories, commands/chat modes, headless CLI populate.
3. **Agents:** `output_mapping` → `ShapeNone` for `AssetKindAgents`; **no** `Install` side effects; **optional** `doctor` informational line when target includes `cursor` (not a failing check).
4. **Support level:** `beta` until manual Cursor smoke is recorded in PR validation section.
5. **DRY:** Reuse VS Code/Copilot MCP JSON builder; do not add a second MCP schema writer.
6. **YAGNI:** One PR; no inject surface; no import from existing `.cursor/rules`.

---

## ## TDD Plan (medium)

**Behavior contract**

- Given project scope and target `cursor`, after `Install`: skills and hooks exist under `.cursor/`; **no** `.cursor/agents/` (or any agent profile path).
- Given `.ai/mcp.json` with enabled servers, after `CompileMCP`: `.cursor/mcp.json` contains `mcpServers` with enabled entries only.
- Given global scope, paths resolve under `~/.cursor/` (skills, hooks, mcp) per `globalpaths`.

**Red tests (write first)**

| Test | File |
|---|---|
| `TestCursorAdapter_Install_EmitsSkillsAndHooks` | `cursor_test.go` |
| `TestCursorAdapter_Install_DoesNotEmitAgents` | `cursor_test.go` |
| `TestCompileCursorMCP_WritesMcpServersJson` | `cursor_test.go` or `mcp_compiler_test.go` |
| Registry lists cursor | extend `registry_test.go` |
| Output mapping agents = none | extend `output_mapping_test.go` |
| Capabilities: skills/hooks/MCP true, agents false | extend `capabilities_test.go` |
| Scope paths | extend `scope_test.go`, `globalpaths_test.go` |

**Verification command**

```bash
cd packages/cli && go test ./internal/adapter/... -count=1
```

**Test preservation:** Extend existing contract tests only; do not weaken other adapters.

---

## Implementation checklist (single PR)

### A. Spec (this phase — done when PR opens)

- [x] `specs/issues/612-cursor-cli-adapter/research.md`
- [x] `specs/issues/612-cursor-cli-adapter/plan.md`

### B. Types and registration

| File | Change |
|---|---|
| `internal/types/types.go` | `ToolIdCursor = "cursor"`; append to `SupportedToolIDs` |
| `internal/types/types_test.go` | `IsValidToolId("cursor")` |
| `internal/adapter/registry.go` | Register `CursorAdapter` |
| `internal/adapter/scope.go` | `projectSubdir` → `.cursor` |
| `internal/globalpaths/globalpaths.go` | Global root `~/.cursor`; `IsGlobalSupportedTool` |
| `internal/schema/lazyai.schema.json` | Add `"cursor"` and missing `"codex"` to `targets` enum |
| `internal/schema/schema_test.go` | Enum coverage |
| `internal/validation/validation.go` | Valid tool id |
| `internal/migration/detector.go` | `DetectionPatterns["cursor"]`, `AdapterNames` |

### C. Adapter core

| File | Change |
|---|---|
| **`internal/adapter/cursor.go`** | New `CursorAdapter`: `Install` (skills + hooks only), `CompileMCP` delegate, headless false |
| **`internal/adapter/cursor_test.go`** | Install + MCP tests |
| `internal/adapter/capabilities.go` | Cursor `Capabilities()` — beta; agents false |
| `internal/adapter/output_mapping.go` | Cursor row: skills dir-per-item → `skills`; all other kinds `ShapeNone` including agents |
| `internal/adapter/mcp_compiler.go` | `case ToolIdCursor:` → `compileCursorMCP` writing `.cursor/mcp.json` via shared VS Code payload helper |

### D. Embedded library assets

| Path | Change |
|---|---|
| `library/cursor/hooks.json` | `version: 1`; map lazyai shell guard to Cursor hook events; commands use `.cursor/hooks/lazyai/...` |
| `library/cursor/hooks/lazyai/block-destructive-shell.sh` | Copy/adapt from `library/codex/hooks/lazyai/` (path references only) |

Optional later (not v1): `objective-workflow-gate`, `startup-self-heal` — only if hook events are verified; YAGNI start with one hook.

### E. CLI / wizard (minimal strings)

| File | Change |
|---|---|
| `tui/wizard/phase1.go` | Select option Cursor |
| `tui/wizard/hover_descriptions.go` | One-line description |
| `cmd/helpers.go` | `--tool cursor` validation |
| `README.md` | One table row + example tools list |

### F. Doctor (agents — informational only)

| File | Change |
|---|---|
| `cmd/doctor.go` or `doctor_health.go` | When manifest targets include `cursor`: emit **info** “Cursor has no custom agent profiles; use AGENTS.md and skills.” Do **not** fail health. Do **not** log in `Install`. |

### G. Documentation (minimal)

| File | Change |
|---|---|
| `docs/adapters/cursor.md` | Generated paths, limitations, links to cursor.com docs |
| `docs/concepts/tools.md` | Short Cursor section + comparison table column (follow-up if table too wide: row in plan only) |

**Deferred (explicit out of PR):** `bin/inject`, `cli-adapters.yml`, mkdocs nav, golden `testdata/golden/cursor-only/` (add if existing golden harness requires new fixture — prefer one test in `cursor_test.go` first).

---

## Hook mapping (initial)

Canonical policy: `block-destructive-shell` (see `library/hooks/block-destructive-shell.md`).

Proposed Cursor mapping (verify against hooks doc during implementation):

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      {
        "command": ".cursor/hooks/lazyai/block-destructive-shell.sh"
      }
    ]
  }
}
```

If matcher support is required to avoid blocking non-shell tools, add `"matcher"` per Cursor docs without changing the shell script.

---

## Acceptance criteria

1. `lazyai-cli init --scope project --tools cursor --preset minimal --no-interactive` then `compile` creates:
   - `.cursor/skills/<selected>/SKILL.md` (when skills selected)
   - `.cursor/hooks.json` and `.cursor/hooks/lazyai/block-destructive-shell.sh`
   - `.cursor/mcp.json` when MCP servers enabled in `.ai/mcp.json`
2. No agent profile files under `.cursor/` from LazyAI.
3. `lazyai-cli doctor` does not fail solely because Cursor lacks agents; optional info message present.
4. `go test ./internal/adapter/...` passes; `output_mapping` and `capabilities` tests cover `cursor`.
5. Second `compile` is idempotent (lockfile hashes unchanged when sources unchanged).
6. `research.md` boundaries respected: no `.mdc`, no steering, no agent emit.

---

## Out of scope (v1)

- Cursor rules (`.mdc`) and Kiro-style steering emission
- Custom agent / subagent file emission
- Import/absorb from existing `.cursor/rules`
- `bin/inject --surface cursor`
- Skills deduplication between `cursor` and `codex` targets
- Headless `RunHeadlessInit` / validation via Cursor binary
- Cloud vs local hook differences beyond project-level config

---

## Risks

| Risk | Mitigation |
|---|---|
| Hook schema differs from Claude/Codex | Static `library/cursor/hooks.json`; unit test loads JSON |
| MCP serializer mismatch | Reuse Copilot VS Code builder; golden byte compare in test |
| User expects LazyAI to manage `.mdc` | Document in `docs/adapters/cursor.md` and doctor info |
| Schema enum drift | Fix `codex` + add `cursor` in same PR |

---

## PR structure (suggested commits — one PR)

1. `docs: add cursor adapter research and plan` — this directory only  
2. `feat(cli): register cursor tool id and paths` — types, schema, migration, wizard  
3. `feat(adapter): cursor skills, mcp, and hooks` — adapter, library, mcp_compiler, tests  
4. `docs: cursor adapter user-facing notes` — README + `docs/adapters/cursor.md`  
5. (optional) `fix(schema): add codex to lazyai.json targets enum` — if not folded into commit 2  

---

## Manual validation (post-merge checklist for author)

- [ ] Fresh temp repo: init + compile with `cursor` only  
- [ ] Cursor IDE or CLI: MCP server appears from `.cursor/mcp.json`  
- [ ] Skill visible in agent skill list  
- [ ] Destructive shell hook fires on test command (or hook registered in UI)  
- [ ] Record result in PR `### Validação`  

---

## Human gate

Implementation may proceed per this plan; link PR to issue #612 and `specs/issues/612-cursor-cli-adapter/`.

<!-- Human Gate: pending PR author sign-off after manual Cursor smoke -->
