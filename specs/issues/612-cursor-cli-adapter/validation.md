# Manual validation (issue #612)

Recorded during implementation (automated checks plus local CLI smoke).

## Automated

- `go test ./packages/cli/internal/adapter/... -count=1` — pass
- `go test ./internal/compiler/... -count=1` — pass (includes `cursor-only` golden)
- `go test ./internal/schema/... ./internal/aimanifest/... -count=1` — pass

## Local CLI smoke (project scope)

Commands run from a temp directory with the built binary (embedded library includes `cursor/`):

```bash
cd packages/cli
go build -o ~/tmp/lazyai-cli-smoke ./cmd/lazyai-cli
SMOKE=$(mktemp -d) && cd "$SMOKE"
~/tmp/lazyai-cli-smoke init --scope project --tools cursor --preset minimal --no-interactive --name cursor-smoke
```

Observed: `.cursor/skills/*/SKILL.md`, `.cursor/hooks.json`, `.cursor/hooks/lazyai/block-destructive-shell.sh`; after `compile`, `.cursor/mcp.json` when `.ai/mcp.json` has enabled servers.

## Cursor IDE (maintainer follow-up)

- Confirm MCP servers load from `.cursor/mcp.json`
- Confirm skills appear in Cursor skill discovery
- Confirm `beforeShellExecution` hook is registered

Update this file or the PR `### Validação` section when IDE smoke is complete.
