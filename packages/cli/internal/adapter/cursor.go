package adapter

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	"github.com/rluisb/lazyai/packages/cli/internal/files"
	"github.com/rluisb/lazyai/packages/cli/internal/types"
)

// CursorAdapter installs Cursor IDE/CLI native surfaces. Cursor reads project
// instructions from AGENTS.md (scaffold layer), MCP from .cursor/mcp.json,
// Agent Skills from .cursor/skills/<name>/SKILL.md, and lifecycle hooks from
// .cursor/hooks.json. LazyAI does not emit custom agent profiles or .mdc rules.
// Refs: https://cursor.com/docs/skills, /docs/mcp, /docs/hooks.
type CursorAdapter struct{}

func (a *CursorAdapter) ID() types.ToolId  { return types.ToolIdCursor }
func (a *CursorAdapter) Name() string      { return "Cursor" }
func (a *CursorAdapter) ConfigDir() string { return ".cursor" }

func (a *CursorAdapter) Install(ctx *AdapterContext) ([]types.TrackedFile, error) {
	if !IsScopeSupported(types.ToolIdCursor, ctx.SetupScope) {
		return ctx.FileRecords, nil
	}
	cursorDir, err := ResolveToolRoot(types.ToolIdCursor, ctx.SetupScope, ctx)
	if err != nil {
		return nil, err
	}

	skillsDir := filepath.Join(cursorDir, "skills")
	if err := files.EnsureDir(skillsDir); err != nil {
		return nil, err
	}
	if err := CopyLibraryDirectory(CopyLibraryDirectoryOption{
		Ctx:          ctx,
		SourceSubdir: "skills",
		SelectionKey: "skills",
		ToDestPath: func(file string) string {
			return filepath.Join(skillsDir, fileID(file), "SKILL.md")
		},
	}); err != nil {
		return nil, err
	}

	if err := CopyLibraryDirectory(CopyLibraryDirectoryOption{
		Ctx:          ctx,
		SourceSubdir: "cursor/hooks",
		Recursive:    true,
		ToDestPath: func(file string) string {
			return filepath.Join(cursorDir, "hooks", file)
		},
		Mode: 0o755,
	}); err != nil {
		return nil, err
	}

	hooksConfig, err := readJSONAsset(ctx, "cursor/hooks.json")
	if err != nil {
		return nil, err
	}
	hookCommand := ".cursor/hooks/lazyai/block-destructive-shell.sh"
	if ctx.SetupScope == types.SetupScopeGlobal {
		hookCommand = "./hooks/lazyai/block-destructive-shell.sh"
	}
	if hooks, ok := hooksConfig["hooks"].(map[string]any); ok {
		if before, ok := hooks["beforeShellExecution"].([]any); ok && len(before) > 0 {
			if entry, ok := before[0].(map[string]any); ok {
				entry["command"] = hookCommand
			}
		}
	}

	hooksPayload, err := json.MarshalIndent(hooksConfig, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("marshal cursor/hooks.json: %w", err)
	}
	hooksJSONPath := filepath.Join(cursorDir, "hooks.json")
	if err := files.WriteFile(hooksJSONPath, hooksPayload, 0o644); err != nil {
		return nil, err
	}
	if err := trackFile(ctx, hooksJSONPath, "cursor/hooks.json"); err != nil {
		return nil, err
	}

	return ctx.FileRecords, nil
}

func (a *CursorAdapter) CompileMCP(ctx CompileContext) ([]types.TrackedFile, error) {
	return CompileMCPForTool(types.ToolIdCursor, ctx)
}

func (a *CursorAdapter) CanRunHeadless() bool { return false }

func (a *CursorAdapter) RunHeadlessValidation(ctx *AdapterContext) error { return nil }

func (a *CursorAdapter) RunHeadlessInit(ctx *AdapterContext, prompt string) error { return nil }
