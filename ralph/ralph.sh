#!/usr/bin/env bash
# Ralph Loop — Puff Tactics
# Runs Claude Code (or Codex) in a loop until all PRD stories pass.
# Usage: ./ralph/ralph.sh [max_iterations]

set -euo pipefail

MAX_ITERATIONS="${1:-50}"
PROMPT_FILE="ralph/prompt.md"
PRD_FILE="ralph/prd.json"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

# Validate setup
if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: $PROMPT_FILE not found"
  exit 1
fi

if [ ! -f "$PRD_FILE" ]; then
  echo "ERROR: $PRD_FILE not found"
  exit 1
fi

if ! command -v claude &> /dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH"
  exit 1
fi

PROMPT_CONTENT=$(cat "$PROMPT_FILE")

echo "========================================="
echo "  RALPH LOOP — Puff Tactics"
echo "  Max iterations: $MAX_ITERATIONS"
echo "========================================="

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "--- Iteration $i / $MAX_ITERATIONS ---"
  echo "$(date '+%Y-%m-%d %H:%M:%S')"

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
    exit 0
  fi

  echo "Remaining stories: $INCOMPLETE"

  # Run Claude with the prompt
  OUTPUT=$(claude --dangerously-skip-permissions --print "$PROMPT_CONTENT" 2>&1) || true

  echo "$OUTPUT" | tail -20

  # Check for completion promise
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "RALPH COMPLETE — All stories passed!"
    exit 0
  fi

  echo "--- Iteration $i done ---"
  sleep 2
done

echo ""
echo "MAX ITERATIONS ($MAX_ITERATIONS) reached. Some stories may remain incomplete."
echo "Run again to continue."
exit 1
