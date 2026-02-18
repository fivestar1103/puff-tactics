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
- "`src/scripts/feed/feed_main.gd` normalizes all fallback/cached/network snapshots through `_normalize_snapshot_for_feed()` so feed cards always have at least 2 player and 2 enemy puffs, no overlapping spawn cells, and a fallback enemy intent when authored intent data is missing."
- "`feed_item.gd` score overlay computes from enemies defeated, damage dealt, allies surviving, and turns used; decisive snapshots (`moment_meta`) render original-player comparison text while regular feed puzzles render community percentile plus a Share-button stub."
- "`src/scripts/utils/puzzle_generator.gd` builds four template puzzles with difficulty-scaled terrain/unit placement and returns JSON-safe feed snapshots (`cell` values serialized as `{x,y}`) that include `puzzle_meta.validation` from an internal one-turn action simulation."
- "Supabase network/auth access is centralized in `src/scripts/network/supabase_client.gd` as the `SupabaseClient` autoload; configure `puff_tactics/supabase/url` and `puff_tactics/supabase/publishable_key` in `project.godot`."
- "`src/scripts/network/feed_sync.gd` handles `feed_items` batch sync (limit 50), JSON cache + pending score queue files in `user://feed_cache/`, and `feed_main.gd` now renders cached snapshots first then fetches the next batch in the background."
- "`src/scenes/battle/FullBattle.tscn` uses `TurnManager.auto_begin_turn_cycle = false` and starts turn flow with `begin_turn_cycle()` only after roster selection; tile-control victories call `TurnManager.end_battle()` and logs persist to `user://battle_logs/*.json` for downstream moment extraction."
- "`TurnManager` emits `action_resolved(side, action_payload)` for move/attack/skill outcomes; `full_battle.gd` records per-turn `player_turn_snapshot` + `player_action_result` and stores `turn_summaries` so `src/scripts/utils/moment_extractor.gd` can build feed-ready decisive-moment snapshots."
- "Async PvP orchestration is centralized in `src/scripts/network/pvp_async.gd`; `full_battle.gd` calls it before match start to fetch nearest-ELO leaderboard opponents and apply ghost `team_paths` + AI weights, then calls it after battle end to upload the player's ghost and submit PvP result/ELO updates."
- "Progression/accessories are centralized in `src/scripts/puffs/puff_progression.gd` (`PuffProgression` autoload); player puff spawns should use `build_runtime_puff_data(data_path)` so level/XP and equipped gear bonuses apply in feed and battle contexts."
- "`src/scenes/puffs/Puff.tscn` includes `HatSprite`, `ScarfSprite`, and `RibbonSprite` overlay layers; `src/scripts/puffs/puff.gd` renders equipped accessory visuals from `PuffData.get_equipped_accessories()`."
- "Puff animation feedback is centralized in `src/scripts/ui/puff_animator.gd`; `TurnManager` drives move/attack/bump/defeat/recovery tweens through this helper and uses `_is_action_locked` to block duplicate inputs during active action animations."
- "Puff team ring visuals depend on `Puff.team` (via `set_team()`); spawn/update call sites should set team before/after `Puff` visual build to avoid default team fallback."
- "`src/scenes/ui/PuzzleEditor.tscn` + `src/scripts/ui/puzzle_editor.gd` handle UGC authoring: drag terrain painting + puff drag/drop placement, per-puff team/element/class controls, template objective metadata, and FeedItem-gated test-play that must pass before Supabase `ugc_puzzles` publish is enabled."
- "Story campaign flow is orchestrated by `src/scripts/story/story_chapter_1.gd`, which runs scripted `FullBattle.start_scripted_battle(...)` scenarios and advances dialogue/tutorial beats from `battle_completed` + `player_action_resolved`."
- "Register `VisualTheme` as an autoload and use its StyleBox helpers for consistent label/button/panel styling across feed, battle, story, and editor screens."
- "BattleMap builds terrain tile art in `src/scripts/core/battle_map.gd::_create_terrain_texture()` via direct `Image` drawing: base gradient fill plus per-terrain symbols and cliff-specific border treatment are applied at atlas generation time."
- "`TurnManager` now emits `battle_ended(winner)` in addition to `SignalBus` bus events; hook HUD-layer result UI to this signal for scene-local outcome updates."
- "`src/scripts/ai/enemy_intent.gd` should render movement/skill intents with actor->target arrows and attack intents with crosshair/X overlays to keep intent direction and impact clear."
- "Keep `src/scripts/ai/enemy_intent.gd` overlays subdued in feed snapshots (fill alpha around ~0.16, border/arrow alpha ~0.74-0.82, line widths ~1.5-3.0) so intent cues stay clear without overpowering map tiles."
- "CollectionScreen and PuzzleEditor UI style is driven from script with VisualTheme helpers (`create_panel_stylebox`, `apply_button_theme`, `apply_label_theme`) in `_ready()`-time setup for consistent button and panel treatment."
- "`src/scripts/feed/feed_item.gd::_layout_battle_snapshot()` centers TurnBattle feed snapshots by applying a negative X offset of half the isometric map width (scaled), compensating for the map origin being top-left."
- "Portrait feed spacing is tuned by `src/scripts/feed/feed_main.gd` (`SNAPSHOT_Y_RATIO`, `SWIPE_HINT_GAP_RATIO`, `SWIPE_HINT_GAP_MIN`) plus `src/scripts/feed/feed_item.gd` `SNAPSHOT_LOCAL_Y`; adjust these together when rebalancing header/map/hint/FAB vertical flow."
- "`src/scripts/feed/feed_item.gd` now anchors status/score overlays to map bounds (`STATUS_PANEL_MAP_GAP`, `SCORE_PANEL_MAP_GAP`) in `_layout_battle_snapshot()`; prefer map-relative panel spacing over fixed Y offsets when retuning feed-card layout."
- "When map tiles read too faint in feed, improve clarity via `feed_item.gd` map-backdrop treatment (`_create_map_backdrop_pattern_texture()` + `_layout_map_backdrop()` padding) before changing protected snapshot layout constants."
- "When tightening header-to-map spacing, tune `STATUS_PANEL_SIZE.y` with `STATUS_PANEL_MAP_GAP` together: the status panel is map-anchored, so panel height directly controls subtitle->status visual gap while preserving map-relative placement."
- "FeedMain should run a deferred `_layout_hud_overlays()` after activating the first card; otherwise initial HUD placement can miss `FeedItem` score panel bounds (not ready yet) and fall back to bottom anchoring, creating a large middle empty gap."
- "For a 5x5 isometric board using 128x64 tiles, feed map width is ~`640 * SNAPSHOT_SCALE.x`; target `SNAPSHOT_SCALE` around `1.37-1.55` for a 75-85% fill of a 1170px portrait viewport."
- "Keep `src/scripts/feed/feed_main.gd` `SNAPSHOT_Y_RATIO` near `0.16-0.22`; drifting toward `0.40+` pushes the whole feed card stack too low and creates an oversized subtitle-to-status empty zone on portrait layouts."
- "`src/scripts/feed/feed_main.gd::_build_visual_atmosphere()` adds non-interactive pastel ambient blobs + a header card so tall portrait whitespace reads intentional when layout constants are locked."
- "`src/scripts/feed/feed_item.gd` feed card polish should prefer style upgrades (`_build_card_stylebox()`, `_ensure_map_backdrop()`, elevated status/score panels) before touching protected spacing constants."
- "`src/scripts/feed/feed_item.gd` status panel polish should stay in the frosted range (panel alpha ~0.82 with a subtle top-to-bottom gradient/pattern) and status width should track map bounds (`map_width + ~20px`) for clean map/panel alignment."
- "For feed UI depth consistency, keep status/score panels (`feed_item.gd`) and FAB button state styleboxes (`feed_main.gd`) on the same elevation profile: ~26px corners for cards, 1-2px pastel borders, and subtle shadows (size ~10, y-offset ~3, alpha ~0.12)."
- "`src/scripts/feed/feed_main.gd` FAB polish should derive each button's corner radius from its current minimum height (`height/2`) and set stylebox content margins (~18px horizontal, ~12px vertical) so pill geometry and label padding remain consistent across Profile/Create/Leaderboard."
- "Feed typography hierarchy should stay explicit: `feed_item.gd` status headline/detail near 33/22 with detail alpha ~0.90, score text near 29/52/19/21; `feed_main.gd` swipe hint should stay low-emphasis (~18px, alpha 0.5-0.7) while FAB labels remain in the 20-22 range."
- "Feed header/status/error copy should stay player-facing; avoid implementation-detail wording like `scene unavailable`, `failed to initialize`, or build-state messages in visible subtitles."
- "`src/scripts/feed/feed_main.gd` swipe hint visibility should follow the active card state via `FeedItem.should_show_swipe_hint()`; when hidden, hide both label+panel and stop the chevron tween so locked turns never show swipe affordance."

## Gotchas

- "NEVER use `class_name X` on autoload scripts — it conflicts with the singleton name. Autoloads are already accessible globally (e.g. `Constants.FIRE`, `SignalBus.emit(...)`) without class_name."
- "Godot 4 TileMap uses layers (TileMapLayer), not separate TileMap nodes"
- "Godot 4.3 is available as `godot`; for syntax checks in this repo use `godot --headless --path /home/fives/projects/puff-tactics --check-only --script <gd_file>` per script (main scene is not present yet)."
- "GDScript `const` dictionaries must use literal arrays; constructor calls like `PackedStringArray()` are not valid constant expressions."
- "When instantiating children from a node's `_ready()`, adding to a parent/sibling can hit `Parent node is busy setting up children`; use `call_deferred()` for spawn/setup."
- "`godot --check-only --script` can fail to resolve cross-file `class_name` references in isolation; preload helper scripts (e.g. `const X_SCRIPT = preload(...); X_SCRIPT.new()`) for deterministic syntax checks."
- "`godot --headless --check-only --script` can also report `Identifier not found` for autoload singletons (e.g. `VisualTheme`) when scripts are checked in isolation; prefer `godot --headless --scene <scene> --quit` parse checks for autoload-heavy UI scenes."
- "Keep the new `VisualTheme` utility methods in sync with accepted button style state keys (`normal`, `hover`, `pressed`, `disabled`) and font override usage."
- "`bash ralph/take_screenshot.sh` can crash in sandboxed Linux shells unless `HOME` points to a writable directory (e.g. `HOME=/tmp`) because Godot writes `user://logs/*` before scene boot."
- "For `Control` overlays parented to `Node2D` (FeedItem map/status/score panels), avoid `size` + `position` layout math; set anchors to 0 and write `offset_left/top/right/bottom` explicitly (see `_set_control_rect()` in `feed_item.gd`) to prevent runaway panel sizes and broken vertical spacing."

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
- "Collection UI styling: src/scripts/ui/collection_screen.gd"
- "UGC editor styling: src/scripts/ui/puzzle_editor.gd"

## Supabase Notes

<!-- Add Supabase-specific learnings -->
<!-- Examples:
- "RLS policies require auth.uid() check on all user-scoped tables"
- "Edge Functions timeout at 60s — keep puzzle generation batches small"
-->
- "Supabase auth state is encrypted in `user://auth/supabase_auth.dat`; token refresh is scheduled ~60s before expiry and also checked before each API request."

- "FeedMain UI uses VisualTheme.apply_label_theme() for title/subtitle/small labels and VisualTheme.apply_button_theme() for profile/create/leaderboard FABs to keep feed styling consistent."

## Visual Verification

- "Screenshot tool: `bash ralph/take_screenshot.sh` launches Godot with `-- --screenshot`, waits 4s, captures viewport to `ralph/screenshots/latest.png`, then quits. Requires DISPLAY (WSLg provides this)."
- "`ScreenshotTool` autoload in `ralph/screenshot_tool.gd` checks `OS.get_cmdline_user_args()` for `--screenshot`; if absent, it calls `queue_free()` immediately and has zero runtime cost in normal play."
- "Isometric map origin is top-left of the grid; the map extends right and down. When centering the battle in a feed card, apply a negative X offset to `_battle_root.position` to compensate."
- "BattleHUD uses CanvasLayer which renders globally over the entire window, not relative to the battle Node2D. In feed snapshot mode, hide or remove the HudLayer to prevent HUD elements from overlapping feed-level UI."
- "Feed card layout: FeedItem is placed at `(viewport.x * 0.5, page_offset + viewport.y * 0.34)`. The battle_root within FeedItem starts at local (0,0). Isometric tile_size is 128x64 for a 5x5 grid."
