extends Control
class_name PuzzleEditor

signal published(snapshot_id: String, status_text: String)
signal status_changed(status_text: String)

const BATTLE_MAP_SCENE: PackedScene = preload("res://src/scenes/maps/BattleMap.tscn")
const PUFF_SCENE: PackedScene = preload("res://src/scenes/puffs/Puff.tscn")
const FEED_ITEM_SCRIPT: GDScript = preload("res://src/scripts/feed/feed_item.gd")
const PUFF_DATA_SCRIPT: GDScript = preload("res://src/scripts/puffs/puff_data.gd")

const UGC_PUZZLES_TABLE: String = "ugc_puzzles"

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

const TOOL_TERRAIN: int = 0
const TOOL_PUFF: int = 1

const TEMPLATE_BUMP_TO_CLIFF_KILL: StringName = &"bump-to-cliff-kill"
const TEMPLATE_DEFEAT_N_IN_1_TURN: StringName = &"defeat-n-in-1-turn"
const TEMPLATE_HEAL_ALL_ALLIES: StringName = &"heal-all-allies"
const TEMPLATE_MINIMUM_MOVES: StringName = &"minimum-moves"

const SUPPORTED_WIN_TEMPLATES: Array[StringName] = [
	TEMPLATE_BUMP_TO_CLIFF_KILL,
	TEMPLATE_DEFEAT_N_IN_1_TURN,
	TEMPLATE_HEAL_ALL_ALLIES,
	TEMPLATE_MINIMUM_MOVES
]

const TERRAIN_TYPES: Array[String] = [
	"cloud",
	"high_cloud",
	"cotton_candy",
	"puddle",
	"cliff",
	"mushroom"
]

const TEAM_OPTIONS: Array[StringName] = [TEAM_PLAYER, TEAM_ENEMY]

const ELEMENT_OPTIONS: Array[int] = [
	Constants.Element.FIRE,
	Constants.Element.WATER,
	Constants.Element.GRASS,
	Constants.Element.WIND,
	Constants.Element.STAR
]

const CLASS_OPTIONS: Array[int] = [
	Constants.PuffClass.CLOUD,
	Constants.PuffClass.FLAME,
	Constants.PuffClass.DROPLET,
	Constants.PuffClass.LEAF,
	Constants.PuffClass.WHIRL,
	Constants.PuffClass.STAR
]

const TEAM_LABELS: Dictionary = {
	TEAM_PLAYER: "Player",
	TEAM_ENEMY: "Enemy"
}

const ELEMENT_LABELS_BY_ID: Dictionary = {
	Constants.Element.FIRE: "Fire",
	Constants.Element.WATER: "Water",
	Constants.Element.GRASS: "Grass",
	Constants.Element.WIND: "Wind",
	Constants.Element.STAR: "Star"
}

const CLASS_LABELS_BY_ID: Dictionary = {
	Constants.PuffClass.CLOUD: "Cloud (Tank)",
	Constants.PuffClass.FLAME: "Flame (Melee)",
	Constants.PuffClass.DROPLET: "Droplet (Ranged)",
	Constants.PuffClass.LEAF: "Leaf (Healer)",
	Constants.PuffClass.WHIRL: "Whirl (Mobility)",
	Constants.PuffClass.STAR: "Star (Wildcard)"
}

const TEMPLATE_LABELS_BY_ID: Dictionary = {
	TEMPLATE_BUMP_TO_CLIFF_KILL: "Bump To Cliff Kill",
	TEMPLATE_DEFEAT_N_IN_1_TURN: "Defeat N In 1 Turn",
	TEMPLATE_HEAL_ALL_ALLIES: "Heal All Allies",
	TEMPLATE_MINIMUM_MOVES: "Minimum Moves"
}

const CLASS_TO_DATA_PATH: Dictionary = {
	Constants.PuffClass.CLOUD: "res://src/resources/puffs/base/cloud_tank.tres",
	Constants.PuffClass.FLAME: "res://src/resources/puffs/base/flame_melee.tres",
	Constants.PuffClass.DROPLET: "res://src/resources/puffs/base/droplet_ranged.tres",
	Constants.PuffClass.LEAF: "res://src/resources/puffs/base/leaf_healer.tres",
	Constants.PuffClass.WHIRL: "res://src/resources/puffs/base/whirl_mobility.tres",
	Constants.PuffClass.STAR: "res://src/resources/puffs/base/star_wildcard.tres"
}

const DEFAULT_TARGET_SCORE: int = 240

@onready var status_label: Label = $Panel/RootLayout/Header/StatusLabel
@onready var close_button: Button = $Panel/RootLayout/Header/CloseButton
@onready var board_area: ColorRect = $Panel/RootLayout/Body/EditorColumn/BoardArea
@onready var board_root: Node2D = $Panel/RootLayout/Body/EditorColumn/BoardArea/BoardRoot
@onready var selection_label: Label = $Panel/RootLayout/Body/EditorColumn/SelectionLabel
@onready var puzzle_title_edit: LineEdit = $Panel/RootLayout/Body/ControlColumn/PuzzleTitleEdit
@onready var tool_option_button: OptionButton = $Panel/RootLayout/Body/ControlColumn/ToolOptionButton
@onready var terrain_option_button: OptionButton = $Panel/RootLayout/Body/ControlColumn/TerrainOptionButton
@onready var team_option_button: OptionButton = $Panel/RootLayout/Body/ControlColumn/TeamOptionButton
@onready var element_option_button: OptionButton = $Panel/RootLayout/Body/ControlColumn/ElementOptionButton
@onready var class_option_button: OptionButton = $Panel/RootLayout/Body/ControlColumn/ClassOptionButton
@onready var win_template_option_button: OptionButton = $Panel/RootLayout/Body/ControlColumn/WinTemplateOptionButton
@onready var target_score_spin_box: SpinBox = $Panel/RootLayout/Body/ControlColumn/TargetScoreSpinBox
@onready var apply_puff_button: Button = $Panel/RootLayout/Body/ControlColumn/ApplyPuffButton
@onready var remove_puff_button: Button = $Panel/RootLayout/Body/ControlColumn/RemovePuffButton
@onready var clear_board_button: Button = $Panel/RootLayout/Body/ControlColumn/ClearBoardButton
@onready var test_play_button: Button = $Panel/RootLayout/Body/ControlColumn/TestPlayButton
@onready var publish_button: Button = $Panel/RootLayout/Body/ControlColumn/PublishButton
@onready var publish_status_label: Label = $Panel/RootLayout/Body/ControlColumn/PublishStatusLabel
@onready var test_play_layer: Control = $TestPlayLayer
@onready var test_play_root: Node2D = $TestPlayLayer/TestPlayRoot
@onready var exit_test_play_button: Button = $TestPlayLayer/ExitTestPlayButton

var _battle_map: BattleMap
var _puff_state_by_id: Dictionary = {}
var _next_puff_id: int = 1
var _selected_puff_id: String = ""

var _is_drag_active: bool = false
var _is_terrain_painting: bool = false
var _dragging_puff_id: String = ""

var _active_test_feed_item: Node2D
var _current_test_snapshot_json: String = ""
var _last_tested_snapshot_json: String = ""


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_option_buttons()
	_setup_board()
	_connect_ui()
	_update_selection_label()
	_set_status("Drag to paint terrain or place puffs. Run test-play before publishing.")
	_set_publish_status("Test-play required before publishing.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_refresh_board_layout")


func show_editor() -> void:
	visible = true
	move_to_front()
	_set_status("UGC editor ready. Terrain tool paints tiles; Puff tool drags units.")
	_update_selection_label()


func hide_editor() -> void:
	_close_test_play_overlay()
	visible = false


func is_editor_open() -> bool:
	return visible


func get_status_text() -> String:
	if status_label == null:
		return ""
	return status_label.text


func _setup_option_buttons() -> void:
	tool_option_button.clear()
	tool_option_button.add_item("Terrain Paint", TOOL_TERRAIN)
	tool_option_button.add_item("Puff Drag", TOOL_PUFF)
	_select_option_by_id(tool_option_button, TOOL_TERRAIN)

	terrain_option_button.clear()
	for terrain_index in TERRAIN_TYPES.size():
		var terrain_name: String = TERRAIN_TYPES[terrain_index]
		terrain_option_button.add_item(terrain_name.capitalize(), terrain_index)
	_select_option_by_id(terrain_option_button, 0)

	team_option_button.clear()
	for team_index in TEAM_OPTIONS.size():
		var team: StringName = TEAM_OPTIONS[team_index]
		var label: String = str(TEAM_LABELS.get(team, String(team)))
		team_option_button.add_item(label, team_index)
	_select_option_by_id(team_option_button, 0)

	element_option_button.clear()
	for element_id in ELEMENT_OPTIONS:
		var element_label: String = str(ELEMENT_LABELS_BY_ID.get(element_id, str(element_id)))
		element_option_button.add_item(element_label, element_id)
	_select_option_by_id(element_option_button, Constants.Element.STAR)

	class_option_button.clear()
	for class_id in CLASS_OPTIONS:
		var class_label: String = str(CLASS_LABELS_BY_ID.get(class_id, str(class_id)))
		class_option_button.add_item(class_label, class_id)
	_select_option_by_id(class_option_button, Constants.PuffClass.STAR)

	win_template_option_button.clear()
	for template_id in SUPPORTED_WIN_TEMPLATES:
		var template_label: String = str(TEMPLATE_LABELS_BY_ID.get(template_id, String(template_id)))
		win_template_option_button.add_item(template_label)
		var item_index: int = win_template_option_button.item_count - 1
		win_template_option_button.set_item_metadata(item_index, String(template_id))
	win_template_option_button.select(0)

	target_score_spin_box.min_value = 100.0
	target_score_spin_box.max_value = 600.0
	target_score_spin_box.step = 5.0
	target_score_spin_box.value = float(DEFAULT_TARGET_SCORE)


func _setup_board() -> void:
	var battle_map_variant: Node = BATTLE_MAP_SCENE.instantiate()
	if not (battle_map_variant is BattleMap):
		battle_map_variant.queue_free()
		push_warning("PuzzleEditor could not instantiate BattleMap.")
		return

	_battle_map = battle_map_variant
	board_root.add_child(_battle_map)
	_battle_map.load_map_from_config(_default_map_config())

	call_deferred("_refresh_board_layout")


func _connect_ui() -> void:
	_connect_if_needed(close_button, &"pressed", Callable(self, "hide_editor"))
	_connect_if_needed(board_area, &"gui_input", Callable(self, "_on_board_area_gui_input"))
	_connect_if_needed(apply_puff_button, &"pressed", Callable(self, "_on_apply_puff_button_pressed"))
	_connect_if_needed(remove_puff_button, &"pressed", Callable(self, "_on_remove_puff_button_pressed"))
	_connect_if_needed(clear_board_button, &"pressed", Callable(self, "_on_clear_board_button_pressed"))
	_connect_if_needed(test_play_button, &"pressed", Callable(self, "_on_test_play_button_pressed"))
	_connect_if_needed(publish_button, &"pressed", Callable(self, "_on_publish_button_pressed"))
	_connect_if_needed(exit_test_play_button, &"pressed", Callable(self, "_on_exit_test_play_button_pressed"))
	_connect_if_needed(team_option_button, &"item_selected", Callable(self, "_on_puff_option_changed"))
	_connect_if_needed(element_option_button, &"item_selected", Callable(self, "_on_puff_option_changed"))
	_connect_if_needed(class_option_button, &"item_selected", Callable(self, "_on_puff_option_changed"))
	_connect_if_needed(puzzle_title_edit, &"text_changed", Callable(self, "_on_editor_content_changed"))
	_connect_if_needed(win_template_option_button, &"item_selected", Callable(self, "_on_editor_content_changed"))
	_connect_if_needed(target_score_spin_box, &"value_changed", Callable(self, "_on_editor_content_changed"))


func _refresh_board_layout() -> void:
	if _battle_map == null:
		return
	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return

	var min_point: Vector2 = Vector2(1000000.0, 1000000.0)
	var max_point: Vector2 = Vector2(-1000000.0, -1000000.0)

	for y in _battle_map.map_size.y:
		for x in _battle_map.map_size.x:
			var point: Vector2 = tile_map_layer.position + tile_map_layer.map_to_local(Vector2i(x, y))
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)

	var map_center: Vector2 = (min_point + max_point) * 0.5
	var area_center: Vector2 = board_area.size * 0.5
	board_root.position = area_center - map_center


func _on_board_area_gui_input(event: InputEvent) -> void:
	if not visible or _battle_map == null:
		return
	if _is_test_play_open():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_board_drag(event.position)
		else:
			_finish_board_drag(event.position)
		return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_continue_board_drag(event.position)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_board_drag(event.position)
		else:
			_finish_board_drag(event.position)
		return

	if event is InputEventScreenDrag:
		_continue_board_drag(event.position)


func _begin_board_drag(board_position: Vector2) -> void:
	var target_cell: Vector2i = _board_position_to_cell(board_position)
	if not _is_valid_cell(target_cell):
		return

	_is_drag_active = true
	_is_terrain_painting = _selected_tool() == TOOL_TERRAIN
	_dragging_puff_id = ""

	if _is_terrain_painting:
		_paint_terrain_cell(target_cell)
		return

	var puff_id: String = _find_puff_id_at_cell(target_cell)
	if puff_id.is_empty():
		puff_id = _create_puff_at_cell(target_cell)
	if puff_id.is_empty():
		return

	_dragging_puff_id = puff_id
	_select_puff(puff_id)
	_move_puff_to_cell(puff_id, target_cell)


func _continue_board_drag(board_position: Vector2) -> void:
	if not _is_drag_active:
		return

	var target_cell: Vector2i = _board_position_to_cell(board_position)
	if not _is_valid_cell(target_cell):
		return

	if _is_terrain_painting:
		_paint_terrain_cell(target_cell)
		return

	if not _dragging_puff_id.is_empty():
		_move_puff_to_cell(_dragging_puff_id, target_cell)


func _finish_board_drag(board_position: Vector2) -> void:
	if not _is_drag_active:
		return
	_continue_board_drag(board_position)
	_is_drag_active = false
	_is_terrain_painting = false
	_dragging_puff_id = ""


func _paint_terrain_cell(cell: Vector2i) -> void:
	if _battle_map == null or not _is_valid_cell(cell):
		return

	var terrain_type: String = _selected_terrain_type()
	if _battle_map.get_terrain_at(cell) == terrain_type:
		return

	_battle_map.set_terrain_at(cell, terrain_type)
	_invalidate_test_play_state()


func _create_puff_at_cell(cell: Vector2i) -> String:
	if not _is_valid_cell(cell):
		return ""

	var existing_id: String = _find_puff_id_at_cell(cell)
	if not existing_id.is_empty():
		return existing_id

	var puff_id: String = "ugc_puff_%d" % _next_puff_id
	_next_puff_id += 1

	var puff_class: int = _selected_puff_class()
	var puff_state: Dictionary = {
		"id": puff_id,
		"name": puff_id,
		"team": _selected_team(),
		"cell": cell,
		"element": _selected_element(),
		"puff_class": puff_class,
		"data_path": _data_path_for_class(puff_class),
		"node": null
	}
	_puff_state_by_id[puff_id] = puff_state
	_ensure_puff_node(puff_id)
	_select_puff(puff_id)
	_invalidate_test_play_state()
	return puff_id


func _move_puff_to_cell(puff_id: String, target_cell: Vector2i) -> void:
	if puff_id.is_empty() or not _puff_state_by_id.has(puff_id):
		return
	if not _is_valid_cell(target_cell):
		return

	var blocker_id: String = _find_puff_id_at_cell(target_cell)
	if not blocker_id.is_empty() and blocker_id != puff_id:
		return

	var puff_state: Dictionary = _puff_state_by_id[puff_id]
	var current_cell: Vector2i = _to_cell(puff_state.get("cell", Vector2i.ZERO))
	if current_cell == target_cell:
		return

	puff_state["cell"] = target_cell
	_puff_state_by_id[puff_id] = puff_state
	_ensure_puff_node(puff_id)
	_invalidate_test_play_state()
	_update_selection_label()


func _ensure_puff_node(puff_id: String) -> void:
	if not _puff_state_by_id.has(puff_id):
		return

	var puff_state: Dictionary = _puff_state_by_id[puff_id]
	var puff_node: Puff = null
	var existing_node_variant: Variant = puff_state.get("node")
	if existing_node_variant is Puff and is_instance_valid(existing_node_variant):
		puff_node = existing_node_variant
	else:
		var puff_variant: Node = PUFF_SCENE.instantiate()
		if not (puff_variant is Puff):
			puff_variant.queue_free()
			return
		puff_node = puff_variant
		board_root.add_child(puff_node)
		puff_state["node"] = puff_node
		_puff_state_by_id[puff_id] = puff_state

	var puff_data: Resource = _build_runtime_puff_data(puff_state)
	if puff_data != null:
		puff_node.set_puff_data(puff_data)

	puff_node.set_battle_map(_battle_map)
	puff_node.set_grid_cell(_to_cell(puff_state.get("cell", Vector2i.ZERO)))
	puff_node.name = puff_id
	puff_node.modulate = _team_color(_normalize_team(puff_state.get("team", TEAM_ENEMY)))
	_refresh_selection_highlight()


func _build_runtime_puff_data(puff_state: Dictionary) -> Resource:
	var puff_class: int = int(puff_state.get("puff_class", Constants.PuffClass.STAR))
	var data_path: String = str(puff_state.get("data_path", _data_path_for_class(puff_class)))
	var base_resource: Resource = load(data_path)
	var runtime_data: Resource = null

	if base_resource != null:
		runtime_data = base_resource.duplicate(true)
	else:
		var fallback_variant: Variant = PUFF_DATA_SCRIPT.new()
		if fallback_variant is Resource:
			runtime_data = fallback_variant

	if runtime_data == null:
		return null

	runtime_data.set("element", int(puff_state.get("element", Constants.Element.STAR)))
	runtime_data.set("puff_class", puff_class)
	runtime_data.set("display_name", StringName(_build_puff_display_name(puff_state)))
	return runtime_data


func _refresh_selection_highlight() -> void:
	for puff_id_variant in _puff_state_by_id.keys():
		var puff_id: String = str(puff_id_variant)
		var puff_state: Dictionary = _puff_state_by_id[puff_id]
		var puff_node_variant: Variant = puff_state.get("node")
		if not (puff_node_variant is Puff):
			continue
		var puff_node: Puff = puff_node_variant
		if not is_instance_valid(puff_node):
			continue

		var base_color: Color = _team_color(_normalize_team(puff_state.get("team", TEAM_ENEMY)))
		if puff_id == _selected_puff_id:
			puff_node.scale = Vector2(1.12, 1.12)
			puff_node.z_index = 6
			puff_node.modulate = base_color.lightened(0.12)
		else:
			puff_node.scale = Vector2.ONE
			puff_node.z_index = 1
			puff_node.modulate = base_color


func _select_puff(puff_id: String) -> void:
	if puff_id.is_empty() or not _puff_state_by_id.has(puff_id):
		_selected_puff_id = ""
		_update_selection_label()
		_refresh_selection_highlight()
		return

	_selected_puff_id = puff_id
	_sync_controls_from_selected_puff()
	_update_selection_label()
	_refresh_selection_highlight()


func _sync_controls_from_selected_puff() -> void:
	if _selected_puff_id.is_empty() or not _puff_state_by_id.has(_selected_puff_id):
		return

	var puff_state: Dictionary = _puff_state_by_id[_selected_puff_id]
	var team: StringName = _normalize_team(puff_state.get("team", TEAM_ENEMY))
	var team_index: int = TEAM_OPTIONS.find(team)
	if team_index == -1:
		team_index = 0
	_select_option_by_id(team_option_button, team_index)
	_select_option_by_id(element_option_button, int(puff_state.get("element", Constants.Element.STAR)))
	_select_option_by_id(class_option_button, int(puff_state.get("puff_class", Constants.PuffClass.STAR)))


func _on_apply_puff_button_pressed() -> void:
	if _selected_puff_id.is_empty():
		_set_status("Select or place a puff first.")
		return
	_apply_selected_options_to_puff(_selected_puff_id)
	_set_status("Updated puff %s settings." % _selected_puff_id)


func _on_remove_puff_button_pressed() -> void:
	if _selected_puff_id.is_empty():
		_set_status("Select a puff to remove.")
		return

	var puff_state: Dictionary = _puff_state_by_id.get(_selected_puff_id, {})
	var puff_node_variant: Variant = puff_state.get("node")
	if puff_node_variant is Puff and is_instance_valid(puff_node_variant):
		puff_node_variant.queue_free()

	_puff_state_by_id.erase(_selected_puff_id)
	_selected_puff_id = ""
	_invalidate_test_play_state()
	_update_selection_label()
	_refresh_selection_highlight()
	_set_status("Selected puff removed.")


func _on_clear_board_button_pressed() -> void:
	_clear_all_puffs()
	if _battle_map != null:
		_battle_map.load_map_from_config(_default_map_config())
	call_deferred("_refresh_board_layout")
	_invalidate_test_play_state()
	_set_status("Board reset to blank cloud map.")


func _clear_all_puffs() -> void:
	for puff_id_variant in _puff_state_by_id.keys():
		var puff_state: Dictionary = _puff_state_by_id[str(puff_id_variant)]
		var puff_node_variant: Variant = puff_state.get("node")
		if puff_node_variant is Puff and is_instance_valid(puff_node_variant):
			puff_node_variant.queue_free()
	_puff_state_by_id.clear()
	_selected_puff_id = ""
	_update_selection_label()
	_refresh_selection_highlight()


func _on_test_play_button_pressed() -> void:
	if _puff_state_by_id.is_empty():
		_set_status("Place at least one puff before test-play.")
		return

	var snapshot: Dictionary = _build_snapshot()
	_current_test_snapshot_json = JSON.stringify(_to_json_safe(snapshot))
	_open_test_play_overlay(snapshot)


func _open_test_play_overlay(snapshot: Dictionary) -> void:
	_close_test_play_overlay()

	var feed_item_variant: Variant = FEED_ITEM_SCRIPT.new()
	if not (feed_item_variant is Node2D):
		_set_status("FeedItem script unavailable for test-play.")
		return

	_active_test_feed_item = feed_item_variant
	test_play_root.add_child(_active_test_feed_item)
	_active_test_feed_item.position = _resolve_test_play_position()
	if _active_test_feed_item.has_method("configure_snapshot"):
		_active_test_feed_item.call("configure_snapshot", snapshot)
	if _active_test_feed_item.has_method("set_interaction_enabled"):
		_active_test_feed_item.call("set_interaction_enabled", true)

	_connect_if_needed(_active_test_feed_item, &"cycle_completed", Callable(self, "_on_test_play_cycle_completed"))
	test_play_layer.visible = true
	move_to_front()
	_set_status("Test-play running. Complete the turn to unlock publish.")


func _on_test_play_cycle_completed(score: int, cycle_duration_seconds: float) -> void:
	_last_tested_snapshot_json = _current_test_snapshot_json
	_set_publish_status("Test-play passed (%d score in %.1fs). Ready to publish." % [score, cycle_duration_seconds])
	_set_status("Test-play complete. Publish to ugc_puzzles when ready.")
	_close_test_play_overlay()


func _on_exit_test_play_button_pressed() -> void:
	_close_test_play_overlay()
	_set_status("Test-play closed.")


func _close_test_play_overlay() -> void:
	if _active_test_feed_item != null and is_instance_valid(_active_test_feed_item):
		_active_test_feed_item.queue_free()
	_active_test_feed_item = null
	test_play_layer.visible = false


func _on_publish_button_pressed() -> void:
	if _puff_state_by_id.is_empty():
		_set_status("Cannot publish an empty board.")
		return

	var snapshot: Dictionary = _build_snapshot()
	var safe_snapshot: Variant = _to_json_safe(snapshot)
	var snapshot_json: String = JSON.stringify(safe_snapshot)

	if _last_tested_snapshot_json != snapshot_json:
		_set_publish_status("Publish blocked: run test-play for this exact puzzle version first.")
		_set_status("Test-play is required before publish.")
		return

	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null or not supabase_client.has_method("request_rest"):
		_set_publish_status("Publish failed: SupabaseClient autoload is unavailable.")
		_set_status("Could not publish puzzle.")
		return

	var payload: Dictionary = {
		"title": _resolve_puzzle_title(),
		"snapshot": safe_snapshot,
		"snapshot_json": snapshot_json,
		"win_template": String(_selected_win_template()),
		"created_by": _resolve_creator_identity(supabase_client)
	}

	var response_variant: Variant = await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_POST,
		UGC_PUZZLES_TABLE,
		{},
		[payload],
		["Prefer: return=representation"]
	)

	if not (response_variant is Dictionary):
		_set_publish_status("Publish failed: invalid Supabase response payload.")
		_set_status("Could not publish puzzle.")
		return

	var response: Dictionary = response_variant
	if not bool(response.get("ok", false)):
		var error_text: String = str(response.get("error", "Unknown error"))
		_set_publish_status("Publish failed: %s" % error_text)
		_set_status("Supabase upload to ugc_puzzles failed.")
		return

	var puzzle_id: String = _extract_inserted_puzzle_id(response.get("data", []))
	var status_text: String = "Published to ugc_puzzles%s." % (" (id %s)" % puzzle_id if not puzzle_id.is_empty() else "")
	_set_publish_status(status_text)
	_set_status("UGC puzzle uploaded.")
	emit_signal("published", puzzle_id, status_text)


func _build_snapshot() -> Dictionary:
	var map_size: Vector2i = _battle_map.map_size if _battle_map != null else Constants.GRID_SIZE
	var map_config: Dictionary = {
		"width": map_size.x,
		"height": map_size.y,
		"rows": _build_rows_from_map(map_size)
	}

	var puffs: Array = []
	var sorted_ids: Array[String] = []
	for puff_id_variant in _puff_state_by_id.keys():
		sorted_ids.append(str(puff_id_variant))
	sorted_ids.sort()

	for puff_id in sorted_ids:
		var puff_state: Dictionary = _puff_state_by_id[puff_id]
		puffs.append(
			{
				"name": puff_id,
				"team": String(_normalize_team(puff_state.get("team", TEAM_ENEMY))),
				"data_path": str(
					puff_state.get(
						"data_path",
						_data_path_for_class(int(puff_state.get("puff_class", Constants.PuffClass.STAR)))
					)
				),
				"cell": _to_cell(puff_state.get("cell", Vector2i.ZERO)),
				"element": int(puff_state.get("element", Constants.Element.STAR)),
				"puff_class": int(puff_state.get("puff_class", Constants.PuffClass.STAR))
			}
		)

	var objective: Dictionary = _build_objective_from_template(_selected_win_template())

	return {
		"title": _resolve_puzzle_title(),
		"map_config": map_config,
		"puffs": puffs,
		"enemy_intents": [],
		"target_score": int(round(target_score_spin_box.value)),
		"puzzle_meta": {
			"source": "ugc_editor",
			"template": _selected_win_template(),
			"objective": objective
		}
	}


func _build_rows_from_map(map_size: Vector2i) -> Array:
	var rows: Array = []
	for y in map_size.y:
		var row: Array = []
		for x in map_size.x:
			var cell: Vector2i = Vector2i(x, y)
			var terrain_type: String = "cloud"
			if _battle_map != null:
				terrain_type = _battle_map.get_terrain_at(cell)
			row.append(terrain_type)
		rows.append(row)
	return rows


func _build_objective_from_template(template_id: StringName) -> Dictionary:
	match template_id:
		TEMPLATE_BUMP_TO_CLIFF_KILL:
			return {
				"type": TEMPLATE_BUMP_TO_CLIFF_KILL,
				"required_cliff_falls": 1
			}
		TEMPLATE_DEFEAT_N_IN_1_TURN:
			return {
				"type": TEMPLATE_DEFEAT_N_IN_1_TURN,
				"required_defeats": 1
			}
		TEMPLATE_HEAL_ALL_ALLIES:
			return {
				"type": TEMPLATE_HEAL_ALL_ALLIES,
				"require_all_allies_full": true
			}
		TEMPLATE_MINIMUM_MOVES:
			return {
				"type": TEMPLATE_MINIMUM_MOVES,
				"minimum_moves": 2
			}
		_:
			return {
				"type": TEMPLATE_BUMP_TO_CLIFF_KILL
			}


func _resolve_supabase_client() -> Node:
	return get_node_or_null("/root/SupabaseClient")


func _resolve_creator_identity(supabase_client: Node) -> String:
	if supabase_client == null:
		return "ugc_guest"

	if supabase_client.has_method("get_authenticated_user_id"):
		var user_id: String = str(supabase_client.call("get_authenticated_user_id"))
		if not user_id.is_empty():
			return user_id

	if supabase_client.has_method("get_guest_id"):
		var guest_id: String = str(supabase_client.call("get_guest_id"))
		if not guest_id.is_empty():
			return guest_id

	return "ugc_guest"


func _resolve_puzzle_title() -> String:
	var trimmed: String = puzzle_title_edit.text.strip_edges()
	if not trimmed.is_empty():
		return trimmed
	return "UGC Puzzle %d" % _next_puff_id


func _extract_inserted_puzzle_id(data_variant: Variant) -> String:
	if data_variant is Array:
		var rows: Array = data_variant
		if not rows.is_empty() and rows[0] is Dictionary:
			var first_row: Dictionary = rows[0]
			if first_row.has("id"):
				return str(first_row.get("id", ""))
			if first_row.has("uuid"):
				return str(first_row.get("uuid", ""))
	if data_variant is Dictionary:
		var row: Dictionary = data_variant
		if row.has("id"):
			return str(row.get("id", ""))
	return ""


func _on_puff_option_changed(_item_index: int) -> void:
	if _selected_puff_id.is_empty():
		return
	_apply_selected_options_to_puff(_selected_puff_id)


func _apply_selected_options_to_puff(puff_id: String) -> void:
	if puff_id.is_empty() or not _puff_state_by_id.has(puff_id):
		return

	var puff_state: Dictionary = _puff_state_by_id[puff_id]
	var puff_class: int = _selected_puff_class()

	puff_state["team"] = _selected_team()
	puff_state["element"] = _selected_element()
	puff_state["puff_class"] = puff_class
	puff_state["data_path"] = _data_path_for_class(puff_class)

	_puff_state_by_id[puff_id] = puff_state
	_ensure_puff_node(puff_id)
	_update_selection_label()
	_invalidate_test_play_state()


func _on_editor_content_changed(_value: Variant) -> void:
	_invalidate_test_play_state()


func _update_selection_label() -> void:
	if selection_label == null:
		return

	if _selected_puff_id.is_empty() or not _puff_state_by_id.has(_selected_puff_id):
		selection_label.text = "Selected puff: none. Puff Drag mode places new puffs on empty tiles."
		return

	var puff_state: Dictionary = _puff_state_by_id[_selected_puff_id]
	var cell: Vector2i = _to_cell(puff_state.get("cell", Vector2i.ZERO))
	var team: StringName = _normalize_team(puff_state.get("team", TEAM_ENEMY))
	var element_id: int = int(puff_state.get("element", Constants.Element.STAR))
	var class_id: int = int(puff_state.get("puff_class", Constants.PuffClass.STAR))

	selection_label.text = "Selected %s at (%d, %d) | Team %s | Element %s | Class %s" % [
		_selected_puff_id,
		cell.x,
		cell.y,
		str(TEAM_LABELS.get(team, String(team))),
		str(ELEMENT_LABELS_BY_ID.get(element_id, str(element_id))),
		str(CLASS_LABELS_BY_ID.get(class_id, str(class_id)))
	]


func _default_map_config() -> Dictionary:
	var rows: Array = []
	for _y in Constants.GRID_HEIGHT:
		var row: Array = []
		for _x in Constants.GRID_WIDTH:
			row.append("cloud")
		rows.append(row)

	return {
		"width": Constants.GRID_WIDTH,
		"height": Constants.GRID_HEIGHT,
		"rows": rows
	}


func _resolve_tile_map_layer() -> TileMapLayer:
	if _battle_map == null:
		return null
	return _battle_map.get_node_or_null("TileMapLayer")


func _board_position_to_cell(board_position: Vector2) -> Vector2i:
	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return Vector2i(-1, -1)

	var tile_local_position: Vector2 = board_position - board_root.position - tile_map_layer.position
	return tile_map_layer.local_to_map(tile_local_position)


func _is_valid_cell(cell: Vector2i) -> bool:
	if _battle_map == null:
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < _battle_map.map_size.x and cell.y < _battle_map.map_size.y


func _find_puff_id_at_cell(cell: Vector2i) -> String:
	for puff_id_variant in _puff_state_by_id.keys():
		var puff_id: String = str(puff_id_variant)
		var puff_state: Dictionary = _puff_state_by_id[puff_id]
		var puff_cell: Vector2i = _to_cell(puff_state.get("cell", Vector2i.ZERO))
		if puff_cell == cell:
			return puff_id
	return ""


func _build_puff_display_name(puff_state: Dictionary) -> String:
	var class_id: int = int(puff_state.get("puff_class", Constants.PuffClass.STAR))
	var class_label: String = str(CLASS_LABELS_BY_ID.get(class_id, "Puff"))
	return "%s_%s" % [class_label.replace(" ", "_"), puff_state.get("id", "ugc")]


func _selected_tool() -> int:
	if tool_option_button == null or tool_option_button.item_count == 0:
		return TOOL_TERRAIN
	return tool_option_button.get_selected_id()


func _selected_terrain_type() -> String:
	var selected_id: int = terrain_option_button.get_selected_id()
	if selected_id < 0 or selected_id >= TERRAIN_TYPES.size():
		return TERRAIN_TYPES[0]
	return TERRAIN_TYPES[selected_id]


func _selected_team() -> StringName:
	var selected_id: int = team_option_button.get_selected_id()
	if selected_id < 0 or selected_id >= TEAM_OPTIONS.size():
		return TEAM_OPTIONS[0]
	return TEAM_OPTIONS[selected_id]


func _selected_element() -> int:
	var selected_id: int = element_option_button.get_selected_id()
	if ELEMENT_OPTIONS.has(selected_id):
		return selected_id
	return Constants.Element.STAR


func _selected_puff_class() -> int:
	var selected_id: int = class_option_button.get_selected_id()
	if CLASS_OPTIONS.has(selected_id):
		return selected_id
	return Constants.PuffClass.STAR


func _selected_win_template() -> StringName:
	if win_template_option_button == null or win_template_option_button.item_count == 0:
		return TEMPLATE_BUMP_TO_CLIFF_KILL

	var selected_index: int = win_template_option_button.get_selected()
	if selected_index < 0:
		selected_index = 0

	var metadata_variant: Variant = win_template_option_button.get_item_metadata(selected_index)
	var metadata_text: String = str(metadata_variant).strip_edges()

	for template_id in SUPPORTED_WIN_TEMPLATES:
		if metadata_text == String(template_id):
			return template_id

	return TEMPLATE_BUMP_TO_CLIFF_KILL


func _data_path_for_class(puff_class: int) -> String:
	if CLASS_TO_DATA_PATH.has(puff_class):
		return str(CLASS_TO_DATA_PATH[puff_class])
	return str(CLASS_TO_DATA_PATH[Constants.PuffClass.STAR])


func _normalize_team(team_variant: Variant) -> StringName:
	if team_variant is StringName:
		var team_name: StringName = team_variant
		if team_name == TEAM_PLAYER or team_name == TEAM_ENEMY:
			return team_name

	var team_text: String = str(team_variant).strip_edges().to_lower()
	if team_text == String(TEAM_PLAYER):
		return TEAM_PLAYER
	return TEAM_ENEMY


func _team_color(team: StringName) -> Color:
	if team == TEAM_PLAYER:
		return Color(0.88, 1.0, 0.9, 1.0)
	return Color(1.0, 0.88, 0.88, 1.0)


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


func _resolve_test_play_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.34)


func _is_test_play_open() -> bool:
	return test_play_layer != null and test_play_layer.visible


func _invalidate_test_play_state() -> void:
	_current_test_snapshot_json = ""
	_last_tested_snapshot_json = ""
	_set_publish_status("Test-play required before publishing.")


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	emit_signal("status_changed", text)


func _set_publish_status(text: String) -> void:
	if publish_status_label != null:
		publish_status_label.text = text


func _to_json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var safe_dict: Dictionary = {}
		var dictionary_value: Dictionary = value
		for key_variant in dictionary_value.keys():
			safe_dict[str(key_variant)] = _to_json_safe(dictionary_value[key_variant])
		return safe_dict

	if value is Array:
		var safe_array: Array = []
		var source_array: Array = value
		for item_variant in source_array:
			safe_array.append(_to_json_safe(item_variant))
		return safe_array

	if value is Vector2i:
		var cell: Vector2i = value
		return {"x": cell.x, "y": cell.y}

	if value is Vector2:
		var point: Vector2 = value
		return {"x": point.x, "y": point.y}

	if value is StringName:
		return String(value)

	return value


func _select_option_by_id(option_button: OptionButton, target_id: int) -> void:
	if option_button == null:
		return
	for item_index in option_button.item_count:
		if option_button.get_item_id(item_index) == target_id:
			option_button.select(item_index)
			return


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
