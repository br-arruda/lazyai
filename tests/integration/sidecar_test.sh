#!/usr/bin/env bash
set -euo pipefail

# Integration Test: Sidecar Lifecycle
# Tests the positional-discovery sidecar model (issue #579): sidecar init
# writes to cwd/.lazyai/sidecar.yaml (or ~/.lazyai/sidecar.yaml for global
# scope), sidecar status/doctor discover layers by walking up from cwd, and
# there is no workspace registry and no attach/detach command.
# Uses a temporary HOME so the real ~/.lazyai is never touched.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLI="${CLI:-$PROJECT_DIR/packages/cli/lazyai-cli}"

# Temporary directories (cleaned up on exit)
TMP_HOME=$(mktemp -d)
TMP_WORKSPACE=$(mktemp -d)
TMP_PROJECT="$TMP_WORKSPACE/project"
TMP_SIDECAR=$(mktemp -d)
mkdir -p "$TMP_PROJECT"
trap 'rm -rf "$TMP_HOME" "$TMP_WORKSPACE" "$TMP_SIDECAR"' EXIT

export HOME="$TMP_HOME"

echo "═══════════════════════════════════════════════════════════════"
echo "🧪 Integration Test: Sidecar Lifecycle"
echo "═══════════════════════════════════════════════════════════════"
echo "CLI binary:      $CLI"
echo "Temp HOME:       $TMP_HOME"
echo "Temp workspace:  $TMP_WORKSPACE"
echo "Temp project:    $TMP_PROJECT (child of workspace)"
echo "Temp sidecar:    $TMP_SIDECAR"
echo ""

# Check if CLI binary exists
if [ ! -x "$CLI" ]; then
    echo "❌ CLI binary not found or not executable: $CLI"
    echo "   Build the CLI with: cd packages/cli && go build ./cmd/lazyai-cli"
    exit 1
fi

# Verify sidecar command is available (sidecar is implemented — missing = failure)
if ! "$CLI" sidecar --help >/dev/null 2>&1; then
    echo "❌ Sidecar command missing from CLI binary: $CLI"
    echo "   Build the CLI with: cd packages/cli && go build ./cmd/lazyai-cli"
    exit 1
fi

# Helper: run a command and assert success
assert_success() {
    local label="$1"
    shift
    echo "  → $label"
    if "$@"; then
        echo "  ✅ $label succeeded"
    else
        echo "  ❌ $label FAILED (exit $?)"
        exit 1
    fi
}

# ───────────────────────────────────────────────────────────────
# Regression guard (#579): workspace registry and attach/detach
# commands are fully removed, not silently no-op'd.
#
# Note: cobra's non-runnable parent commands (e.g. "sidecar", "memory")
# print their own help and exit 0 for an unrecognized subcommand — that
# is standard behavior across this CLI, not something #579 changed. The
# reliable check is whether "attach"/"detach" appear in the listed
# subcommands. The top-level "workspace" command, by contrast, has no
# parent group to fall back to, so it correctly errors non-zero.
# ───────────────────────────────────────────────────────────────
echo "Regression: deleted commands are fully removed"
if "$CLI" workspace >/dev/null 2>&1; then
    echo "  ❌ 'workspace' command still exists (should be deleted)"
    exit 1
fi
echo "  ✅ 'workspace' is an unknown command"

SIDECAR_HELP=$("$CLI" sidecar --help 2>&1)
if echo "$SIDECAR_HELP" | grep -qE "^[[:space:]]*attach([[:space:]]|$)"; then
    echo "  ❌ 'sidecar attach' still listed in 'sidecar --help' (should be deleted)"
    exit 1
fi
if echo "$SIDECAR_HELP" | grep -qE "^[[:space:]]*detach([[:space:]]|$)"; then
    echo "  ❌ 'sidecar detach' still listed in 'sidecar --help' (should be deleted)"
    exit 1
fi
echo "  ✅ 'sidecar attach'/'sidecar detach' are not listed subcommands"

# ───────────────────────────────────────────────────────────────
# Test 1: sidecar init --scope workspace writes to cwd/.lazyai/sidecar.yaml
# ───────────────────────────────────────────────────────────────
echo ""
echo "Test 1: sidecar init --scope workspace --path <sidecar> (run from workspace root)"
(cd "$TMP_WORKSPACE" && assert_success "sidecar init workspace" "$CLI" sidecar init --scope workspace --path "$TMP_SIDECAR")

if [ -f "$TMP_WORKSPACE/.lazyai/sidecar.yaml" ]; then
    echo "  ✅ Workspace sidecar file exists: $TMP_WORKSPACE/.lazyai/sidecar.yaml"
else
    echo "  ❌ Workspace sidecar file not created at $TMP_WORKSPACE/.lazyai/sidecar.yaml"
    exit 1
fi

if [ -f "$TMP_HOME/.lazyai/workspaces.yaml" ]; then
    echo "  ❌ Legacy workspace registry was created (should never exist post-#579): $TMP_HOME/.lazyai/workspaces.yaml"
    exit 1
fi
echo "  ✅ No workspace registry (~/.lazyai/workspaces.yaml) was created"

# ───────────────────────────────────────────────────────────────
# Test 2: sidecar status discovers the ancestor workspace layer
# from a child project directory (positional walk-up)
# ───────────────────────────────────────────────────────────────
echo ""
echo "Test 2: sidecar status (run from child project dir, discovers ancestor workspace)"
STATUS_OUTPUT=$(cd "$TMP_PROJECT" && "$CLI" sidecar status 2>&1) || true
echo "$STATUS_OUTPUT"
if echo "$STATUS_OUTPUT" | grep -qE "workspace .*\(found\)"; then
    echo "  ✅ sidecar status discovered the ancestor workspace layer"
else
    echo "  ❌ sidecar status did not report the workspace layer as found"
    exit 1
fi
if echo "$STATUS_OUTPUT" | grep -qiE "(docs_dir|specs_dir|plans_dir)"; then
    echo "  ✅ sidecar status shows resolved-path fields"
else
    echo "  ❌ sidecar status missing expected resolved-path fields"
    exit 1
fi

# ───────────────────────────────────────────────────────────────
# Test 3: sidecar init --scope project writes to cwd/.lazyai/sidecar.yaml
# and takes precedence over the ancestor workspace layer
# ───────────────────────────────────────────────────────────────
echo ""
echo "Test 3: sidecar init --scope project --path <sidecar> (run from child project dir)"
mkdir -p "$TMP_SIDECAR/docs" "$TMP_SIDECAR/specs" "$TMP_SIDECAR/plans"
(cd "$TMP_PROJECT" && assert_success "sidecar init project" "$CLI" sidecar init --scope project --path "$TMP_SIDECAR/project-docs")
mkdir -p "$TMP_SIDECAR/project-docs/docs" "$TMP_SIDECAR/project-docs/specs" "$TMP_SIDECAR/project-docs/plans"

if [ -f "$TMP_PROJECT/.lazyai/sidecar.yaml" ]; then
    echo "  ✅ Project sidecar file exists: $TMP_PROJECT/.lazyai/sidecar.yaml"
else
    echo "  ❌ Project sidecar file not created at $TMP_PROJECT/.lazyai/sidecar.yaml"
    exit 1
fi
if [ -f "$TMP_PROJECT/.lazyai-sidecar.yaml" ]; then
    echo "  ❌ Legacy flat .lazyai-sidecar.yaml file was produced (should never exist post-#579)"
    exit 1
fi
echo "  ✅ No flat .lazyai-sidecar.yaml file was produced"

PROJECT_STATUS_OUTPUT=$(cd "$TMP_PROJECT" && "$CLI" sidecar status 2>&1) || true
echo "$PROJECT_STATUS_OUTPUT"
if echo "$PROJECT_STATUS_OUTPUT" | grep -qE "project .*\(found\)"; then
    echo "  ✅ sidecar status shows the project layer as found (project > workspace precedence)"
else
    echo "  ❌ sidecar status did not report the project layer as found"
    exit 1
fi

# ───────────────────────────────────────────────────────────────
# Test 4: sidecar doctor validates the discovered layers cleanly
# ───────────────────────────────────────────────────────────────
echo ""
echo "Test 4: sidecar doctor (run from child project dir)"
DOCTOR_OUTPUT=$(cd "$TMP_PROJECT" && "$CLI" sidecar doctor 2>&1)
DOCTOR_EXIT=$?
echo "$DOCTOR_OUTPUT"
if [ "$DOCTOR_EXIT" -ne 0 ]; then
    echo "  ❌ sidecar doctor exited non-zero"
    exit 1
fi
if echo "$DOCTOR_OUTPUT" | grep -qE "WARN|ERROR"; then
    echo "  ❌ sidecar doctor reported WARN/ERROR issues with fully-populated layers"
    exit 1
fi
echo "  ✅ sidecar doctor: all discovered layers valid, zero issues"

# ───────────────────────────────────────────────────────────────
# Test 5: backward compat — no sidecar anywhere = graceful default status
# ───────────────────────────────────────────────────────────────
echo ""
echo "Test 5: Backward compatibility (no sidecar configured anywhere)"
TMP_CLEAN_HOME=$(mktemp -d)
TMP_CLEAN_PROJECT=$(mktemp -d)
trap 'rm -rf "$TMP_HOME" "$TMP_WORKSPACE" "$TMP_SIDECAR" "$TMP_CLEAN_HOME" "$TMP_CLEAN_PROJECT"' EXIT

NO_SIDECAR_OUTPUT=$(cd "$TMP_CLEAN_PROJECT" && HOME="$TMP_CLEAN_HOME" "$CLI" sidecar status 2>&1) || true
echo "$NO_SIDECAR_OUTPUT"
if echo "$NO_SIDECAR_OUTPUT" | grep -qiE "(no \.lazyai/ configuration found|not found)"; then
    echo "  ✅ No sidecar = graceful fallback with built-in defaults"
else
    echo "  ❌ No-sidecar output missing expected fallback guidance"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ All sidecar integration tests passed."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Notes:"
echo "  • Real ~/.lazyai was never touched (used temp HOME: $TMP_HOME)."
echo "  • Build the CLI with 'cd packages/cli && go build ./cmd/lazyai-cli' before running these tests."
