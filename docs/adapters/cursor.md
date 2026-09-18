# Cursor adapter

**Support level:** beta (issue #612, ADR-009)  
**Verification:** Official Cursor docs for skills, MCP, and hooks; unit and golden tests in `packages/cli/internal/adapter/cursor_test.go` and `testdata/golden/cursor-only/`. Manual IDE/CLI smoke pending.

## What LazyAI emits

| Surface | Project / workspace path | Global path |
|---|---|---|
| Root instructions | `AGENTS.md` (scaffold; not duplicated under `.cursor/`) | same |
| Skills | `.cursor/skills/<name>/SKILL.md` | `~/.cursor/skills/<name>/SKILL.md` |
| MCP | `.cursor/mcp.json` (`mcpServers`) | `~/.cursor/mcp.json` |
| Hooks | `.cursor/hooks.json` + `.cursor/hooks/lazyai/*.sh` | `~/.cursor/hooks.json` + scripts under `~/.cursor/hooks/` |

Compile MCP from canonical `.ai/mcp.json` the same way as Claude Code (`mcpServers` object shape).

## Out of scope (v1)

- Cursor rules (`.cursor/rules/*.mdc`) and steering-like files
- Custom agent profile directories (no `.cursor/agents/` from LazyAI)
- `bin/inject --surface cursor`
- Headless placeholder fill via Cursor CLI

Use shared `AGENTS.md` and skills for specialist behavior. `lazyai-cli doctor` prints an informational note when `cursor` is among configured tools; it does not fail health for missing agent profiles.

## References

- [Cursor Skills](https://cursor.com/docs/skills)
- [Cursor MCP](https://cursor.com/docs/mcp)
- [Cursor Hooks](https://cursor.com/docs/hooks)
- Issue [#612](https://github.com/rluisb/lazyai/issues/612)
- ADR [009 nine-target contract (Codex stable, Cursor beta)](https://github.com/rluisb/lazyai/blob/main/specs/adrs/009-nine-target-contract-codex-stable-cursor-beta.md)
