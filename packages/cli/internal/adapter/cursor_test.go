package adapter

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/rluisb/lazyai/packages/cli/internal/files"
	"github.com/rluisb/lazyai/packages/cli/internal/types"
)

func TestCursorAdapter_Install_EmitsSkillsAndHooks(t *testing.T) {
	ctx, targetDir := createTestAdapterContext(t)
	libFS, ok := ctx.LibraryFS.(fstest.MapFS)
	if !ok {
		t.Fatalf("expected test library fs")
	}
	libFS["cursor/hooks.json"] = &fstest.MapFile{
		Data: []byte(`{"version":1,"hooks":{"beforeShellExecution":[{"command":".cursor/hooks/lazyai/block-destructive-shell.sh"}]}}`),
	}
	libFS["cursor/hooks/lazyai/block-destructive-shell.sh"] = &fstest.MapFile{
		Data: []byte("#!/usr/bin/env bash\nexit 0\n"),
	}
	ctx.Selections = AdapterSelections{
		Skills: []types.SkillId{types.SkillIdDiagnose},
	}

	a := &CursorAdapter{}
	if _, err := a.Install(ctx); err != nil {
		t.Fatalf("Cursor Install failed: %v", err)
	}

	for _, path := range []string{
		filepath.Join(targetDir, ".cursor", "skills", "diagnose", "SKILL.md"),
		filepath.Join(targetDir, ".cursor", "hooks.json"),
		filepath.Join(targetDir, ".cursor", "hooks", "lazyai", "block-destructive-shell.sh"),
	} {
		assertExists(t, path)
	}

	var hooks map[string]any
	data, err := os.ReadFile(filepath.Join(targetDir, ".cursor", "hooks.json"))
	if err != nil {
		t.Fatalf("read hooks.json: %v", err)
	}
	if err := json.Unmarshal(data, &hooks); err != nil {
		t.Fatalf("parse hooks.json: %v", err)
	}
	if hooks["version"] != float64(1) {
		t.Fatalf("hooks.json version = %v, want 1", hooks["version"])
	}
}

func TestCursorAdapter_Install_DoesNotEmitAgents(t *testing.T) {
	ctx, targetDir := createTestAdapterContext(t)
	libFS, ok := ctx.LibraryFS.(fstest.MapFS)
	if !ok {
		t.Fatalf("expected test library fs")
	}
	libFS["cursor/hooks.json"] = &fstest.MapFile{Data: []byte(`{"version":1,"hooks":{}}`)}
	ctx.Selections = AdapterSelections{
		Agents: []types.AgentId{types.AgentIdReviewer},
		Skills: []types.SkillId{types.SkillIdDiagnose},
	}

	a := &CursorAdapter{}
	if _, err := a.Install(ctx); err != nil {
		t.Fatalf("Cursor Install failed: %v", err)
	}

	agentsDir := filepath.Join(targetDir, ".cursor", "agents")
	if files.DirExists(agentsDir) {
		entries, _ := os.ReadDir(agentsDir)
		if len(entries) > 0 {
			t.Fatalf("unexpected agent files under .cursor/agents: %d entries", len(entries))
		}
	}
}

func TestCompileCursorMCP_WritesMcpServersJson(t *testing.T) {
	targetDir := t.TempDir()
	aiDir := filepath.Join(targetDir, ".ai")
	_ = files.EnsureDir(aiDir)
	mcp := `{"servers":{"ctx7":{"command":"npx","args":["-y","@upstash/context7-mcp"]}}}`
	if err := os.WriteFile(filepath.Join(aiDir, "mcp.json"), []byte(mcp), 0o644); err != nil {
		t.Fatalf("write mcp.json: %v", err)
	}

	records, err := CompileMCPForTool(types.ToolIdCursor, CompileContext{
		TargetDir:  targetDir,
		SetupScope: types.SetupScopeProject,
	})
	if err != nil {
		t.Fatalf("CompileMCPForTool(cursor) failed: %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("expected 1 tracked record, got %d", len(records))
	}

	data, err := os.ReadFile(filepath.Join(targetDir, ".cursor", "mcp.json"))
	if err != nil {
		t.Fatalf("read .cursor/mcp.json: %v", err)
	}
	got := string(data)
	if !strings.Contains(got, `"mcpServers"`) {
		t.Fatalf(".cursor/mcp.json missing mcpServers key:\n%s", got)
	}
	if !strings.Contains(got, `"ctx7"`) {
		t.Fatalf(".cursor/mcp.json missing ctx7 server:\n%s", got)
	}
}

func TestOutputMappingCursorAgentsNone(t *testing.T) {
	target, ok := LookupOutputTarget(types.ToolIdCursor, AssetKindAgents)
	if !ok {
		t.Fatal("cursor has no agents target entry")
	}
	if target.Shape != ShapeNone {
		t.Errorf("cursor agents Shape=%q, want none", target.Shape)
	}
}
