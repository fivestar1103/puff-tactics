extends Node2D
class_name FeedItem

signal cycle_completed(score: int, cycle_duration_seconds: float)
signal status_changed(status_text: String, swipe_unlocked: bool)

const TURN_BATTLE_SCENE: PackedScene = preload("res://src/scenes/battle/TurnBattle.tscn")
const PUFF_SCENE: PackedScene = preload("res://src/scenes/puffs/Puff.tscn")
const PUFF_DATA_SCRIPT: GDScript = preload("res://src/scripts/puffs/puff_data.gd")

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"
const PHASE_RESOLVE: StringName = &"resolve"

const MIN_DECISION_SECONDS: float = 15.0
const MAX_DECISION_SECONDS: float = 30.0
const RESULT_PHASE_SECONDS: float = 3.0
const SCORE_PHASE_SECONDS: float = 2.0
const SCORE_REVEAL_DURATION: float = 1.1

const SNAPSHOT_SCALE: Vector2 = Vector2(1.65, 1.65)
const SNAPSHOT_LOCAL_Y: float = -220.0
const SNAPSHOT_BOUNDS_FALLBACK_SIZE: Vector2 = Vector2(640.0, 320.0)
const STATUS_PANEL_SIZE: Vector2 = Vector2(804.0, 228.0)
const STATUS_PANEL_MAP_GAP: float = 8.0
const STATUS_PANEL_FALLBACK_LOCAL_Y: float = -120.0
const SCORE_PANEL_SIZE: Vector2 = Vector2(804.0, 280.0)
const SCORE_PANEL_MAP_GAP: float = 10.0
const SCORE_PANEL_FALLBACK_LOCAL_Y: float = 300.0
const DEFAULT_TARGET_SCORE: int = 230
const MOMENT_FEED_ITEM_PREFIX: String = "moment_"

const SCORE_ENEMY_DEFEATED_POINTS: int = 140
const SCORE_DAMAGE_POINTS_PER_HP: int = 5
const SCORE_SURVIVAL_POINTS: int = 45
const SCORE_TURN_EFFICIENCY_POINTS: int = 20
const SCORE_TURN_BASELINE: int = 4

const SCORE_FALLBACK_PERCENTILE_FACTOR: float = 0.36

const ORIGINAL_SCORE_KEYS: Array = [
	"original_player_score",
	"original_score",
	"benchmark_score",
	"source_score"
]

const COMMUNITY_SCORE_KEYS: Array = [
	"community_score_samples",
	"community_scores",
	"score_samples"
]

const DEFAULT_SNAPSHOT: Dictionary = {
	"map_config": {
		"width": 5,
		"height": 5,
		"rows": [
			["cloud", "cloud", "high_cloud", "cloud", "cloud"],
			["cloud", "puddle", "cloud", "mushroom", "cloud"],
			["cotton_candy", "cloud", "cliff", "cloud", "high_cloud"],
			["cloud", "mushroom", "cloud", "puddle", "cloud"],
			["cloud", "cloud", "high_cloud", "cloud", "cloud"]
		]
	},
	"puffs": [
		{
			"name": "Flame_Lead",
			"team": TEAM_PLAYER,
			"data_path": "res://src/resources/puffs/base/flame_melee.tres",
			"cell": Vector2i(1, 3)
		},
		{
			"name": "Leaf_Ally",
			"team": TEAM_PLAYER,
			"data_path": "res://src/resources/puffs/base/leaf_healer.tres",
			"cell": Vector2i(0, 2)
		},
		{
			"name": "Cloud_Guard",
			"team": TEAM_ENEMY,
			"data_path": "res://src/resources/puffs/base/cloud_tank.tres",
			"cell": Vector2i(3, 2)
		},
		{
			"name": "Droplet_Backline",
			"team": TEAM_ENEMY,
			"data_path": "res://src/resources/puffs/base/droplet_ranged.tres",
			"cell": Vector2i(4, 1)
		}
	],
	"enemy_intents": [
		{
			"action": &"skill",
			"actor_cell": Vector2i(3, 2),
			"move_cell": Vector2i(3, 2),
			"target_cell": Vector2i(1, 3),
			"skill_cells": [Vector2i(2, 3), Vector2i(3, 3)],
			"direction": Vector2i(-1, 0)
		},
		{
			"action": &"move",
			"actor_cell": Vector2i(4, 1),
			"move_cell": Vector2i(3, 1),
			"target_cell": Vector2i(3, 1),
			"skill_cells": [],
			"direction": Vector2i.ZERO
		}
	],
	"target_score": DEFAULT_TARGET_SCORE
}

var _snapshot: Dictionary = DEFAULT_SNAPSHOT.duplicate(true)

var _battle_root: Node2D
var _battle_map: BattleMap
var _turn_manager: TurnManager
var _enemy_intent: EnemyIntent

var _card_backdrop: PanelContainer
var _status_panel: PanelContainer
var _status_label: Label
var _detail_label: Label
var _score_panel: PanelContainer
var _score_title_label: Label
var _score_value_label: Label
var _score_breakdown_label: Label
var _score_comparison_label: Label
var _share_button: Button
var _share_stub_label: Label
var _decision_timeout_timer: Timer

var _puff_team_by_id: Dictionary = {}
var _initial_enemy_count: int = 0
var _initial_player_count: int = 0
var _player_damage_dealt: int = 0
var _player_turns_used: int = 0
var _resolved_player_turn_numbers: Dictionary = {}

var _is_active: bool = false
var _decision_started: bool = false
var _decision_locked: bool = false
var _cycle_done: bool = false

var _decision_start_time_seconds: float = 0.0
var _decision_lock_time_seconds: float = 0.0
var _cycle_completion_time_seconds: float = 0.0


func configure_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if is_node_ready():
		_rebuild_battle_snapshot()


func set_interaction_enabled(enabled: bool) -> void:
	_is_active = enabled
	if _turn_manager == null:
		return

	if _cycle_done or _decision_locked:
		_turn_manager.set_process_unhandled_input(false)
		return

	if enabled and not _decision_started:
		_begin_decision_phase()

	_turn_manager.set_process_unhandled_input(enabled and _decision_started and not _decision_locked)


func is_cycle_complete() -> bool:
	return _cycle_done


func can_advance_to_next_item() -> bool:
	return _cycle_done


func get_status_text() -> String:
	if _status_label == null:
		return ""
	return _status_label.text


func get_score_panel_bottom_global_y() -> float:
	if _score_panel == null:
		return NAN
	var local_bottom: Vector2 = _score_panel.position + Vector2(0.0, _score_panel.size.y)
	return to_global(local_bottom).y


func _ready() -> void:
	_build_card_backdrop()
	_build_status_overlay()
	_setup_decision_timeout_timer()
	_rebuild_battle_snapshot()


func _build_card_backdrop() -> void:
	_card_backdrop = PanelContainer.new()
	_card_backdrop.name = "CardBackdrop"
	_card_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_backdrop)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.30, 0.42, 0.06)
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_right = 28
	style.corner_radius_bottom_left = 28
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.50, 0.50, 0.60, 0.12)
	_card_backdrop.add_theme_stylebox_override("panel", style)


func _layout_card_backdrop() -> void:
	if _card_backdrop == null or _status_panel == null or _score_panel == null:
		return
	var top_y: float = _status_panel.position.y - 16.0
	var bottom_y: float = _score_panel.position.y + _score_panel.size.y + 16.0
	var panel_width: float = maxf(_status_panel.size.x, _score_panel.size.x) + 32.0
	_card_backdrop.position = Vector2(-panel_width * 0.5, top_y)
	_card_backdrop.custom_minimum_size = Vector2(panel_width, bottom_y - top_y)
	_card_backdrop.size = Vector2(panel_width, bottom_y - top_y)


func _build_status_overlay() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.name = "StatusPanel"
	_layout_status_overlay()
	add_child(_status_panel)

	var status_style: StyleBoxFlat = StyleBoxFlat.new()
	status_style.bg_color = Color(0.08, 0.11, 0.19, 0.72)
	status_style.corner_radius_top_left = 20
	status_style.corner_radius_top_right = 20
	status_style.corner_radius_bottom_right = 20
	status_style.corner_radius_bottom_left = 20
	status_style.content_margin_left = 24.0
	status_style.content_margin_right = 24.0
	status_style.content_margin_top = 20.0
	status_style.content_margin_bottom = 20.0
	status_style.border_width_left = 1
	status_style.border_width_top = 1
	status_style.border_width_right = 1
	status_style.border_width_bottom = 1
	status_style.border_color = Color(0.45, 0.58, 0.85, 0.35)
	_status_panel.add_theme_stylebox_override("panel", status_style)

	var status_vbox: VBoxContainer = VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 8)
	_status_panel.add_child(status_vbox)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.add_theme_font_size_override("font_size", 30)
	_status_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
	status_vbox.add_child(_status_label)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_label.add_theme_font_size_override("font_size", 21)
	_detail_label.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0, 0.80))
	status_vbox.add_child(_detail_label)

	_build_score_overlay()

	_set_status(
		"Your turn: move, attack, or bump",
		"Take your time and plan a one-turn masterpiece."
	)


func _build_score_overlay() -> void:
	_score_panel = PanelContainer.new()
	_score_panel.name = "ScorePanel"
	_layout_score_overlay()
	_score_panel.visible = false
	add_child(_score_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.17, 0.90)
	panel_style.corner_radius_top_left = 28
	panel_style.corner_radius_top_right = 28
	panel_style.corner_radius_bottom_right = 28
	panel_style.corner_radius_bottom_left = 28
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.53, 0.74, 0.98, 0.9)
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_bottom = 20.0
	_score_panel.add_theme_stylebox_override("panel", panel_style)

	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 8)
	_score_panel.add_child(root_layout)

	_score_title_label = Label.new()
	_score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_title_label.add_theme_font_size_override("font_size", 30)
	_score_title_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	_score_title_label.text = "Score Breakdown"
	root_layout.add_child(_score_title_label)

	_score_value_label = Label.new()
	_score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_value_label.add_theme_font_size_override("font_size", 56)
	_score_value_label.add_theme_color_override("font_color", Color(0.99, 0.89, 0.59, 1.0))
	_score_value_label.text = "0"
	root_layout.add_child(_score_value_label)

	_score_breakdown_label = Label.new()
	_score_breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_breakdown_label.add_theme_font_size_override("font_size", 20)
	_score_breakdown_label.add_theme_color_override("font_color", Color(0.87, 0.93, 1.0, 0.95))
	root_layout.add_child(_score_breakdown_label)

	_score_comparison_label = Label.new()
	_score_comparison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_comparison_label.add_theme_font_size_override("font_size", 22)
	_score_comparison_label.add_theme_color_override("font_color", Color(0.79, 0.97, 0.85, 1.0))
	root_layout.add_child(_score_comparison_label)

	_share_button = Button.new()
	_share_button.text = "Share"
	_share_button.focus_mode = Control.FOCUS_NONE
	_share_button.custom_minimum_size = Vector2(180.0, 48.0)
	_share_button.add_theme_font_size_override("font_size", 18)
	_share_button.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2, 1.0))
	_style_pill_button(_share_button, Constants.PALETTE_MINT, 24)
	root_layout.add_child(_share_button)
	_connect_if_needed(_share_button, &"pressed", Callable(self, "_on_share_button_pressed"))

	_share_stub_label = Label.new()
	_share_stub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_share_stub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_share_stub_label.add_theme_font_size_override("font_size", 18)
	_share_stub_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.58, 0.95))
	_share_stub_label.text = ""
	_share_stub_label.visible = false
	root_layout.add_child(_share_stub_label)


func _setup_decision_timeout_timer() -> void:
	_decision_timeout_timer = Timer.new()
	_decision_timeout_timer.one_shot = true
	_decision_timeout_timer.wait_time = MAX_DECISION_SECONDS
	add_child(_decision_timeout_timer)
	_connect_if_needed(_decision_timeout_timer, &"timeout", Callable(self, "_on_decision_timeout"))


func _rebuild_battle_snapshot() -> void:
	_clear_existing_battle_snapshot()

	var battle_variant: Node = TURN_BATTLE_SCENE.instantiate()
	if not (battle_variant is Node2D):
		battle_variant.queue_free()
		push_warning("FeedItem requires TurnBattle.tscn to instantiate as Node2D.")
		return

	_battle_root = battle_variant
	var turn_manager_candidate: Node = _battle_root.get_node_or_null("TurnManager")
	if turn_manager_candidate is TurnManager:
		turn_manager_candidate.auto_spawn_demo_puffs = false

	add_child(_battle_root)

	_cache_battle_nodes()
	_suppress_battle_hud_for_feed_snapshot()
	_connect_turn_manager_signals()
	_apply_snapshot_map()
	_layout_battle_snapshot()
	_spawn_snapshot_puffs()
	_seed_snapshot_enemy_intents()

	if _turn_manager != null:
		_turn_manager.set_process_unhandled_input(false)

	_set_status(
		"Your turn: move, attack, or bump",
		"Take your time and plan a one-turn masterpiece."
	)
	_show_score_preview_overlay()


func _layout_battle_snapshot() -> void:
	if _battle_root == null:
		return

	_battle_root.scale = SNAPSHOT_SCALE

	var map_bounds: Rect2 = _resolve_snapshot_map_bounds_local()
	var map_center_x: float = map_bounds.position.x + (map_bounds.size.x * 0.5)
	var map_top_local: float = SNAPSHOT_LOCAL_Y + map_bounds.position.y * SNAPSHOT_SCALE.y
	var map_bottom_local: float = SNAPSHOT_LOCAL_Y + (map_bounds.position.y + map_bounds.size.y) * SNAPSHOT_SCALE.y
	var centered_x_offset: float = -map_center_x * SNAPSHOT_SCALE.x
	_battle_root.position = Vector2(centered_x_offset, SNAPSHOT_LOCAL_Y)
	_layout_status_overlay(map_top_local)
	_layout_score_overlay(map_bottom_local)
	_layout_card_backdrop()


func _resolve_snapshot_map_bounds_local() -> Rect2:
	if _battle_map == null:
		return Rect2(Vector2.ZERO, SNAPSHOT_BOUNDS_FALLBACK_SIZE)

	var tile_map_layer: TileMapLayer = _battle_map.get_node_or_null("TileMapLayer")
	if tile_map_layer == null:
		return Rect2(Vector2.ZERO, SNAPSHOT_BOUNDS_FALLBACK_SIZE)

	var tile_half_size: Vector2 = Vector2(
		float(BattleMap.TILE_PIXEL_SIZE.x) * 0.5,
		float(BattleMap.TILE_PIXEL_SIZE.y) * 0.5
	)
	var map_size: Vector2i = _battle_map.map_size
	if map_size.x <= 0 or map_size.y <= 0:
		map_size = Constants.GRID_SIZE

	var min_bounds: Vector2 = Vector2(INF, INF)
	var max_bounds: Vector2 = Vector2(-INF, -INF)
	for y in map_size.y:
		for x in map_size.x:
			var layer_local_center: Vector2 = tile_map_layer.map_to_local(Vector2i(x, y))
			var map_local_center: Vector2 = _battle_map.to_local(tile_map_layer.to_global(layer_local_center))
			min_bounds.x = minf(min_bounds.x, map_local_center.x - tile_half_size.x)
			min_bounds.y = minf(min_bounds.y, map_local_center.y - tile_half_size.y)
			max_bounds.x = maxf(max_bounds.x, map_local_center.x + tile_half_size.x)
			max_bounds.y = maxf(max_bounds.y, map_local_center.y + tile_half_size.y)

	if min_bounds.x == INF or min_bounds.y == INF:
		return Rect2(Vector2.ZERO, SNAPSHOT_BOUNDS_FALLBACK_SIZE)

	return Rect2(min_bounds, max_bounds - min_bounds)


func _layout_status_overlay(map_top_local: float = NAN) -> void:
	if _status_panel == null:
		return
	_status_panel.custom_minimum_size = STATUS_PANEL_SIZE
	_status_panel.size = STATUS_PANEL_SIZE
	var panel_y: float = STATUS_PANEL_FALLBACK_LOCAL_Y
	if not is_nan(map_top_local):
		panel_y = map_top_local - STATUS_PANEL_SIZE.y - STATUS_PANEL_MAP_GAP
	_status_panel.position = Vector2(-STATUS_PANEL_SIZE.x * 0.5, panel_y)


func _layout_score_overlay(map_bottom_local: float = NAN) -> void:
	if _score_panel == null:
		return
	_score_panel.size = SCORE_PANEL_SIZE
	var panel_y: float = SCORE_PANEL_FALLBACK_LOCAL_Y
	if not is_nan(map_bottom_local):
		panel_y = map_bottom_local + SCORE_PANEL_MAP_GAP
	_score_panel.position = Vector2(-_score_panel.size.x * 0.5, panel_y)


func _cache_battle_nodes() -> void:
	_battle_map = null
	_turn_manager = null
	_enemy_intent = null

	if _battle_root == null:
		return

	var map_candidate: Node = _battle_root.get_node_or_null("BattleMap")
	if map_candidate is BattleMap:
		_battle_map = map_candidate

	var turn_manager_candidate: Node = _battle_root.get_node_or_null("TurnManager")
	if turn_manager_candidate is TurnManager:
		_turn_manager = turn_manager_candidate

	var intent_candidate: Node = _battle_root.get_node_or_null("EnemyIntent")
	if intent_candidate is EnemyIntent:
		_enemy_intent = intent_candidate


func _suppress_battle_hud_for_feed_snapshot() -> void:
	if _battle_root == null:
		return

	var hud_candidate: Node = _battle_root.get_node_or_null("HudLayer")
	if hud_candidate is CanvasLayer:
		var hud_layer: CanvasLayer = hud_candidate
		hud_layer.visible = false


func _connect_turn_manager_signals() -> void:
	if _turn_manager == null:
		return
	_connect_if_needed(_turn_manager, &"phase_changed", Callable(self, "_on_turn_phase_changed"))
	_connect_if_needed(_turn_manager, &"action_resolved", Callable(self, "_on_turn_manager_action_resolved"))


func _apply_snapshot_map() -> void:
	if _battle_map == null:
		return
	var map_config_variant: Variant = _snapshot.get("map_config", {})
	if map_config_variant is Dictionary and not map_config_variant.is_empty():
		_battle_map.load_map_from_config(map_config_variant)


func _spawn_snapshot_puffs() -> void:
	_puff_team_by_id.clear()
	_initial_enemy_count = 0
	_initial_player_count = 0
	_reset_score_tracking()

	if _turn_manager == null or _battle_root == null:
		return

	var puffs_variant: Variant = _snapshot.get("puffs", [])
	if not (puffs_variant is Array):
		return

	var puff_configs: Array = puffs_variant
	for puff_config_variant in puff_configs:
		if not (puff_config_variant is Dictionary):
			continue
		var puff_config: Dictionary = puff_config_variant
		_spawn_snapshot_puff(puff_config)

	var counts: Dictionary = _count_alive_puffs_by_team()
	_initial_player_count = int(counts.get(TEAM_PLAYER, 0))
	_initial_enemy_count = int(counts.get(TEAM_ENEMY, 0))


func _spawn_snapshot_puff(puff_config: Dictionary) -> void:
	if _turn_manager == null:
		return

	var puff_variant: Node = PUFF_SCENE.instantiate()
	if not (puff_variant is Puff):
		puff_variant.queue_free()
		return

	var puff: Puff = puff_variant
	_battle_root.add_child(puff)
	puff.set_battle_map(_battle_map)

	var team: StringName = _normalize_team(puff_config.get("team", TEAM_ENEMY))
	var data_path: String = str(puff_config.get("data_path", ""))
	var puff_data_resource: Resource = null
	if not data_path.is_empty():
		puff_data_resource = _load_puff_data_for_team(data_path, team)
	puff.set_team(team)
	puff_data_resource = _apply_snapshot_puff_overrides(puff_data_resource, puff_config)
	if puff_data_resource != null:
		puff.set_puff_data(puff_data_resource)

	var cell: Vector2i = _to_cell(puff_config.get("cell", Vector2i.ZERO))
	puff.set_grid_cell(cell)

	var puff_name: String = str(puff_config.get("name", ""))
	if puff_name.is_empty():
		puff_name = _build_snapshot_puff_name(puff_config, cell)
	puff.name = puff_name

	_turn_manager.register_puff(puff, team)

	var puff_id: int = puff.get_instance_id()
	_puff_team_by_id[puff_id] = team
	puff.tree_exited.connect(_on_snapshot_puff_exited.bind(puff_id), CONNECT_ONE_SHOT)


func _seed_snapshot_enemy_intents() -> void:
	if _enemy_intent == null:
		return

	var intents_variant: Variant = _snapshot.get("enemy_intents", [])
	if not (intents_variant is Array):
		return
	var intents: Array = intents_variant
	_enemy_intent.load_snapshot_intents(intents)


func _begin_decision_phase() -> void:
	if _decision_started or _cycle_done:
		return
	_decision_started = true
	_decision_start_time_seconds = _now_seconds()
	_decision_lock_time_seconds = 0.0
	_cycle_completion_time_seconds = 0.0
	_show_score_preview_overlay()
	_decision_timeout_timer.start(MAX_DECISION_SECONDS)

	_set_status(
		"Your turn: move, attack, or bump",
		"Take your time and plan a one-turn masterpiece."
	)


func _on_turn_phase_changed(phase: StringName, active_side: StringName, _turn_number: int) -> void:
	if _cycle_done or _decision_locked or not _decision_started:
		return
	if phase != PHASE_RESOLVE:
		return
	if active_side != TEAM_PLAYER:
		return

	_decision_locked = true
	_decision_lock_time_seconds = _now_seconds()
	call_deferred("_run_completion_flow", true)


func _on_turn_manager_action_resolved(side: StringName, action_payload: Dictionary) -> void:
	if side != TEAM_PLAYER:
		return

	var direct_damage: int = maxi(0, int(action_payload.get("damage", 0)))
	var swing_damage: int = maxi(0, int(action_payload.get("hp_swing", 0)))
	_player_damage_dealt += maxi(direct_damage, swing_damage)

	var turn_number: int = int(action_payload.get("turn_number", 0))
	if turn_number <= 0:
		turn_number = _resolved_player_turn_numbers.size() + 1
	if not _resolved_player_turn_numbers.has(turn_number):
		_resolved_player_turn_numbers[turn_number] = true
	_player_turns_used = _resolved_player_turn_numbers.size()


func _on_decision_timeout() -> void:
	if _cycle_done or _decision_locked or not _decision_started:
		return
	_decision_locked = true
	_decision_lock_time_seconds = _now_seconds()
	call_deferred("_run_completion_flow", false)


func _run_completion_flow(player_acted: bool) -> void:
	if _turn_manager != null:
		_turn_manager.set_process_unhandled_input(false)

	if _decision_timeout_timer != null and not _decision_timeout_timer.is_stopped():
		_decision_timeout_timer.stop()

	var elapsed_decision: float = _decision_elapsed_seconds()
	var min_hold_seconds: float = maxf(0.0, MIN_DECISION_SECONDS - elapsed_decision)
	if min_hold_seconds > 0.0:
		_set_status(
			"Locking tactical result...",
			"Almost there..."
		)
		await get_tree().create_timer(min_hold_seconds).timeout

	_set_status(
		"Resolving turn result",
		"Watch what happens next..."
	)
	await _play_result_animation()

	var score_breakdown: Dictionary = _build_score_breakdown(player_acted)
	var final_score: int = int(score_breakdown.get("final_score", 0))
	var comparison_text: String = _build_score_comparison_text(final_score, score_breakdown)
	_show_score_overlay(score_breakdown, comparison_text)

	_set_status(
		"Score reveal",
		comparison_text
	)

	var reveal_duration: float = minf(SCORE_REVEAL_DURATION, SCORE_PHASE_SECONDS)
	await _animate_score_countup(final_score, reveal_duration)
	var hold_duration: float = maxf(0.0, SCORE_PHASE_SECONDS - reveal_duration)
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout

	_cycle_done = true
	_cycle_completion_time_seconds = _now_seconds()

	_emit_feed_item_completed(final_score)
	_set_status(
		"Swipe up for next feed item",
		"Swipe up for the next puzzle."
	)

	emit_signal("cycle_completed", final_score, _cycle_duration_seconds())


func _play_result_animation() -> void:
	if _status_panel == null:
		await get_tree().create_timer(RESULT_PHASE_SECONDS).timeout
		return

	_status_panel.modulate = Color(1.0, 1.0, 1.0, 0.76)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_status_panel, "modulate:a", 0.98, RESULT_PHASE_SECONDS * 0.45)
	tween.tween_property(_status_panel, "modulate:a", 0.78, RESULT_PHASE_SECONDS * 0.55)
	await tween.finished


func _build_score_breakdown(_player_acted: bool) -> Dictionary:
	var counts: Dictionary = _count_alive_puffs_by_team()
	var enemies_alive: int = int(counts.get(TEAM_ENEMY, 0))
	var allies_alive: int = int(counts.get(TEAM_PLAYER, 0))

	var enemies_defeated: int = maxi(0, _initial_enemy_count - enemies_alive)
	var allies_surviving: int = maxi(0, allies_alive)
	var damage_dealt: int = maxi(0, _player_damage_dealt)
	var turns_used: int = maxi(1, _player_turns_used)

	var enemies_points: int = enemies_defeated * SCORE_ENEMY_DEFEATED_POINTS
	var damage_points: int = damage_dealt * SCORE_DAMAGE_POINTS_PER_HP
	var survival_points: int = allies_surviving * SCORE_SURVIVAL_POINTS
	var turn_points: int = maxi(0, SCORE_TURN_BASELINE - turns_used) * SCORE_TURN_EFFICIENCY_POINTS
	var final_score: int = enemies_points + damage_points + survival_points + turn_points

	return {
		"final_score": final_score,
		"enemies_defeated": enemies_defeated,
		"damage_dealt": damage_dealt,
		"allies_surviving": allies_surviving,
		"turns_used": turns_used,
		"enemies_points": enemies_points,
		"damage_points": damage_points,
		"survival_points": survival_points,
		"turn_points": turn_points
	}


func _compute_score_from_components(enemies_defeated: int, damage_dealt: int, allies_surviving: int, turns_used: int) -> int:
	var clamped_turns: int = maxi(1, turns_used)
	var turn_points: int = maxi(0, SCORE_TURN_BASELINE - clamped_turns) * SCORE_TURN_EFFICIENCY_POINTS
	return maxi(0, enemies_defeated) * SCORE_ENEMY_DEFEATED_POINTS \
		+ maxi(0, damage_dealt) * SCORE_DAMAGE_POINTS_PER_HP \
		+ maxi(0, allies_surviving) * SCORE_SURVIVAL_POINTS \
		+ turn_points


func _build_score_breakdown_text(score_breakdown: Dictionary) -> String:
	var enemies_defeated: int = int(score_breakdown.get("enemies_defeated", 0))
	var damage_dealt: int = int(score_breakdown.get("damage_dealt", 0))
	var allies_surviving: int = int(score_breakdown.get("allies_surviving", 0))
	var turns_used: int = int(score_breakdown.get("turns_used", 1))
	var enemies_points: int = int(score_breakdown.get("enemies_points", 0))
	var damage_points: int = int(score_breakdown.get("damage_points", 0))
	var survival_points: int = int(score_breakdown.get("survival_points", 0))
	var turn_points: int = int(score_breakdown.get("turn_points", 0))

	return "Enemies defeated: %d (+%d)\nDamage dealt: %d (+%d)\nPuffs surviving: %d (+%d)\nTurns used: %d (+%d)" % [
		enemies_defeated,
		enemies_points,
		damage_dealt,
		damage_points,
		allies_surviving,
		survival_points,
		turns_used,
		turn_points
	]


func _build_score_comparison_text(final_score: int, score_breakdown: Dictionary) -> String:
	if _is_decisive_moment_snapshot():
		var original_score: int = _resolve_original_player_score(score_breakdown)
		return _build_decisive_comparison_text(final_score, original_score)

	var percentile: int = _resolve_percentile_rank(final_score)
	return _build_percentile_comparison_text(percentile)


func _build_decisive_comparison_text(final_score: int, original_score: int) -> String:
	var delta: int = final_score - original_score
	if delta > 0:
		return "Did you do better than the original player? Yes (+%d)." % delta
	if delta < 0:
		return "Did you do better than the original player? Not yet (%d behind)." % absi(delta)
	return "Did you do better than the original player? You matched the original."


func _build_percentile_comparison_text(percentile: int) -> String:
	var top_percent: int = maxi(1, 100 - percentile)
	return "Community ranking: %d%s percentile (top %d%%)." % [
		percentile,
		_ordinal_suffix(percentile),
		top_percent
	]


func _ordinal_suffix(value: int) -> String:
	var normalized: int = abs(value)
	var mod_hundred: int = normalized % 100
	if mod_hundred >= 11 and mod_hundred <= 13:
		return "th"

	match normalized % 10:
		1:
			return "st"
		2:
			return "nd"
		3:
			return "rd"
		_:
			return "th"


func _is_decisive_moment_snapshot() -> bool:
	var moment_meta_variant: Variant = _snapshot.get("moment_meta", null)
	if moment_meta_variant is Dictionary:
		return true

	var feed_item_id: String = str(_snapshot.get("feed_item_id", "")).strip_edges().to_lower()
	return feed_item_id.begins_with(MOMENT_FEED_ITEM_PREFIX)


func _resolve_original_player_score(score_breakdown: Dictionary) -> int:
	var fallback_score: int = int(_snapshot.get("target_score", DEFAULT_TARGET_SCORE))
	var moment_meta_variant: Variant = _snapshot.get("moment_meta", null)
	if not (moment_meta_variant is Dictionary):
		return fallback_score

	var moment_meta: Dictionary = moment_meta_variant
	for key in ORIGINAL_SCORE_KEYS:
		var score_variant: Variant = moment_meta.get(key, null)
		if _is_numeric(score_variant):
			return int(round(float(score_variant)))

	var original_result_variant: Variant = moment_meta.get("original_result", {})
	var original_action_variant: Variant = moment_meta.get("original_player_action", {})
	var original_result: Dictionary = original_result_variant if original_result_variant is Dictionary else {}
	var original_action: Dictionary = original_action_variant if original_action_variant is Dictionary else {}

	var enemies_defeated: int = int(original_result.get("knockout_count", original_action.get("knockout_count", 0)))
	if enemies_defeated <= 0 and (
		bool(original_result.get("knockout_occurred", false))
		or bool(original_action.get("knockout", false))
	):
		enemies_defeated = 1

	var damage_dealt: int = maxi(
		0,
		maxi(
			int(original_action.get("damage", 0)),
			int(original_result.get("hp_swing", original_action.get("hp_swing", 0)))
		)
	)

	var allies_surviving: int = int(score_breakdown.get("allies_surviving", _count_snapshot_player_units()))
	if _is_numeric(moment_meta.get("original_allies_surviving", null)):
		allies_surviving = maxi(0, int(round(float(moment_meta.get("original_allies_surviving", allies_surviving)))))
	elif _is_numeric(original_result.get("allies_surviving", null)):
		allies_surviving = maxi(0, int(round(float(original_result.get("allies_surviving", allies_surviving)))))

	var turns_used: int = int(moment_meta.get("original_turns_used", original_action.get("turns_used", 1)))
	if turns_used <= 0:
		turns_used = maxi(1, int(original_action.get("turn_number", 1)))

	return _compute_score_from_components(enemies_defeated, damage_dealt, allies_surviving, turns_used)


func _resolve_percentile_rank(score: int) -> int:
	var snapshot_percentile_variant: Variant = _snapshot.get("community_percentile", null)
	if _is_numeric(snapshot_percentile_variant):
		return clampi(int(round(float(snapshot_percentile_variant))), 1, 99)

	var community_stats_variant: Variant = _snapshot.get("community_stats", null)
	if community_stats_variant is Dictionary:
		var community_stats: Dictionary = community_stats_variant
		var stats_percentile_variant: Variant = community_stats.get("percentile", community_stats.get("player_percentile", null))
		if _is_numeric(stats_percentile_variant):
			return clampi(int(round(float(stats_percentile_variant))), 1, 99)

	var community_samples: Array[int] = _extract_community_score_samples()
	if not community_samples.is_empty():
		return _resolve_percentile_from_samples(score, community_samples)

	var target_score: int = int(_snapshot.get("target_score", DEFAULT_TARGET_SCORE))
	var delta: int = score - target_score
	var estimated_percentile: int = int(round(50.0 + float(delta) * SCORE_FALLBACK_PERCENTILE_FACTOR))
	return clampi(estimated_percentile, 5, 99)


func _extract_community_score_samples() -> Array[int]:
	var samples: Array[int] = []
	for key in COMMUNITY_SCORE_KEYS:
		var raw_variant: Variant = _snapshot.get(String(key), null)
		_append_numeric_samples(samples, raw_variant)

	return samples


func _append_numeric_samples(target_samples: Array[int], raw_samples_variant: Variant) -> void:
	if raw_samples_variant is Array:
		var raw_samples: Array = raw_samples_variant
		for sample_variant in raw_samples:
			if _is_numeric(sample_variant):
				target_samples.append(int(round(float(sample_variant))))
		return

	if raw_samples_variant is Dictionary:
		var sample_dict: Dictionary = raw_samples_variant
		var nested_samples_variant: Variant = sample_dict.get("scores", sample_dict.get("values", []))
		if nested_samples_variant is Array:
			var nested_samples: Array = nested_samples_variant
			for sample_variant in nested_samples:
				if _is_numeric(sample_variant):
					target_samples.append(int(round(float(sample_variant))))


func _resolve_percentile_from_samples(score: int, samples: Array[int]) -> int:
	if samples.is_empty():
		return 50

	var at_or_below_count: int = 0
	for sample in samples:
		if sample <= score:
			at_or_below_count += 1

	var percentile: int = int(round((float(at_or_below_count) / float(samples.size())) * 100.0))
	return clampi(percentile, 1, 99)


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float


func _count_snapshot_player_units() -> int:
	var puffs_variant: Variant = _snapshot.get("puffs", [])
	if not (puffs_variant is Array):
		return maxi(1, _initial_player_count)

	var player_count: int = 0
	var puffs: Array = puffs_variant
	for puff_variant in puffs:
		if not (puff_variant is Dictionary):
			continue
		var puff_config: Dictionary = puff_variant
		if _normalize_team(puff_config.get("team", TEAM_ENEMY)) == TEAM_PLAYER:
			player_count += 1

	if player_count > 0:
		return player_count
	return maxi(1, _initial_player_count)


func _show_score_overlay(score_breakdown: Dictionary, comparison_text: String) -> void:
	if _score_panel == null:
		return

	var final_score: int = int(score_breakdown.get("final_score", 0))
	_score_panel.visible = true
	_score_title_label.text = "Score Breakdown"
	_score_value_label.text = "0"
	_score_breakdown_label.text = _build_score_breakdown_text(score_breakdown)
	_score_comparison_label.text = comparison_text
	_share_stub_label.text = ""
	_share_button.visible = true
	_share_button.disabled = false
	_share_button.tooltip_text = "Share this result"

	if final_score <= 0:
		_set_score_display_value(0.0)


func _hide_score_overlay() -> void:
	if _score_panel == null:
		return
	_score_panel.visible = false
	if _share_stub_label != null:
		_share_stub_label.text = ""


func _show_score_preview_overlay() -> void:
	if _score_panel == null:
		return

	_score_panel.visible = true
	_score_title_label.text = "Turn Objective"
	_score_value_label.text = "Make Move"
	_score_breakdown_label.text = "Defeat enemies, protect allies, and finish this turn clean for a higher score."
	_score_comparison_label.text = "Pick one tactical move, then lock in your result."
	_share_button.visible = false
	_share_button.disabled = true
	_share_button.tooltip_text = ""
	_share_stub_label.text = ""


func _animate_score_countup(final_score: int, reveal_duration: float) -> void:
	if _score_value_label == null:
		if reveal_duration > 0.0:
			await get_tree().create_timer(reveal_duration).timeout
		return

	_set_score_display_value(0.0)
	if reveal_duration <= 0.0:
		_set_score_display_value(float(final_score))
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(self, "_set_score_display_value"), 0.0, float(final_score), reveal_duration)
	await tween.finished
	_set_score_display_value(float(final_score))


func _set_score_display_value(value: float) -> void:
	if _score_value_label == null:
		return
	_score_value_label.text = "%d" % maxi(0, int(round(value)))


func _on_share_button_pressed() -> void:
	_set_status(
		"Share action",
		"Sharing is coming soon."
	)


func _reset_score_tracking() -> void:
	_player_damage_dealt = 0
	_player_turns_used = 0
	_resolved_player_turn_numbers.clear()


func _count_alive_puffs_by_team() -> Dictionary:
	var counts: Dictionary = {
		TEAM_PLAYER: 0,
		TEAM_ENEMY: 0
	}

	var stale_ids: Array[int] = []
	for puff_id_variant in _puff_team_by_id.keys():
		var puff_id: int = int(puff_id_variant)
		var puff_variant: Variant = instance_from_id(puff_id)
		if not (puff_variant is Puff):
			stale_ids.append(puff_id)
			continue

		var puff: Puff = puff_variant
		if not is_instance_valid(puff):
			stale_ids.append(puff_id)
			continue

		var team: StringName = _normalize_team(_puff_team_by_id.get(puff_id, TEAM_ENEMY))
		counts[team] = int(counts.get(team, 0)) + 1

	for stale_id in stale_ids:
		_puff_team_by_id.erase(stale_id)

	return counts


func _clear_existing_battle_snapshot() -> void:
	if _battle_root != null and is_instance_valid(_battle_root):
		_battle_root.queue_free()

	_battle_root = null
	_battle_map = null
	_turn_manager = null
	_enemy_intent = null
	_puff_team_by_id.clear()
	_initial_enemy_count = 0
	_initial_player_count = 0
	_reset_score_tracking()
	_decision_started = false
	_decision_locked = false
	_cycle_done = false
	_hide_score_overlay()

	if _decision_timeout_timer != null and not _decision_timeout_timer.is_stopped():
		_decision_timeout_timer.stop()


func _emit_feed_item_completed(score: int) -> void:
	var signal_bus: Node = get_node_or_null("/root/SignalBus")
	if signal_bus == null:
		return
	if not signal_bus.has_signal(&"feed_item_completed"):
		return
	signal_bus.emit_signal("feed_item_completed", score)


func _set_status(headline: String, detail: String) -> void:
	if _status_label != null:
		_status_label.text = headline
	if _detail_label != null:
		_detail_label.text = detail
	emit_signal("status_changed", headline, can_advance_to_next_item())


func _decision_elapsed_seconds() -> float:
	if not _decision_started:
		return 0.0
	if _decision_lock_time_seconds > 0.0:
		return maxf(0.0, _decision_lock_time_seconds - _decision_start_time_seconds)
	return maxf(0.0, _now_seconds() - _decision_start_time_seconds)


func _cycle_duration_seconds() -> float:
	if not _decision_started:
		return 0.0
	if _cycle_completion_time_seconds > 0.0:
		return maxf(0.0, _cycle_completion_time_seconds - _decision_start_time_seconds)
	return maxf(0.0, _now_seconds() - _decision_start_time_seconds)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _to_cell(cell_variant: Variant) -> Vector2i:
	if cell_variant is Vector2i:
		return cell_variant
	if cell_variant is Dictionary:
		var cell_dict: Dictionary = cell_variant
		return Vector2i(int(cell_dict.get("x", 0)), int(cell_dict.get("y", 0)))
	if cell_variant is Array:
		var cell_array: Array = cell_variant
		if cell_array.size() >= 2:
			return Vector2i(int(cell_array[0]), int(cell_array[1]))
	return Vector2i.ZERO


func _normalize_team(team_variant: Variant) -> StringName:
	if team_variant is StringName:
		var named_team: StringName = team_variant
		if named_team == TEAM_PLAYER or named_team == TEAM_ENEMY:
			return named_team

	var team_text: String = str(team_variant).strip_edges().to_lower()
	if team_text == String(TEAM_PLAYER):
		return TEAM_PLAYER
	if team_text == String(TEAM_ENEMY):
		return TEAM_ENEMY
	return TEAM_ENEMY


func _build_snapshot_puff_name(puff_config: Dictionary, cell: Vector2i) -> String:
	var team: StringName = _normalize_team(puff_config.get("team", TEAM_ENEMY))
	return "%s_%d_%d" % [String(team), cell.x, cell.y]


func _on_snapshot_puff_exited(puff_id: int) -> void:
	_puff_team_by_id.erase(puff_id)


func _style_pill_button(button: Button, base_color: Color, corner_radius: int) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		match state_name:
			"normal":
				style.bg_color = base_color
			"hover":
				style.bg_color = base_color.lightened(0.08)
			"pressed":
				style.bg_color = base_color.darkened(0.1)
			"disabled":
				style.bg_color = base_color.darkened(0.3)
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		button.add_theme_stylebox_override(state_name, style)


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)


func _load_puff_data_for_team(data_path: String, team: StringName) -> Resource:
	if data_path.is_empty():
		return null

	if team == TEAM_PLAYER:
		var progression: Node = get_node_or_null("/root/PuffProgression")
		if progression != null and progression.has_method("build_runtime_puff_data"):
			var runtime_data_variant: Variant = progression.call("build_runtime_puff_data", data_path)
			if runtime_data_variant is Resource:
				return runtime_data_variant

	return load(data_path)


func _apply_snapshot_puff_overrides(base_resource: Resource, puff_config: Dictionary) -> Resource:
	var needs_override: bool = (
		puff_config.has("element")
		or puff_config.has("puff_class")
		or puff_config.has("display_name")
	)
	if not needs_override:
		return base_resource

	var runtime_resource: Resource = null
	if base_resource != null:
		runtime_resource = base_resource.duplicate(true)
	else:
		var fallback_variant: Variant = PUFF_DATA_SCRIPT.new()
		if fallback_variant is Resource:
			runtime_resource = fallback_variant

	if runtime_resource == null:
		return null

	if puff_config.has("element"):
		runtime_resource.set("element", int(puff_config.get("element", Constants.Element.STAR)))
	if puff_config.has("puff_class"):
		runtime_resource.set("puff_class", int(puff_config.get("puff_class", Constants.PuffClass.STAR)))
	if puff_config.has("display_name"):
		runtime_resource.set("display_name", StringName(str(puff_config.get("display_name", ""))))

	return runtime_resource
