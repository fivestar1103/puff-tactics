#!/usr/bin/env bash
# Takes a screenshot of the Puff Tactics game window.
# Usage: ./ralph/take_screenshot.sh [--scene=res://path/to/Scene.tscn]
#
# Requires: Godot in PATH, DISPLAY or WAYLAND_DISPLAY set (WSLg works).
# Output: ralph/screenshots/latest.png

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_PATH="$PROJECT_DIR/ralph/screenshots/latest.png"
TIMEOUT_SECS=15
EXTRA_ARGS=("$@")

# --- Pre-flight checks ---
if ! command -v godot &>/dev/null; then
  echo "ERROR: 'godot' not found in PATH" >&2
  exit 1
fi

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  echo "ERROR: No display server available (DISPLAY and WAYLAND_DISPLAY are unset)." >&2
  echo "       Run from WSLg or set up a virtual display (Xvfb)." >&2
  exit 1
fi

# --- Kill stale Godot processes ---
pkill -f "godot.*--path" 2>/dev/null || true
sleep 1

# --- Prepare screenshot directory ---
mkdir -p "$PROJECT_DIR/ralph/screenshots"
rm -f "$SCREENSHOT_PATH"

# --- Run Godot with --screenshot flag ---
echo "[take_screenshot] Launching Godot for screenshot capture..."
timeout "$TIMEOUT_SECS" godot --path "$PROJECT_DIR" -- --screenshot "${EXTRA_ARGS[@]}" 2>&1 || true

# --- Verify output ---
if [ -f "$SCREENSHOT_PATH" ]; then
  FILE_SIZE=$(stat -c%s "$SCREENSHOT_PATH" 2>/dev/null || stat -f%z "$SCREENSHOT_PATH" 2>/dev/null)
  echo "[take_screenshot] Screenshot captured: $SCREENSHOT_PATH ($FILE_SIZE bytes)"
  exit 0
else
  echo "ERROR: Screenshot was not captured. Check Godot output above." >&2
  exit 1
fi
