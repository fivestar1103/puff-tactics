#!/usr/bin/env bash
# Ralph Loop — Puff Tactics
# Two-phase visual verification loop:
#   Phase 1: Codex sees screenshot, implements story
#   Phase 2: ralph.sh takes NEW screenshot, Codex reviews & fixes
#   Guard: Protected layout constants are restored after each phase
#
# Usage: ./ralph/ralph.sh [max_iterations]
# Requires: codex CLI, godot, DISPLAY (WSLg)

set -euo pipefail

MAX_ITERATIONS="${1:-50}"
PROMPT_FILE="ralph/prompt.md"
PRD_FILE="ralph/prd.json"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_DIR="ralph/screenshots"

# Model that supports image input (gpt-5.3-codex-spark does NOT support vision)
CODEX_MODEL="gpt-5.3-codex"

cd "$PROJECT_DIR"

# ─── PROTECTED LAYOUT CONSTANTS ───
# These values were tuned by visual iteration and MUST NOT be changed by Codex.
# The guard_layout function restores them after each Codex phase.
GUARD_FEED_ITEM="src/scripts/feed/feed_item.gd"
GUARD_FEED_MAIN="src/scripts/feed/feed_main.gd"

guard_layout() {
  echo "[Guard] Checking protected layout constants..."
  local changed=0

  # feed_item.gd: SNAPSHOT_SCALE must be Vector2(1.65, 1.65)
  if ! grep -q 'SNAPSHOT_SCALE: Vector2 = Vector2(1.65, 1.65)' "$GUARD_FEED_ITEM"; then
    echo "[Guard] RESTORING SNAPSHOT_SCALE to 1.65"
    sed -i 's/const SNAPSHOT_SCALE: Vector2 = Vector2([^)]*)/const SNAPSHOT_SCALE: Vector2 = Vector2(1.65, 1.65)/' "$GUARD_FEED_ITEM"
    changed=1
  fi

  # feed_item.gd: SNAPSHOT_LOCAL_Y must be -220.0
  if ! grep -q 'SNAPSHOT_LOCAL_Y: float = -220.0' "$GUARD_FEED_ITEM"; then
    echo "[Guard] RESTORING SNAPSHOT_LOCAL_Y to -220.0"
    sed -i 's/const SNAPSHOT_LOCAL_Y: float = [^ ]*/const SNAPSHOT_LOCAL_Y: float = -220.0/' "$GUARD_FEED_ITEM"
    changed=1
  fi

  # feed_item.gd: STATUS_PANEL_MAP_GAP must be 8.0
  if ! grep -q 'STATUS_PANEL_MAP_GAP: float = 8.0' "$GUARD_FEED_ITEM"; then
    echo "[Guard] RESTORING STATUS_PANEL_MAP_GAP to 8.0"
    sed -i 's/const STATUS_PANEL_MAP_GAP: float = [^ ]*/const STATUS_PANEL_MAP_GAP: float = 8.0/' "$GUARD_FEED_ITEM"
    changed=1
  fi

  # feed_item.gd: SCORE_PANEL_SIZE height must be 280.0
  if ! grep -q 'SCORE_PANEL_SIZE: Vector2 = Vector2(804.0, 280.0)' "$GUARD_FEED_ITEM"; then
    echo "[Guard] RESTORING SCORE_PANEL_SIZE to (804.0, 280.0)"
    sed -i 's/const SCORE_PANEL_SIZE: Vector2 = Vector2([^)]*)/const SCORE_PANEL_SIZE: Vector2 = Vector2(804.0, 280.0)/' "$GUARD_FEED_ITEM"
    changed=1
  fi

  # feed_item.gd: SCORE_PANEL_MAP_GAP must be 10.0
  if ! grep -q 'SCORE_PANEL_MAP_GAP: float = 10.0' "$GUARD_FEED_ITEM"; then
    echo "[Guard] RESTORING SCORE_PANEL_MAP_GAP to 10.0"
    sed -i 's/const SCORE_PANEL_MAP_GAP: float = [^ ]*/const SCORE_PANEL_MAP_GAP: float = 10.0/' "$GUARD_FEED_ITEM"
    changed=1
  fi

  # feed_main.gd: SNAPSHOT_Y_RATIO must be 0.40
  if ! grep -q 'SNAPSHOT_Y_RATIO: float = 0.40' "$GUARD_FEED_MAIN"; then
    echo "[Guard] RESTORING SNAPSHOT_Y_RATIO to 0.40"
    sed -i 's/const SNAPSHOT_Y_RATIO: float = [^ ]*/const SNAPSHOT_Y_RATIO: float = 0.40/' "$GUARD_FEED_MAIN"
    changed=1
  fi

  # feed_main.gd: SCORE_TO_SWIPE_HINT_GAP must be 20.0
  if ! grep -q 'SCORE_TO_SWIPE_HINT_GAP: float = 20.0' "$GUARD_FEED_MAIN"; then
    echo "[Guard] RESTORING SCORE_TO_SWIPE_HINT_GAP to 20.0"
    sed -i 's/const SCORE_TO_SWIPE_HINT_GAP: float = [^ ]*/const SCORE_TO_SWIPE_HINT_GAP: float = 20.0/' "$GUARD_FEED_MAIN"
    changed=1
  fi

  # feed_main.gd: SWIPE_HINT_TO_FAB_GAP must be 20.0
  if ! grep -q 'SWIPE_HINT_TO_FAB_GAP: float = 20.0' "$GUARD_FEED_MAIN"; then
    echo "[Guard] RESTORING SWIPE_HINT_TO_FAB_GAP to 20.0"
    sed -i 's/const SWIPE_HINT_TO_FAB_GAP: float = [^ ]*/const SWIPE_HINT_TO_FAB_GAP: float = 20.0/' "$GUARD_FEED_MAIN"
    changed=1
  fi

  # feed_main.gd: FAB positioning must use score-panel-following logic (no maxf fallback)
  if grep -q 'fab_top_y = maxf(fab_top_y, fallback_fab_top_y)' "$GUARD_FEED_MAIN"; then
    echo "[Guard] RESTORING FAB positioning logic (removing maxf anchor)"
    # This is harder to sed — just restore the whole file's FAB block from git
    # For now, warn loudly
    echo "[Guard] WARNING: Codex re-added maxf FAB anchor. Manual fix needed."
  fi

  if [ "$changed" -eq 1 ]; then
    echo "[Guard] Layout constants were tampered with — restored and amending commit."
    git add "$GUARD_FEED_ITEM" "$GUARD_FEED_MAIN"
    git commit --amend --no-edit 2>/dev/null || true
  else
    echo "[Guard] Layout constants OK."
  fi
}

# Validate setup
for f in "$PROMPT_FILE" "$PRD_FILE"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: $f not found"
    exit 1
  fi
done

if ! command -v codex &> /dev/null; then
  echo "ERROR: 'codex' CLI not found in PATH"
  exit 1
fi

mkdir -p "$SCREENSHOT_DIR"

echo "========================================="
echo "  RALPH LOOP — Puff Tactics"
echo "  Model: $CODEX_MODEL (vision-enabled)"
echo "  Max iterations: $MAX_ITERATIONS"
echo "  Mode: Implement → Screenshot → Guard → Review"
echo "========================================="

# Take initial screenshot before any iterations
echo "[Ralph] Taking initial screenshot..."
bash ralph/take_screenshot.sh 2>&1 || true

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==========================================="
  echo "  Iteration $i / $MAX_ITERATIONS"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "==========================================="

  # Check how many stories remain
  INCOMPLETE=$(python3 -c "
import json
with open('$PRD_FILE') as f:
    prd = json.load(f)
incomplete = [s for s in prd['userStories'] if not s['passes']]
print(len(incomplete))
")

  if [ "$INCOMPLETE" -eq 0 ]; then
    echo ""
    echo "ALL STORIES COMPLETE!"
    bash ralph/take_screenshot.sh 2>&1 || true
    cp "$SCREENSHOT_DIR/latest.png" "$SCREENSHOT_DIR/final.png" 2>/dev/null || true
    exit 0
  fi

  echo "Remaining stories: $INCOMPLETE"

  # ─── PHASE 1: IMPLEMENT ───
  echo ""
  echo "--- Phase 1: Implement (with pre-screenshot) ---"

  CODEX_ARGS=(exec --full-auto -m "$CODEX_MODEL")
  if [ -f "$SCREENSHOT_DIR/latest.png" ]; then
    CODEX_ARGS+=(-i "$SCREENSHOT_DIR/latest.png")
    echo "[Ralph] Attaching screenshot to Codex"
  fi

  IMPLEMENT_PROMPT=$(cat "$PROMPT_FILE")
  OUTPUT=$(echo "$IMPLEMENT_PROMPT" | codex "${CODEX_ARGS[@]}" 2>&1) || true
  echo "$OUTPUT" | tail -20

  # ─── GUARD: Restore protected layout constants ───
  guard_layout

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo "RALPH COMPLETE — All stories passed!"
    bash ralph/take_screenshot.sh 2>&1 || true
    cp "$SCREENSHOT_DIR/latest.png" "$SCREENSHOT_DIR/final.png" 2>/dev/null || true
    exit 0
  fi

  # ─── TAKE POST-IMPLEMENTATION SCREENSHOT ───
  echo ""
  echo "--- Taking post-implementation screenshot ---"
  bash ralph/take_screenshot.sh 2>&1 || true
  cp "$SCREENSHOT_DIR/latest.png" "$SCREENSHOT_DIR/iteration_${i}_post.png" 2>/dev/null || true

  # ─── PHASE 2: VISUAL REVIEW & FIX ───
  echo ""
  echo "--- Phase 2: Visual review & fix ---"

  if [ -f "$SCREENSHOT_DIR/latest.png" ]; then
    REVIEW_PROMPT="You are a VISUAL QA REVIEWER for Puff Tactics. A screenshot is attached.

STEP 1 — MANDATORY SCREENSHOT ANALYSIS (write this out before doing anything):
- Describe every UI element you see from top to bottom
- Estimate the battle map width as % of screen width
- Count the visible puffs and note their team colors
- Identify ALL empty gaps and estimate their size as % of screen height
- Rate overall polish: 1 (broken prototype) to 10 (polished mobile game)

STEP 2 — CHECKLIST (mark each PASS or FAIL based on what you SEE):
[ ] Map fills 60-80% of screen width and is centered
[ ] All 25 tiles (5x5 iso grid) visible
[ ] 4+ puffs visible (2+ player green/mint, 2+ enemy pink/red)
[ ] Puffs large enough to see kawaii face details
[ ] No puff overlap
[ ] No vertical gap > 15% of screen height
[ ] All text readable with good contrast
[ ] No debug/stub/placeholder text visible
[ ] Pastel kawaii aesthetic (cream bg, lavender/mint/peach/sky/pink)

STEP 3 — ACTION:
- If ALL checks PASS and rating >= 7: output VISUAL_OK
- If ANY check FAILS: FIX the code, then amend the commit: git commit --amend --no-edit
- Update ralph/prd.json notes with your checklist results

IMPORTANT: Do NOT change layout positioning constants (SNAPSHOT_SCALE, SNAPSHOT_LOCAL_Y,
SNAPSHOT_Y_RATIO, gap sizes). These are protected and will be reverted automatically.
Focus on visual STYLE changes: colors, rounded corners, text content, typography, shadows.

Do NOT run bash ralph/take_screenshot.sh — no display in sandbox.
Read CLAUDE.md and AGENTS.md for conventions."

    REVIEW_ARGS=(exec --full-auto -m "$CODEX_MODEL" -i "$SCREENSHOT_DIR/latest.png")
    REVIEW_OUTPUT=$(echo "$REVIEW_PROMPT" | codex "${REVIEW_ARGS[@]}" 2>&1) || true
    echo "$REVIEW_OUTPUT" | tail -20

    # ─── GUARD: Restore protected layout constants after review too ───
    guard_layout

    # Take another screenshot after review fixes
    echo ""
    echo "--- Taking post-review screenshot ---"
    bash ralph/take_screenshot.sh 2>&1 || true
    cp "$SCREENSHOT_DIR/latest.png" "$SCREENSHOT_DIR/iteration_${i}_reviewed.png" 2>/dev/null || true
  fi

  echo ""
  echo "--- Iteration $i done ---"
  sleep 2
done

echo ""
echo "MAX ITERATIONS ($MAX_ITERATIONS) reached. Some stories may remain incomplete."
echo "Run again to continue."
exit 1
