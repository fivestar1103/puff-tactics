extends Node2D
class_name FullBattle

const PUFF_SCENE: PackedScene = preload("res://src/scenes/puffs/Puff.tscn")
const PVP_ASYNC_SCRIPT: GDScript = preload("res://src/scripts/network/pvp_async.gd")

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"
const TEAM_NEUTRAL: StringName = &"neutral"
const PHASE_PLAYER_SELECT: StringName = &"player_select"

const LOG_DIRECTORY: String = "user://battle_logs"

const PLAYER_SPAWN_CELLS: Array[Vector2i] = [
	Vector2i(0, 4),
	Vector2i(1, 4),
	Vector2i(0, 3),
	Vector2i(1, 3)
]

const ENEMY_SPAWN_CELLS: Array[Vector2i] = [
	Vector2i(4, 0),
	Vector2i(3, 0),
	Vector2i(4, 1),
	Vector2i(3, 1)
]

const DEFAULT_MAP_CONFIG: Dictionary = {
	"width": 5,
	"height": 5,
	"rows": [
		["cloud", "high_cloud", "cloud", "cliff", "cloud"],
		["cloud", "puddle", "cloud", "mushroom", "cloud"],
		["cotton_candy", "cloud", "high_cloud", "cloud", "cotton_candy"],
		["cloud", "mushroom", "cloud", "puddle", "cloud"],
		["cloud", "cliff", "cloud", "high_cloud", "cloud"]
	]
}

const PLAYER_ROSTER: Array[Dictionary] = [
	{
		"label": "Cloud",
		"role": "Tank",
		"data_path": "res://src/resources/puffs/base/cloud_tank.tres"
	},
	{
		"label": "Flame",
		"role": "Melee",
		"data_path": "res://src/resources/puffs/base/flame_melee.tres"
	},
	{
		"label": "Droplet",
		"role": "Ranged",
		"data_path": "res://src/resources/puffs/base/droplet_ranged.tres"
	},
	{
		"label": "Leaf",
		"role": "Healer",
		"data_path": "res://src/resources/puffs/base/leaf_healer.tres"
	},
	{
		"label": "Whirl",
		"role": "Mobility",
		"data_path": "res://src/resources/puffs/base/whirl_mobility.tres"
	},
	{
		"label": "Star",
		"role": "Wildcard",
		"data_path": "res://src/resources/puffs/base/star_wildcard.tres"
	}
]

@export_range(5, 8, 1) var max_turns: int = 8
@export var battle_map_path: NodePath = NodePath("BattleMap")
@export var turn_manager_path: NodePath = NodePath("TurnManager")
@export var ui_layer_path: NodePath = NodePath("UiLayer")

var _battle_map: BattleMap
var _turn_manager: TurnManager
var _ui_layer: CanvasLayer
var _signal_bus: Node

var _ui_root: Control
var _hud_panel: PanelContainer
var _hud_label: Label
var _selection_overlay: ColorRect
var _selection_count_label: Label
var _selection_hint_label: Label
var _start_battle_button: Button
var _result_overlay: ColorRect
var _result_title_label: Label
var _result_summary_label: Label

var _roster_buttons_by_path: Dictionary = {}
var _selected_roster_paths: Array[String] = []
var _enemy_roster_paths: Array[String] = []

var _player_units: Array[Puff] = []
var _enemy_units: Array[Puff] = []
var _unit_registry: Dictionary = {}
var _unit_state_by_name: Dictionary = {}

var _battle_started: bool = false
var _battle_finished: bool = false
var _battle_winner: StringName = &""
var _battle_end_reason: StringName = &""
var _latest_tile_control: Dictionary = {
	TEAM_PLAYER: 0,
	TEAM_ENEMY: 0,
	TEAM_NEUTRAL: 0
}

var _battle_id: String = ""
var _battle_log_path: String = ""
var _battle_log_header: Dictionary = {}
var _battle_log_events: Array[Dictionary] = []
var _turn_context_by_number: Dictionary = {}
var _pvp_async: Node
var _match_context: Dictionary = {}
var _opponent_ghost_payload: Dictionary = {}
var _player_ai_weights_for_match: Dictionary = {}
var _pvp_status_message: String = ""


func _ready() -> void:
	_resolve_scene_references()
	if _battle_map == null or _turn_manager == null:
		push_warning("FullBattle requires BattleMap and TurnManager nodes.")
		return

	_turn_manager.auto_spawn_demo_puffs = false
	_turn_manager.auto_begin_turn_cycle = false
	_turn_manager.set_process_unhandled_input(false)

	_apply_default_map_config()
	_connect_signals()
	_setup_async_pvp()
	_build_ui()
	_refresh_selection_ui()
	_update_hud()


func _resolve_scene_references() -> void:
	var map_candidate: Node = get_node_or_null(battle_map_path)
	if map_candidate is BattleMap:
		_battle_map = map_candidate

	var turn_manager_candidate: Node = get_node_or_null(turn_manager_path)
	if turn_manager_candidate is TurnManager:
		_turn_manager = turn_manager_candidate

	var ui_layer_candidate: Node = get_node_or_null(ui_layer_path)
	if ui_layer_candidate is CanvasLayer:
		_ui_layer = ui_layer_candidate

	_signal_bus = get_node_or_null("/root/SignalBus")


func _apply_default_map_config() -> void:
	if _battle_map == null:
		return
	_battle_map.load_map_from_config(DEFAULT_MAP_CONFIG)


func _connect_signals() -> void:
	if _turn_manager != null:
		_connect_if_needed(_turn_manager, &"phase_changed", Callable(self, "_on_turn_phase_changed"))
		_connect_if_needed(_turn_manager, &"action_resolved", Callable(self, "_on_turn_manager_action_resolved"))

	if _signal_bus != null:
		_connect_if_needed(_signal_bus, &"puff_moved", Callable(self, "_on_signal_bus_puff_moved"))
		_connect_if_needed(_signal_bus, &"puff_bumped", Callable(self, "_on_signal_bus_puff_bumped"))
		_connect_if_needed(_signal_bus, &"turn_ended", Callable(self, "_on_signal_bus_turn_ended"))
		_connect_if_needed(_signal_bus, &"battle_ended", Callable(self, "_on_signal_bus_battle_ended"))


func _build_ui() -> void:
	if _ui_layer == null:
		return

	_ui_root = Control.new()
	_ui_root.name = "FullBattleUiRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_ui_root)

	_build_hud_panel()
	_build_selection_overlay()
	_build_result_overlay()


func _build_hud_panel() -> void:
	_hud_panel = PanelContainer.new()
	_hud_panel.anchor_right = 0.0
	_hud_panel.anchor_bottom = 0.0
	_hud_panel.offset_left = 24.0
	_hud_panel.offset_top = 24.0
	_hud_panel.offset_right = 564.0
	_hud_panel.offset_bottom = 180.0
	_ui_root.add_child(_hud_panel)

	_hud_label = Label.new()
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud_label.add_theme_font_size_override("font_size", 20)
	_hud_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	_hud_panel.add_child(_hud_label)


func _build_selection_overlay() -> void:
	_selection_overlay = ColorRect.new()
	_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_overlay.color = Color(0.05, 0.08, 0.16, 0.76)
	_ui_root.add_child(_selection_overlay)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360.0
	panel.offset_top = -280.0
	panel.offset_right = 360.0
	panel.offset_bottom = 280.0
	_selection_overlay.add_child(panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title_label: Label = Label.new()
	title_label.text = "Full Match: Select 3-4 Puffs"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	layout.add_child(title_label)

	_selection_hint_label = Label.new()
	_selection_hint_label.text = "Win by eliminating all enemy puffs or controlling 13/25 tiles."
	_selection_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_hint_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_selection_hint_label)

	_selection_count_label = Label.new()
	_selection_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_count_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(_selection_count_label)

	var roster_grid: GridContainer = GridContainer.new()
	roster_grid.columns = 2
	roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_grid.add_theme_constant_override("h_separation", 10)
	roster_grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(roster_grid)

	_roster_buttons_by_path.clear()
	for roster_entry in PLAYER_ROSTER:
		var data_path: String = str(roster_entry.get("data_path", ""))
		var roster_button: Button = Button.new()
		roster_button.toggle_mode = true
		roster_button.focus_mode = Control.FOCUS_NONE
		roster_button.custom_minimum_size = Vector2(320.0, 54.0)
		roster_button.text = "%s (%s)" % [
			str(roster_entry.get("label", "Unknown")),
			str(roster_entry.get("role", "Role"))
		]
		roster_grid.add_child(roster_button)
		_roster_buttons_by_path[data_path] = roster_button
		_connect_if_needed(roster_button, &"toggled", Callable(self, "_on_roster_button_toggled").bind(data_path))

	_start_battle_button = Button.new()
	_start_battle_button.text = "Start Full Battle"
	_start_battle_button.focus_mode = Control.FOCUS_NONE
	_start_battle_button.custom_minimum_size = Vector2(260.0, 56.0)
	_start_battle_button.disabled = true
	layout.add_child(_start_battle_button)
	_connect_if_needed(_start_battle_button, &"pressed", Callable(self, "_on_start_battle_pressed"))


func _build_result_overlay() -> void:
	_result_overlay = ColorRect.new()
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0.03, 0.05, 0.1, 0.86)
	_result_overlay.visible = false
	_ui_root.add_child(_result_overlay)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_top = -180.0
	panel.offset_right = 330.0
	panel.offset_bottom = 180.0
	_result_overlay.add_child(panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	_result_title_label = Label.new()
	_result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title_label.add_theme_font_size_override("font_size", 38)
	layout.add_child(_result_title_label)

	_result_summary_label = Label.new()
	_result_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_summary_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(_result_summary_label)


func _on_roster_button_toggled(pressed: bool, data_path: String) -> void:
	if pressed:
		if _selected_roster_paths.has(data_path):
			return
		if _selected_roster_paths.size() >= 4:
			var overflow_button_variant: Variant = _roster_buttons_by_path.get(data_path)
			if overflow_button_variant is Button:
				var overflow_button: Button = overflow_button_variant
				overflow_button.set_pressed_no_signal(false)
			return
		_selected_roster_paths.append(data_path)
	else:
		_selected_roster_paths.erase(data_path)

	_refresh_selection_ui()


func _refresh_selection_ui() -> void:
	if _selection_count_label == null:
		return

	var selected_count: int = _selected_roster_paths.size()
	_selection_count_label.text = "Selected: %d / 4 (minimum 3)" % selected_count
	_start_battle_button.disabled = selected_count < 3 or selected_count > 4

	var lock_unselected_buttons: bool = selected_count >= 4
	for path_variant in _roster_buttons_by_path.keys():
		var data_path: String = str(path_variant)
		var button_variant: Variant = _roster_buttons_by_path[path_variant]
		if not (button_variant is Button):
			continue
		var roster_button: Button = button_variant
		roster_button.disabled = lock_unselected_buttons and not _selected_roster_paths.has(data_path)


func _on_start_battle_pressed() -> void:
	if _selected_roster_paths.size() < 3 or _selected_roster_paths.size() > 4:
		return

	_start_battle_button.disabled = true
	_start_battle_button.text = "Matchmaking..."
	await _prepare_async_match_context()
	_start_battle_button.text = "Start Full Battle"
	_start_battle_button.disabled = false

	_start_full_battle()


func _start_full_battle() -> void:
	_selection_overlay.visible = false
	_result_overlay.visible = false

	_battle_started = true
	_battle_finished = false
	_battle_winner = &""
	_battle_end_reason = &""
	if _player_ai_weights_for_match.is_empty():
		_player_ai_weights_for_match = _capture_turn_manager_ai_weights()

	_clear_spawned_units()
	_enemy_roster_paths = _resolve_enemy_roster_for_match(_selected_roster_paths)
	_apply_enemy_ghost_ai_weights()
	_spawn_match_units(_selected_roster_paths, _enemy_roster_paths)
	_initialize_battle_log()
	_latest_tile_control = _calculate_tile_control_totals()
	_update_hud()

	_record_battle_event(&"battle_started", {
		"player_team_count": _selected_roster_paths.size(),
		"enemy_team_count": _enemy_roster_paths.size()
	})

	_turn_manager.begin_turn_cycle(true)


func _build_enemy_roster_for_match(player_roster_paths: Array[String]) -> Array[String]:
	var candidates: Array[String] = []
	for roster_entry in PLAYER_ROSTER:
		var data_path: String = str(roster_entry.get("data_path", ""))
		if not player_roster_paths.has(data_path):
			candidates.append(data_path)

	while candidates.size() < ENEMY_SPAWN_CELLS.size():
		for roster_entry in PLAYER_ROSTER:
			var fallback_path: String = str(roster_entry.get("data_path", ""))
			candidates.append(fallback_path)
			if candidates.size() >= ENEMY_SPAWN_CELLS.size():
				break

	candidates.shuffle()
	var enemy_team: Array[String] = []
	for index in range(ENEMY_SPAWN_CELLS.size()):
		enemy_team.append(candidates[index])
	return enemy_team


func _setup_async_pvp() -> void:
	var pvp_async_variant: Variant = PVP_ASYNC_SCRIPT.new()
	if not (pvp_async_variant is Node):
		return
	_pvp_async = pvp_async_variant
	_pvp_async.name = "AsyncPvp"
	add_child(_pvp_async)


func _prepare_async_match_context() -> void:
	_match_context.clear()
	_opponent_ghost_payload.clear()
	_player_ai_weights_for_match = _capture_turn_manager_ai_weights()
	_pvp_status_message = ""
	if _pvp_async == null:
		return
	if not _pvp_async.has_method("find_match_for_player"):
		return

	var matchmaking_result_variant: Variant = await _pvp_async.call(
		"find_match_for_player",
		_selected_roster_paths.duplicate(),
		_player_ai_weights_for_match.duplicate(true)
	)
	if not (matchmaking_result_variant is Dictionary):
		_pvp_status_message = "Async PvP matchmaking unavailable."
		_update_hud()
		return

	var matchmaking_result: Dictionary = matchmaking_result_variant
	if not bool(matchmaking_result.get("ok", false)):
		_pvp_status_message = "Async PvP unavailable: %s" % str(matchmaking_result.get("error", "network unavailable"))
		_update_hud()
		return

	_match_context = matchmaking_result.duplicate(true)
	var opponent_ghost_variant: Variant = matchmaking_result.get("opponent_ghost", {})
	if opponent_ghost_variant is Dictionary:
		_opponent_ghost_payload = opponent_ghost_variant.duplicate(true)

	var opponent_profile_variant: Variant = matchmaking_result.get("opponent_profile", {})
	if opponent_profile_variant is Dictionary:
		var opponent_profile: Dictionary = opponent_profile_variant
		var opponent_elo: int = int(round(float(opponent_profile.get("elo", 0.0))))
		_pvp_status_message = "Matched async ghost around ELO %d." % opponent_elo
	else:
		_pvp_status_message = "Matched async ghost."
	_update_hud()


func _resolve_enemy_roster_for_match(player_roster_paths: Array[String]) -> Array[String]:
	var fallback_team: Array[String] = _build_enemy_roster_for_match(player_roster_paths)
	if _opponent_ghost_payload.is_empty():
		return fallback_team

	var team_paths_variant: Variant = _opponent_ghost_payload.get("team_paths", [])
	if not (team_paths_variant is Array):
		return fallback_team

	var raw_team_paths: Array = team_paths_variant
	var normalized_team: Array[String] = []
	for data_path_variant in raw_team_paths:
		var data_path: String = str(data_path_variant).strip_edges()
		if data_path.is_empty():
			continue
		normalized_team.append(data_path)

	if normalized_team.is_empty():
		return fallback_team

	var fill_index: int = 0
	while normalized_team.size() < ENEMY_SPAWN_CELLS.size():
		normalized_team.append(fallback_team[fill_index % fallback_team.size()])
		fill_index += 1

	while normalized_team.size() > ENEMY_SPAWN_CELLS.size():
		normalized_team.remove_at(normalized_team.size() - 1)

	return normalized_team


func _apply_enemy_ghost_ai_weights() -> void:
	if _turn_manager == null:
		return

	var ai_weights: Dictionary = _player_ai_weights_for_match.duplicate(true)
	var ai_weights_variant: Variant = _opponent_ghost_payload.get("ai_weights", {})
	if ai_weights_variant is Dictionary:
		ai_weights = _normalize_ai_weights(ai_weights_variant, ai_weights)

	_apply_turn_manager_ai_weights(ai_weights)


func _capture_turn_manager_ai_weights() -> Dictionary:
	if _turn_manager == null:
		return {}

	return {
		"attack_value": _turn_manager.ai_attack_value_weight,
		"survival_risk": _turn_manager.ai_survival_risk_weight,
		"positional_advantage": _turn_manager.ai_positional_advantage_weight,
		"bump_opportunity": _turn_manager.ai_bump_opportunity_weight
	}


func _apply_turn_manager_ai_weights(weights: Dictionary) -> void:
	if _turn_manager == null:
		return
	if weights.is_empty():
		return

	_turn_manager.ai_attack_value_weight = maxf(0.0, float(weights.get("attack_value", _turn_manager.ai_attack_value_weight)))
	_turn_manager.ai_survival_risk_weight = maxf(0.0, float(weights.get("survival_risk", _turn_manager.ai_survival_risk_weight)))
	_turn_manager.ai_positional_advantage_weight = maxf(0.0, float(weights.get("positional_advantage", _turn_manager.ai_positional_advantage_weight)))
	_turn_manager.ai_bump_opportunity_weight = maxf(0.0, float(weights.get("bump_opportunity", _turn_manager.ai_bump_opportunity_weight)))


func _normalize_ai_weights(raw_weights_variant: Variant, fallback_weights: Dictionary) -> Dictionary:
	var normalized: Dictionary = fallback_weights.duplicate(true)
	if normalized.is_empty():
		normalized = _capture_turn_manager_ai_weights()

	if not (raw_weights_variant is Dictionary):
		return normalized

	var raw_weights: Dictionary = raw_weights_variant
	for key in ["attack_value", "survival_risk", "positional_advantage", "bump_opportunity"]:
		if not raw_weights.has(key):
			continue
		normalized[key] = maxf(0.0, float(raw_weights.get(key, normalized[key])))

	return normalized


func _spawn_match_units(player_roster_paths: Array[String], enemy_roster_paths: Array[String]) -> void:
	var player_count: int = mini(player_roster_paths.size(), PLAYER_SPAWN_CELLS.size())
	for index in range(player_count):
		var player_puff: Puff = _spawn_unit(player_roster_paths[index], PLAYER_SPAWN_CELLS[index], TEAM_PLAYER, index)
		if player_puff != null:
			_player_units.append(player_puff)

	var enemy_count: int = mini(enemy_roster_paths.size(), ENEMY_SPAWN_CELLS.size())
	for index in range(enemy_count):
		var enemy_puff: Puff = _spawn_unit(enemy_roster_paths[index], ENEMY_SPAWN_CELLS[index], TEAM_ENEMY, index)
		if enemy_puff != null:
			_enemy_units.append(enemy_puff)


func _spawn_unit(data_path: String, spawn_cell: Vector2i, team: StringName, unit_index: int) -> Puff:
	if PUFF_SCENE == null or _turn_manager == null:
		return null

	var puff_variant: Node = PUFF_SCENE.instantiate()
	if not (puff_variant is Puff):
		if puff_variant != null:
			puff_variant.queue_free()
		return null

	var puff: Puff = puff_variant
	add_child(puff)
	puff.name = "%s_%s_%d" % [str(team).capitalize(), _name_slug_from_data_path(data_path), unit_index + 1]

	var puff_data_resource: Resource = _load_puff_data_for_team(data_path, team)
	if puff_data_resource != null:
		puff.set_puff_data(puff_data_resource)

	puff.set_grid_cell(spawn_cell)
	puff.set_battle_map(_battle_map)
	_turn_manager.register_puff(puff, team)

	var puff_name: StringName = StringName(puff.name)
	_unit_registry[puff_name] = puff
	_unit_state_by_name[puff_name] = {
		"name": str(puff_name),
		"team": str(team),
		"data_path": data_path,
		"spawn_cell": _to_json_safe(spawn_cell),
		"cell": _to_json_safe(spawn_cell),
		"alive": true
	}

	return puff


func _clear_spawned_units() -> void:
	for puff in _player_units:
		if puff != null and is_instance_valid(puff):
			puff.queue_free()
	for puff in _enemy_units:
		if puff != null and is_instance_valid(puff):
			puff.queue_free()

	_player_units.clear()
	_enemy_units.clear()
	_unit_registry.clear()
	_unit_state_by_name.clear()


func _on_turn_phase_changed(phase: StringName, active_side: StringName, turn_number: int) -> void:
	if not _battle_started or _battle_finished:
		return

	_record_battle_event(&"phase_changed", {
		"phase": str(phase),
		"active_side": str(active_side),
		"turn_number": turn_number
	})
	_update_hud()

	if phase == PHASE_PLAYER_SELECT and turn_number <= max_turns:
		_capture_player_turn_snapshot(turn_number)

	if phase == PHASE_PLAYER_SELECT and turn_number > max_turns:
		_latest_tile_control = _calculate_tile_control_totals()
		_battle_end_reason = &"turn_limit"
		var winner: StringName = _resolve_turn_limit_winner(_latest_tile_control)
		_record_battle_event(&"turn_limit_reached", {
			"winner": str(winner),
			"tile_control": _latest_tile_control
		})
		_turn_manager.end_battle(winner)


func _on_turn_manager_action_resolved(side: StringName, action_payload: Dictionary) -> void:
	if not _battle_started or _battle_finished:
		return
	if side != TEAM_PLAYER:
		return

	var current_turn_number: int = _turn_manager.turn_number if _turn_manager != null else 0
	var turn_index: int = int(action_payload.get("turn_number", current_turn_number))
	var action_copy: Dictionary = action_payload.duplicate(true)
	var result_summary: Dictionary = _summarize_player_action_result(action_copy)
	_upsert_turn_context(turn_index, {}, action_copy, result_summary)

	_record_battle_event(&"player_action_result", {
		"turn_number": turn_index,
		"action": action_copy,
		"result": result_summary
	})


func _on_signal_bus_puff_moved(puff_id: StringName, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not _battle_started or _battle_finished:
		return

	if _unit_state_by_name.has(puff_id):
		var state: Dictionary = _unit_state_by_name[puff_id]
		state["cell"] = _to_json_safe(to_cell)
		_unit_state_by_name[puff_id] = state

	_record_battle_event(&"puff_moved", {
		"puff_id": str(puff_id),
		"from_cell": from_cell,
		"to_cell": to_cell
	})


func _on_signal_bus_puff_bumped(puff_id: StringName, direction: Vector2i) -> void:
	if not _battle_started or _battle_finished:
		return

	_record_battle_event(&"puff_bumped", {
		"puff_id": str(puff_id),
		"direction": direction
	})


func _on_signal_bus_turn_ended(turn_number: int) -> void:
	if not _battle_started or _battle_finished:
		return

	_record_battle_event(&"turn_ended", {
		"turn_number": turn_number
	})
	_check_tile_control_win_condition()


func _on_signal_bus_battle_ended(result: StringName) -> void:
	if not _battle_started or _battle_finished:
		return

	_battle_finished = true
	_battle_winner = result
	if _battle_end_reason == &"":
		_battle_end_reason = &"elimination"

	_turn_manager.set_process_unhandled_input(false)
	_latest_tile_control = _calculate_tile_control_totals()

	var rewards: Dictionary = _build_rewards_summary(result)
	_record_battle_event(&"battle_ended", {
		"winner": str(result),
		"reason": str(_battle_end_reason),
		"rewards": rewards,
		"tile_control": _latest_tile_control
	})

	_battle_log_path = _persist_battle_log(result, rewards)
	_restore_player_ai_weights()
	call_deferred("_sync_async_pvp_after_battle", result, rewards)
	_show_result_overlay(result, rewards)
	_update_hud()


func _restore_player_ai_weights() -> void:
	if _player_ai_weights_for_match.is_empty():
		return
	_apply_turn_manager_ai_weights(_player_ai_weights_for_match)


func _sync_async_pvp_after_battle(result: StringName, rewards: Dictionary) -> void:
	if _pvp_async == null:
		return

	var battle_context: Dictionary = {
		"battle_id": _battle_id,
		"battle_log_path": _battle_log_path,
		"winner": str(result),
		"win_reason": str(_battle_end_reason),
		"turn_number": _turn_manager.turn_number if _turn_manager != null else 0,
		"rewards": rewards
	}

	if _pvp_async.has_method("upload_player_ghost"):
		var upload_result_variant: Variant = await _pvp_async.call(
			"upload_player_ghost",
			_selected_roster_paths.duplicate(),
			_player_ai_weights_for_match.duplicate(true),
			battle_context
		)
		if upload_result_variant is Dictionary:
			var upload_result: Dictionary = upload_result_variant
			if bool(upload_result.get("ok", false)):
				_record_battle_event(&"pvp_ghost_uploaded", {
					"player_team_count": _selected_roster_paths.size()
				})
			else:
				_record_battle_event(&"pvp_ghost_upload_failed", {
					"error": str(upload_result.get("error", "upload_failed"))
				})

	if _pvp_async.has_method("record_battle_result"):
		var sync_result_variant: Variant = await _pvp_async.call(
			"record_battle_result",
			_match_context.duplicate(true),
			result == TEAM_PLAYER,
			battle_context
		)
		if sync_result_variant is Dictionary:
			var sync_result: Dictionary = sync_result_variant
			if bool(sync_result.get("ok", false)):
				var elo_delta: int = int(sync_result.get("elo_delta", 0))
				_record_battle_event(&"pvp_result_synced", {
					"elo_delta": elo_delta,
					"player_elo_after": int(round(float(sync_result.get("player_elo_after", 0.0))))
				})
				_pvp_status_message = "Async PvP synced. ELO %+d." % elo_delta
			else:
				_pvp_status_message = "Async PvP sync pending: %s" % str(sync_result.get("error", "network unavailable"))
				_record_battle_event(&"pvp_result_sync_failed", {
					"error": str(sync_result.get("error", "sync_failed"))
				})

	_update_hud()


func _check_tile_control_win_condition() -> void:
	if _battle_map == null or _turn_manager == null:
		return

	_latest_tile_control = _calculate_tile_control_totals()
	_update_hud()

	var majority_tiles: int = _majority_tile_count()
	var player_control: int = int(_latest_tile_control.get(TEAM_PLAYER, 0))
	var enemy_control: int = int(_latest_tile_control.get(TEAM_ENEMY, 0))

	if player_control >= majority_tiles:
		_battle_end_reason = &"tile_control"
		_record_battle_event(&"tile_control_win", {
			"winner": str(TEAM_PLAYER),
			"tile_control": _latest_tile_control
		})
		_turn_manager.end_battle(TEAM_PLAYER)
		return

	if enemy_control >= majority_tiles:
		_battle_end_reason = &"tile_control"
		_record_battle_event(&"tile_control_win", {
			"winner": str(TEAM_ENEMY),
			"tile_control": _latest_tile_control
		})
		_turn_manager.end_battle(TEAM_ENEMY)


func _calculate_tile_control_totals() -> Dictionary:
	var totals: Dictionary = {
		TEAM_PLAYER: 0,
		TEAM_ENEMY: 0,
		TEAM_NEUTRAL: 0
	}
	if _battle_map == null:
		return totals

	var player_controllers: Array[Puff] = _collect_controlling_units(_player_units)
	var enemy_controllers: Array[Puff] = _collect_controlling_units(_enemy_units)

	for y in _battle_map.map_size.y:
		for x in _battle_map.map_size.x:
			var owner: StringName = _resolve_control_owner(Vector2i(x, y), player_controllers, enemy_controllers)
			totals[owner] = int(totals.get(owner, 0)) + 1

	return totals


func _collect_controlling_units(units: Array[Puff]) -> Array[Puff]:
	var controllers: Array[Puff] = []
	for puff in units:
		if puff == null or not is_instance_valid(puff):
			continue
		if not puff.visible:
			continue
		controllers.append(puff)
	return controllers


func _resolve_control_owner(cell: Vector2i, player_units: Array[Puff], enemy_units: Array[Puff]) -> StringName:
	var player_distance: int = _nearest_distance_to_cell(cell, player_units)
	var enemy_distance: int = _nearest_distance_to_cell(cell, enemy_units)

	if player_distance < enemy_distance:
		return TEAM_PLAYER
	if enemy_distance < player_distance:
		return TEAM_ENEMY
	return TEAM_NEUTRAL


func _nearest_distance_to_cell(cell: Vector2i, units: Array[Puff]) -> int:
	if units.is_empty():
		return 1_000_000

	var nearest: int = 1_000_000
	for puff in units:
		var distance: int = absi(puff.grid_cell.x - cell.x) + absi(puff.grid_cell.y - cell.y)
		if distance < nearest:
			nearest = distance
	return nearest


func _resolve_turn_limit_winner(tile_control: Dictionary) -> StringName:
	var player_control: int = int(tile_control.get(TEAM_PLAYER, 0))
	var enemy_control: int = int(tile_control.get(TEAM_ENEMY, 0))
	if player_control > enemy_control:
		return TEAM_PLAYER
	if enemy_control > player_control:
		return TEAM_ENEMY

	var player_alive: int = _count_alive_units(_player_units)
	var enemy_alive: int = _count_alive_units(_enemy_units)
	if player_alive >= enemy_alive:
		return TEAM_PLAYER
	return TEAM_ENEMY


func _count_alive_units(units: Array[Puff]) -> int:
	var alive_count: int = 0
	for puff in units:
		if puff == null:
			continue
		if not is_instance_valid(puff):
			continue
		alive_count += 1
	return alive_count


func _majority_tile_count() -> int:
	if _battle_map == null:
		return 0
	var total_tiles: int = _battle_map.map_size.x * _battle_map.map_size.y
	return int(total_tiles / 2) + 1


func _build_rewards_summary(winner: StringName) -> Dictionary:
	var is_victory: bool = winner == TEAM_PLAYER
	var turns_used: int = 0
	if _turn_manager != null:
		turns_used = maxi(1, _turn_manager.turn_number)

	var turn_efficiency_bonus: int = maxi(0, max_turns - turns_used) * 4 if is_victory else 0
	var base_xp: int = 24 if is_victory else 10
	var base_coins: int = 60 if is_victory else 25

	return {
		"xp": base_xp + turn_efficiency_bonus,
		"coins": base_coins + int(_latest_tile_control.get(TEAM_PLAYER, 0)),
		"star_dust": 3 if is_victory else 1
	}


func _show_result_overlay(winner: StringName, rewards: Dictionary) -> void:
	if _result_overlay == null:
		return

	var is_victory: bool = winner == TEAM_PLAYER
	_result_title_label.text = "Victory!" if is_victory else "Defeat"
	_result_title_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.95, 0.74, 1.0) if is_victory else Color(0.99, 0.72, 0.74, 1.0)
	)

	_result_summary_label.text = "Reason: %s\nTurns: %d / %d\nControl: %d player | %d enemy\nRewards: %d XP, %d coins, %d star dust\nLog: %s" % [
		str(_battle_end_reason).capitalize(),
		_turn_manager.turn_number if _turn_manager != null else 0,
		max_turns,
		int(_latest_tile_control.get(TEAM_PLAYER, 0)),
		int(_latest_tile_control.get(TEAM_ENEMY, 0)),
		int(rewards.get("xp", 0)),
		int(rewards.get("coins", 0)),
		int(rewards.get("star_dust", 0)),
		_battle_log_path
	]
	_result_overlay.visible = true


func _update_hud() -> void:
	if _hud_label == null:
		return

	if not _battle_started:
		var pre_battle_text: String = "Select 3-4 puffs from roster.\nWin by eliminating all enemies or controlling 13/25 tiles.\nFull match runs up to %d turns." % max_turns
		if not _pvp_status_message.is_empty():
			pre_battle_text += "\nPvP: %s" % _pvp_status_message
		_hud_label.text = pre_battle_text
		return

	var turn_number: int = _turn_manager.turn_number if _turn_manager != null else 0
	var player_control: int = int(_latest_tile_control.get(TEAM_PLAYER, 0))
	var enemy_control: int = int(_latest_tile_control.get(TEAM_ENEMY, 0))
	var neutral_control: int = int(_latest_tile_control.get(TEAM_NEUTRAL, 0))
	var status_text: String = "In Progress"
	if _battle_finished:
		status_text = "Finished (%s via %s)" % [str(_battle_winner), str(_battle_end_reason)]

	var hud_text: String = "Turn %d / %d\nStatus: %s\nTile Control: player %d, enemy %d, neutral %d\nMajority target: %d tiles" % [
		turn_number,
		max_turns,
		status_text,
		player_control,
		enemy_control,
		neutral_control,
		_majority_tile_count()
	]
	if not _pvp_status_message.is_empty():
		hud_text += "\nPvP: %s" % _pvp_status_message

	_hud_label.text = hud_text


func _initialize_battle_log() -> void:
	var started_unix: int = Time.get_unix_time_from_system()
	_battle_id = "full_battle_%d" % started_unix
	_battle_log_events.clear()
	_turn_context_by_number.clear()

	_battle_log_header = {
		"battle_id": _battle_id,
		"mode": "full_match",
		"started_at_unix": started_unix,
		"max_turns": max_turns,
		"map_config": _build_map_config_snapshot(),
		"selected_player_team": _selected_roster_paths.duplicate(),
		"enemy_team": _enemy_roster_paths.duplicate(),
		"pvp_match": _build_pvp_match_snapshot()
	}


func _record_battle_event(event_type: StringName, payload: Dictionary = {}) -> void:
	if not _battle_started:
		return

	var turn_number: int = _turn_manager.turn_number if _turn_manager != null else 0
	var phase: String = ""
	if _turn_manager != null:
		phase = str(_turn_manager.current_phase)

	_battle_log_events.append({
		"timestamp_unix": Time.get_unix_time_from_system(),
		"turn_number": turn_number,
		"phase": phase,
		"event": str(event_type),
		"payload": _to_json_safe(payload)
	})


func _persist_battle_log(winner: StringName, rewards: Dictionary) -> String:
	var completed_log: Dictionary = _battle_log_header.duplicate(true)
	completed_log["ended_at_unix"] = Time.get_unix_time_from_system()
	completed_log["winner"] = str(winner)
	completed_log["win_reason"] = str(_battle_end_reason)
	completed_log["turn_number"] = _turn_manager.turn_number if _turn_manager != null else 0
	completed_log["tile_control"] = _to_json_safe(_latest_tile_control)
	completed_log["rewards"] = _to_json_safe(rewards)
	completed_log["units"] = _serialize_unit_states()
	completed_log["events"] = _to_json_safe(_battle_log_events)
	completed_log["turn_summaries"] = _to_json_safe(_build_turn_summaries_for_extraction())

	var directory_absolute: String = ProjectSettings.globalize_path(LOG_DIRECTORY)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory_absolute)
	if mkdir_error != OK:
		push_warning("Failed creating battle log directory: %s" % directory_absolute)
		return ""

	var file_path: String = "%s/%s.json" % [LOG_DIRECTORY, _battle_id]
	var log_file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if log_file == null:
		push_warning("Failed writing battle log file at %s." % file_path)
		return ""

	log_file.store_string(JSON.stringify(_to_json_safe(completed_log), "\t"))
	log_file.close()
	return file_path


func _capture_player_turn_snapshot(turn_number: int) -> void:
	var turn_snapshot: Dictionary = _build_turn_snapshot_payload(turn_number)
	_upsert_turn_context(turn_number, turn_snapshot)
	_record_battle_event(&"player_turn_snapshot", turn_snapshot)


func _build_turn_snapshot_payload(turn_number: int) -> Dictionary:
	return {
		"turn_number": turn_number,
		"map_state_before_turn": _build_map_config_snapshot(),
		"puffs": _serialize_unit_states(),
		"enemy_intents": _build_enemy_intent_snapshot_array(),
		"team_hp": _calculate_team_hp_totals()
	}


func _build_map_config_snapshot() -> Dictionary:
	if _battle_map == null:
		return DEFAULT_MAP_CONFIG.duplicate(true)

	var map_size: Vector2i = _battle_map.map_size
	var rows: Array = []
	for y in map_size.y:
		var row: Array[String] = []
		for x in map_size.x:
			row.append(_battle_map.get_terrain_at(Vector2i(x, y)))
		rows.append(row)

	return {
		"width": map_size.x,
		"height": map_size.y,
		"rows": rows
	}


func _build_pvp_match_snapshot() -> Dictionary:
	var opponent_profile: Dictionary = {}
	var opponent_profile_variant: Variant = _match_context.get("opponent_profile", {})
	if opponent_profile_variant is Dictionary:
		opponent_profile = opponent_profile_variant.duplicate(true)

	return {
		"opponent_profile": opponent_profile,
		"opponent_ghost": _opponent_ghost_payload.duplicate(true),
		"player_ai_weights": _player_ai_weights_for_match.duplicate(true)
	}


func _build_enemy_intent_snapshot_array() -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	if _turn_manager == null:
		return intents

	var intents_variant: Variant = _turn_manager.get_enemy_intent_snapshot()
	if not (intents_variant is Dictionary):
		return intents

	var intents_by_enemy_id: Dictionary = intents_variant
	for intent_variant in intents_by_enemy_id.values():
		if not (intent_variant is Dictionary):
			continue
		intents.append(intent_variant.duplicate(true))

	return intents


func _calculate_team_hp_totals() -> Dictionary:
	var totals: Dictionary = {
		TEAM_PLAYER: 0,
		TEAM_ENEMY: 0
	}
	if _turn_manager == null:
		return totals

	for player_puff in _turn_manager.get_alive_team_snapshot(TEAM_PLAYER):
		totals[TEAM_PLAYER] = int(totals.get(TEAM_PLAYER, 0)) + _turn_manager.get_current_hp(player_puff)
	for enemy_puff in _turn_manager.get_alive_team_snapshot(TEAM_ENEMY):
		totals[TEAM_ENEMY] = int(totals.get(TEAM_ENEMY, 0)) + _turn_manager.get_current_hp(enemy_puff)

	return totals


func _summarize_player_action_result(action_payload: Dictionary) -> Dictionary:
	var hp_swing_ratio: float = float(action_payload.get("hp_swing_ratio", 0.0))
	var knockout_count: int = int(action_payload.get("knockout_count", 0))
	var knockout_occurred: bool = bool(action_payload.get("knockout", false)) or knockout_count > 0
	var action_type: String = str(action_payload.get("action", ""))
	var unique_skill_id: String = str(action_payload.get("skill_id", ""))
	var unique_skill_changed_outcome: bool = (
		action_type == "skill"
		and not unique_skill_id.is_empty()
		and (bool(action_payload.get("changed_outcome", false)) or knockout_occurred or hp_swing_ratio >= 0.3)
	)

	return {
		"hp_swing": int(action_payload.get("hp_swing", 0)),
		"hp_swing_ratio": hp_swing_ratio,
		"meets_hp_swing_threshold": hp_swing_ratio >= 0.3,
		"knockout_occurred": knockout_occurred,
		"knockout_count": knockout_count,
		"unique_skill_id": unique_skill_id,
		"unique_skill_changed_outcome": unique_skill_changed_outcome
	}


func _upsert_turn_context(
	turn_number: int,
	before_snapshot: Dictionary = {},
	player_action: Dictionary = {},
	result: Dictionary = {}
) -> void:
	var context: Dictionary = _turn_context_by_number.get(turn_number, {
		"turn_number": turn_number,
		"before_snapshot": {},
		"player_action": {},
		"result": {}
	})

	if not before_snapshot.is_empty():
		context["before_snapshot"] = before_snapshot.duplicate(true)
	if not player_action.is_empty():
		context["player_action"] = player_action.duplicate(true)
	if not result.is_empty():
		context["result"] = result.duplicate(true)

	_turn_context_by_number[turn_number] = context


func _build_turn_summaries_for_extraction() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	var turn_numbers: Array[int] = []

	for turn_variant in _turn_context_by_number.keys():
		turn_numbers.append(int(turn_variant))
	turn_numbers.sort()

	for turn_index in turn_numbers:
		var context_variant: Variant = _turn_context_by_number.get(turn_index, null)
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant
		var before_snapshot_variant: Variant = context.get("before_snapshot", {})
		var player_action_variant: Variant = context.get("player_action", {})
		var result_variant: Variant = context.get("result", {})
		var before_snapshot: Dictionary = before_snapshot_variant.duplicate(true) if before_snapshot_variant is Dictionary else {}
		var player_action: Dictionary = player_action_variant.duplicate(true) if player_action_variant is Dictionary else {}
		var result: Dictionary = result_variant.duplicate(true) if result_variant is Dictionary else {}

		summaries.append(
			{
				"turn_number": turn_index,
				"before_snapshot": before_snapshot,
				"player_action": player_action,
				"result": result
			}
		)

	return summaries


func _serialize_unit_states() -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	for unit_name_variant in _unit_state_by_name.keys():
		var unit_name: StringName = unit_name_variant
		var state: Dictionary = _unit_state_by_name[unit_name].duplicate(true)
		var puff_variant: Variant = _unit_registry.get(unit_name)
		if puff_variant is Puff and is_instance_valid(puff_variant):
			var puff: Puff = puff_variant
			state["alive"] = true
			state["visible"] = puff.visible
			state["cell"] = _to_json_safe(puff.grid_cell)
			var puff_data: PuffData = puff.puff_data as PuffData
			if puff_data != null:
				if puff_data.has_method("get_effective_hp"):
					state["max_hp"] = int(puff_data.call("get_effective_hp"))
				else:
					state["max_hp"] = puff_data.hp
				state["level"] = int(puff_data.get("level"))
				state["unique_skill_id"] = str(puff_data.unique_skill_id)
			if _turn_manager != null:
				state["hp"] = _turn_manager.get_current_hp(puff)
		else:
			state["alive"] = false
			state["visible"] = false
			if not state.has("hp"):
				state["hp"] = 0
		units.append(state)
	return units


func _name_slug_from_data_path(data_path: String) -> String:
	if data_path.is_empty():
		return "unit"
	return data_path.get_file().trim_suffix(".tres")


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


func _to_json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var out_dictionary: Dictionary = {}
		for key_variant in value.keys():
			out_dictionary[str(key_variant)] = _to_json_safe(value[key_variant])
		return out_dictionary

	if value is Array:
		var out_array: Array = []
		for item_variant in value:
			out_array.append(_to_json_safe(item_variant))
		return out_array

	if value is Vector2i:
		return {"x": value.x, "y": value.y}

	if value is Vector2:
		return {"x": value.x, "y": value.y}

	if value is StringName:
		return str(value)

	return value


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
