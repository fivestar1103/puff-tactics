# AGENTS.md — Puff Tactics

Learnings and patterns discovered during development. Updated after each Ralph loop iteration.
AI coding agents read this file automatically. Keep entries concise and actionable.

## Codebase Patterns

<!-- Add patterns as they are discovered during development -->
<!-- Examples:
- "Use SignalBus.emit('feed_item_completed', score) for cross-system events"
- "Tilemap coordinates use Vector2i, world positions use Vector2"
- "All Supabase responses must be checked for .error before using .data"
-->
- "Global gameplay enums/constants live in `src/scripts/core/constants.gd` and are provided via `Constants` autoload."
- "Cross-system events are centralized in `src/scripts/core/signal_bus.gd` as the `SignalBus` autoload."
- "`BattleMap` terrain data is loaded via `load_map_from_config()` (`rows` or `cells`) or `load_map_from_json()` for procedural snapshots."
- "Base puff archetypes are `PuffData` `.tres` files in `src/resources/puffs/base/`; `src/scripts/puffs/puff.gd` reads these resources to render placeholder puffs."

## Gotchas

- "NEVER use `class_name X` on autoload scripts — it conflicts with the singleton name. Autoloads are already accessible globally (e.g. `Constants.FIRE`, `SignalBus.emit(...)`) without class_name."
- "Godot 4 TileMap uses layers (TileMapLayer), not separate TileMap nodes"
- "Godot 4.3 is available as `godot`; for syntax checks in this repo use `godot --headless --path /home/fives/projects/puff-tactics --check-only --script <gd_file>` per script (main scene is not present yet)."
- "GDScript `const` dictionaries must use literal arrays; constructor calls like `PackedStringArray()` are not valid constant expressions."

## Conventions

- GDScript: snake_case functions/variables, PascalCase classes/nodes
- Signals over direct references; use SignalBus autoload
- Type hints on all function signatures
- One story per commit, atomic changes
- Test scenes in `src/scenes/test/` (not committed to main)

## File Reference

<!-- Add key file locations as the project grows -->
<!-- Examples:
- "Game state machine: src/scripts/core/game_state.gd"
- "Feed controller: src/scripts/feed/feed_controller.gd"
-->
- "Core constants: src/scripts/core/constants.gd"
- "Global signals: src/scripts/core/signal_bus.gd"
- "Battle map terrain system: src/scripts/core/battle_map.gd"
- "Battle map scene: src/scenes/maps/BattleMap.tscn"

## Supabase Notes

<!-- Add Supabase-specific learnings -->
<!-- Examples:
- "RLS policies require auth.uid() check on all user-scoped tables"
- "Edge Functions timeout at 60s — keep puzzle generation batches small"
-->
