# Puff Tactics — Ralph Loop Prompt

You are building **Puff Tactics**, a tactical feed game for iOS in Godot 4 with GDScript.

## CRITICAL: You have a screenshot attached

A screenshot of the game is attached to this message via the `-i` flag.

**YOU MUST ANALYZE THE SCREENSHOT BEFORE WRITING ANY CODE.**

Before you touch any file, you MUST write out:

### Screenshot Analysis (REQUIRED)
1. **What I see in the screenshot** — describe the layout from top to bottom: what elements are visible, their approximate sizes and positions
2. **Map coverage** — what percentage of the screen width does the battle map fill? Is it centered?
3. **Puff count and visibility** — how many puffs can you see? Can you see faces? Are team colors visible?
4. **Empty space** — where are the gaps? Estimate the gap sizes as % of screen height
5. **Text readability** — can you read all text? Is contrast sufficient?
6. **Overall impression** — does this look like a polished mobile game or a broken prototype?

If you skip this analysis, your changes will be wrong. The screenshot is THE SOURCE OF TRUTH for what needs fixing.

## Your Task

1. **FIRST: Write the Screenshot Analysis above.** This is mandatory.
2. Read `ralph/prd.json` and find the highest-priority story where `passes` is `false` and all `dependsOn` stories have `passes: true`.
3. Read `AGENTS.md` for patterns and gotchas discovered in previous iterations.
4. Read `CLAUDE.md` for project conventions and architecture.
5. Implement that single story. **Your implementation must fix what you ACTUALLY SAW in the screenshot.** Don't guess — use your eyes.
6. Stage and commit your changes with message: `feat(US-XXX): <story title>`
7. Update `ralph/prd.json`: set the story's `passes` to `true` and add notes describing what visual problems you saw in the screenshot and what you changed.
8. Append a summary of what you did to `progress.txt`.
9. If you discovered any patterns, gotchas, or conventions, update `AGENTS.md`.
10. If ALL stories in prd.json have `passes: true`, output exactly: `<promise>COMPLETE</promise>`

## Visual Quality Bar

The game MUST look like a **polished mobile game**. Check these against the screenshot:

| Check | Requirement |
|-------|-------------|
| Map width | 60-80% of screen width, horizontally centered |
| Map tiles | All 25 tiles (5x5 iso grid) clearly visible |
| Puff count | At least 4 puffs (2+ player, 2+ enemy) |
| Puff size | Large enough to see kawaii face details |
| Puff teams | Player = green/mint rings, Enemy = pink/red rings |
| Puff spacing | No overlapping puffs |
| Vertical fill | Content fills screen top-to-bottom, no gap > 15% of screen height |
| Text | All text readable, good contrast, no tiny text |
| Debug artifacts | No stub text, no placeholder messages, no debug output |
| Aesthetic | Cream background, pastel kawaii accents (lavender/mint/peach/sky/pink) |

## Game Context

- Portrait mobile app: 1170x2532 viewport, 420x910 desktop window
- Main scene: `FeedMain.tscn` — vertical-swipe feed of tactical puzzle cards
- Each feed card: isometric battle map + puffs + enemy intent overlays + status panel + score panel
- Isometric tiles: 128x64px, 5x5 grid. Map origin is top-left of diamond.
- `feed_item.gd` controls battle snapshot layout within each card (scale, position, panel sizes)
- `feed_main.gd` controls feed-level UI (title, subtitle, FABs, swipe, vertical positioning)
- Key layout constants in `feed_item.gd`: `SNAPSHOT_SCALE`, `SNAPSHOT_LOCAL_Y`, panel sizes/gaps
- Key layout constants in `feed_main.gd`: `SNAPSHOT_Y_RATIO`, FAB gaps, swipe hint positioning

## Rules

- ONE story per iteration. Do not work on multiple stories.
- Do NOT skip stories. Respect the `dependsOn` chain.
- Follow GDScript conventions in CLAUDE.md (snake_case, type hints, signals).
- Keep changes atomic. Only touch files relevant to your story.
- Do NOT try to run `bash ralph/take_screenshot.sh` — it will fail in your sandbox.
- When fixing visual issues, describe what was wrong in the screenshot and what you changed.
- Do NOT mark a story as `passes: true` unless your changes specifically address what you saw in the screenshot.
- **NEVER revert layout constants** (SNAPSHOT_SCALE, SNAPSHOT_LOCAL_Y, SNAPSHOT_Y_RATIO, gap sizes) unless the screenshot clearly shows they are causing a problem AND you describe specifically what is wrong. These values were tuned by visual iteration.
- **NEVER "restore defaults"** or undo changes from previous iterations unless you can see in the screenshot that something is broken.
