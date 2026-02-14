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
- "`TurnManager` phase flow is `player_select -> player_action -> resolve -> enemy_action -> resolve -> player_select`; movement range overlays are drawn in `_draw()` from tilemap cell centers."
- "`src/scripts/battle/bump_system.gd` resolves bump chains from tail to head; `TurnManager` applies pushes and treats any pushed puff standing on `cliff` terrain as a 1-turn stun using `_stun_state_by_puff_id` + team-turn recovery."
- "Enemy intent overlays use `TurnManager.get_enemy_intent_snapshot()` (same plan logic used by enemy execution) and refresh from `phase_changed` plus `SignalBus` board-state events (`puff_moved`, `puff_bumped`, `turn_ended`)."
- "Enemy planning is centralized through `src/scripts/ai/utility_ai.gd`; `TurnManager` builds legal wait/move/attack/skill candidates per enemy and selects the max-utility intent using weighted factors (`attack_value`, `survival_risk`, `positional_advantage`, `bump_opportunity`) exposed as TurnManager exports for difficulty tuning."
- "`src/scripts/feed/feed_item.gd` now owns interactive feed-card micro-puzzle flow: snapshot load (`map_config` + `puffs` + `enemy_intents`), 15-30s decision window, fixed 3s resolve + 2s score phases, and swipe unlock via `can_advance_to_next_item()` that `feed_main.gd` checks before allowing page transitions."
- "`src/scripts/utils/puzzle_generator.gd` builds four template puzzles with difficulty-scaled terrain/unit placement and returns JSON-safe feed snapshots (`cell` values serialized as `{x,y}`) that include `puzzle_meta.validation` from an internal one-turn action simulation."
- "Supabase network/auth access is centralized in `src/scripts/network/supabase_client.gd` as the `SupabaseClient` autoload; configure `puff_tactics/supabase/url` and `puff_tactics/supabase/publishable_key` in `project.godot`."
- "`src/scripts/network/feed_sync.gd` handles `feed_items` batch sync (limit 50), JSON cache + pending score queue files in `user://feed_cache/`, and `feed_main.gd` now renders cached snapshots first then fetches the next batch in the background."
- "`src/scenes/battle/FullBattle.tscn` uses `TurnManager.auto_begin_turn_cycle = false` and starts turn flow with `begin_turn_cycle()` only after roster selection; tile-control victories call `TurnManager.end_battle()` and logs persist to `user://battle_logs/*.json` for downstream moment extraction."
- "`TurnManager` emits `action_resolved(side, action_payload)` for move/attack/skill outcomes; `full_battle.gd` records per-turn `player_turn_snapshot` + `player_action_result` and stores `turn_summaries` so `src/scripts/utils/moment_extractor.gd` can build feed-ready decisive-moment snapshots."
- "Async PvP orchestration is centralized in `src/scripts/network/pvp_async.gd`; `full_battle.gd` calls it before match start to fetch nearest-ELO leaderboard opponents and apply ghost `team_paths` + AI weights, then calls it after battle end to upload the player's ghost and submit PvP result/ELO updates."
- "Progression/accessories are centralized in `src/scripts/puffs/puff_progression.gd` (`PuffProgression` autoload); player puff spawns should use `build_runtime_puff_data(data_path)` so level/XP and equipped gear bonuses apply in feed and battle contexts."
- "`src/scenes/puffs/Puff.tscn` includes `HatSprite`, `ScarfSprite`, and `RibbonSprite` overlay layers; `src/scripts/puffs/puff.gd` renders equipped accessory visuals from `PuffData.get_equipped_accessories()`."
- "`src/scenes/ui/PuzzleEditor.tscn` + `src/scripts/ui/puzzle_editor.gd` handle UGC authoring: drag terrain painting + puff drag/drop placement, per-puff team/element/class controls, template objective metadata, and FeedItem-gated test-play that must pass before Supabase `ugc_puzzles` publish is enabled."

## Gotchas

- "NEVER use `class_name X` on autoload scripts — it conflicts with the singleton name. Autoloads are already accessible globally (e.g. `Constants.FIRE`, `SignalBus.emit(...)`) without class_name."
- "Godot 4 TileMap uses layers (TileMapLayer), not separate TileMap nodes"
- "Godot 4.3 is available as `godot`; for syntax checks in this repo use `godot --headless --path /home/fives/projects/puff-tactics --check-only --script <gd_file>` per script (main scene is not present yet)."
- "GDScript `const` dictionaries must use literal arrays; constructor calls like `PackedStringArray()` are not valid constant expressions."
- "When instantiating children from a node's `_ready()`, adding to a parent/sibling can hit `Parent node is busy setting up children`; use `call_deferred()` for spawn/setup."
- "`godot --check-only --script` can fail to resolve cross-file `class_name` references in isolation; preload helper scripts (e.g. `const X_SCRIPT = preload(...); X_SCRIPT.new()`) for deterministic syntax checks."

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
- "Bump logic: src/scripts/battle/bump_system.gd"
- "Async PvP sync/matchmaking: src/scripts/network/pvp_async.gd"

## Supabase Notes

<!-- Add Supabase-specific learnings -->
<!-- Examples:
- "RLS policies require auth.uid() check on all user-scoped tables"
- "Edge Functions timeout at 60s — keep puzzle generation batches small"
-->
- "Supabase auth state is encrypted in `user://auth/supabase_auth.dat`; token refresh is scheduled ~60s before expiry and also checked before each API request."
