# Puff Tactics

Tactical feed game for iOS. "Swipe like Shorts, solve like puzzles, addicted by cuteness."

## Tech Stack

- **Engine**: Godot 4.3+ (GDScript)
- **Backend**: Supabase (Auth, PostgreSQL, Edge Functions, Storage, Realtime)
- **Platform**: iOS (StoreKit 2, Apple Sign-In)
- **Art**: AI-generated pastel kawaii sprites (256x256 puffs, 128x64 isometric tiles)
- **Version Control**: Git + GitHub

## Project Structure

```
src/
  scenes/       # .tscn scene files grouped by feature
    feed/       # Feed swipe UI, feed items
    battle/     # Full match battle scenes
    ui/         # Shared UI components
    puffs/      # Puff character scenes
    maps/       # Tilemap scenes
  scripts/      # .gd script files grouped by system
    core/       # Game manager, state machine, constants
    feed/       # Feed logic, swipe controller, scoring
    battle/     # Turn system, bump physics, combat
    ai/         # Utility AI, enemy behavior, PvP ghost AI
    puffs/      # Puff stats, classes, accessories
    ui/         # UI controllers, animations
    network/    # Supabase client, API calls, auth
    utils/      # Helpers, procedural generation
  resources/    # .tres resource files
assets/         # Raw art/audio assets
  sprites/      # Puff sprites, tiles, UI elements, accessories, backgrounds
  audio/        # SFX and music
  fonts/        # Custom fonts
```

## Key Architecture Decisions

- **Feed-first**: App opens directly to tactical feed, no menus. 0-second cold start.
- **1-turn micro-puzzles**: Each feed item is a single turn decision (15-30 seconds).
- **Bump mechanic**: Core differentiator. All puffs can push adjacent units. Chain bumps possible. Cliff falls = 1-turn knockout.
- **Into the Breach-style info**: Enemy next actions shown as transparent overlays. Strategy over luck.
- **Async PvP**: No real-time networking. Store opponent team + AI pattern, challenger plays vs AI ghost.
- **Vertical swipe UI**: TikTok/Shorts-style swipe between feed items.

## Coding Conventions

- GDScript style: snake_case for functions/variables, PascalCase for classes/nodes
- Signals over direct references. Use signal bus (autoload) for cross-system communication.
- Prefer composition (child nodes) over deep inheritance
- Type hints on all function signatures: `func move_puff(puff: Puff, target: Vector2i) -> bool:`
- Constants in `src/scripts/core/constants.gd` (autoload)
- All network calls go through `src/scripts/network/supabase_client.gd`
- Scene files (.tscn) and their scripts (.gd) live in matching directories

## Puff System

5 elements: Fire > Grass > Wind > Water > Fire (cycle). Star is neutral.
6 base classes: Tank, Melee DPS, Ranged, Healer, Mobility/Utility, Wildcard.
Each puff has: class, element, move range, attack range, unique skill, accessories.

## Ralph Loop

This project uses the Ralph loop methodology for autonomous development.
- `ralph/prd.json` — User stories with acceptance criteria and pass/fail status
- `ralph/prompt.md` — The prompt fed to the agent each iteration
- `ralph/ralph.sh` — The bash loop runner
- `progress.txt` — Cumulative log of completed work
- `AGENTS.md` — Discovered patterns, gotchas, conventions

Each iteration: read PRD → pick next unpassed story → implement → commit → update progress → exit.

## Quality Gates

- `gdlint` for GDScript linting (when available)
- Scene files must be parseable (no broken references)
- All scripts must have no syntax errors (verified via Godot --check-only when available)
- Commits must be atomic: one story per commit
