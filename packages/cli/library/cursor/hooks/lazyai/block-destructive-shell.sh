#!/usr/bin/env bash
# LazyAI Cursor beforeShellExecution hook: blocks obviously destructive shell commands.
# Cursor delivers hook context on stdin; non-zero exit blocks execution. This is a
# usability guardrail, not a security boundary. See https://cursor.com/docs/hooks.

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi
input="$(cat)"

JSON_INPUT="$input" python3 - <<'PY'
import json
import os
import sys

try:
    data = json.loads(os.environ.get("JSON_INPUT", ""))
except Exception:
    sys.exit(0)

command = data.get("command") or data.get("shellCommand") or ""
if isinstance(data.get("tool_input"), dict):
    command = command or data["tool_input"].get("command", "")
if not isinstance(command, str):
    sys.exit(0)

command = command.strip()
denied_prefixes = [
    "rm -rf /",
    "rm -rf /*",
    "mkfs",
    "dd if=/dev/zero of=",
    "dd if=/dev/zero of=/dev/",
    "> /dev/sd",
    "shutdown",
    "poweroff",
    "reboot",
    "halt",
]
if any(command == p or command.startswith(p + " ") for p in denied_prefixes):
    print("Destructive shell command blocked by LazyAI policy", file=sys.stderr)
    sys.exit(2)
sys.exit(0)
PY
