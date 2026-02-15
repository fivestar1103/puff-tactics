extends Control
class_name FeedMain

const FEED_ITEM_SCRIPT: GDScript = preload("res://src/scripts/feed/feed_item.gd")
const FEED_SYNC_SCRIPT: GDScript = preload("res://src/scripts/network/feed_sync.gd")
const COLLECTION_SCREEN_SCENE: PackedScene = preload("res://src/scenes/ui/CollectionScreen.tscn")
const PUZZLE_EDITOR_SCENE: PackedScene = preload("res://src/scenes/ui/PuzzleEditor.tscn")
const STORY_CHAPTER_1_SCENE_PATH: String = "res://src/scenes/story/StoryChapter1.tscn"

const SNAP_DURATION: float = 0.28
const SWIPE_THRESHOLD_PX: float = 120.0
const SNAPSHOT_Y_RATIO: float = 0.16
const FAB_ROW_HALF_WIDTH: float = 364.0
const FAB_ROW_HEIGHT: float = 128.0
const FAB_ROW_BOTTOM_MARGIN_RATIO: float = 0.03
const FAB_ROW_BOTTOM_MARGIN_MIN: float = 42.0
const FAB_ROW_VIEWPORT_PADDING: float = 24.0
const SWIPE_HINT_WIDTH: float = 520.0
const SWIPE_HINT_HEIGHT: float = 42.0
const SWIPE_HINT_GAP_RATIO: float = 0.05
const SWIPE_HINT_GAP_MIN: float = 56.0
const SWIPE_HINT_GAP_MAX: float = 84.0
const SCORE_TO_SWIPE_HINT_GAP: float = 46.0
const SWIPE_HINT_TO_FAB_GAP: float = 64.0
const FEED_BATCH_SIZE: int = 50
const MIN_PLAYER_PUFFS_PER_SNAPSHOT: int = 2
const MIN_ENEMY_PUFFS_PER_SNAPSHOT: int = 2
const FALLBACK_PLAYER_DATA_PATH: String = "res://src/resources/puffs/base/flame_melee.tres"
const FALLBACK_ENEMY_DATA_PATH: String = "res://src/resources/puffs/base/cloud_tank.tres"

const SUPPLEMENTAL_PLAYER_PUFFS: Array[Dictionary] = [
	{
		"name": "Leaf_Support",
		"team": "player",
		"data_path": "res://src/resources/puffs/base/leaf_healer.tres",
		"preferred_cells": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 4)]
	},
	{
		"name": "Whirl_Support",
		"team": "player",
		"data_path": "res://src/resources/puffs/base/whirl_mobility.tres",
		"preferred_cells": [Vector2i(1, 4), Vector2i(0, 4), Vector2i(2, 3), Vector2i(1, 1)]
	}
]

const SUPPLEMENTAL_ENEMY_PUFFS: Array[Dictionary] = [
	{
		"name": "Flame_Raider",
		"team": "enemy",
		"data_path": "res://src/resources/puffs/base/flame_melee.tres",
		"preferred_cells": [Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 1), Vector2i(3, 2)]
	},
	{
		"name": "Droplet_Sniper",
		"team": "enemy",
		"data_path": "res://src/resources/puffs/base/droplet_ranged.tres",
		"preferred_cells": [Vector2i(4, 0), Vector2i(3, 0), Vector2i(4, 3), Vector2i(3, 3)]
	}
]

const FALLBACK_FEED_PUZZLE_SNAPSHOTS: Array[Dictionary] = [
	{
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
					"team": "player",
					"data_path": "res://src/resources/puffs/base/flame_melee.tres",
					"cell": Vector2i(1, 3)
				},
				{
					"name": "Leaf_Ally",
					"team": "player",
					"data_path": "res://src/resources/puffs/base/leaf_healer.tres",
					"cell": Vector2i(0, 2)
				},
				{
					"name": "Cloud_Guard",
					"team": "enemy",
					"data_path": "res://src/resources/puffs/base/cloud_tank.tres",
					"cell": Vector2i(3, 2)
			},
			{
				"name": "Droplet_Backline",
				"team": "enemy",
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
		"target_score": 230
	},
	{
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["high_cloud", "cloud", "cloud", "cloud", "cliff"],
				["cloud", "cotton_candy", "puddle", "cloud", "cloud"],
				["cloud", "cloud", "mushroom", "high_cloud", "cloud"],
				["cloud", "puddle", "cloud", "cloud", "cloud"],
				["cliff", "cloud", "cloud", "cotton_candy", "high_cloud"]
			]
		},
			"puffs": [
				{
					"name": "Whirl_Scout",
					"team": "player",
					"data_path": "res://src/resources/puffs/base/whirl_mobility.tres",
					"cell": Vector2i(1, 2)
				},
				{
					"name": "Flame_Vanguard",
					"team": "player",
					"data_path": "res://src/resources/puffs/base/flame_melee.tres",
					"cell": Vector2i(0, 3)
				},
				{
					"name": "Cloud_Anchor",
					"team": "enemy",
					"data_path": "res://src/resources/puffs/base/cloud_tank.tres",
					"cell": Vector2i(2, 2)
			},
			{
				"name": "Leaf_Enemy",
				"team": "enemy",
				"data_path": "res://src/resources/puffs/base/leaf_healer.tres",
				"cell": Vector2i(3, 3)
			}
		],
		"enemy_intents": [
			{
				"action": &"attack",
				"actor_cell": Vector2i(2, 2),
				"move_cell": Vector2i(2, 2),
				"target_cell": Vector2i(1, 2),
				"skill_cells": [],
				"direction": Vector2i.ZERO
			},
			{
				"action": &"move",
				"actor_cell": Vector2i(3, 3),
				"move_cell": Vector2i(2, 3),
				"target_cell": Vector2i(2, 3),
				"skill_cells": [],
				"direction": Vector2i.ZERO
			}
		],
		"target_score": 255
	},
	{
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "mushroom", "cloud", "high_cloud", "cloud"],
				["cloud", "cloud", "puddle", "cloud", "cloud"],
				["high_cloud", "cliff", "cloud", "puddle", "cloud"],
				["cloud", "cloud", "cotton_candy", "cloud", "mushroom"],
				["cloud", "high_cloud", "cloud", "cloud", "cliff"]
			]
		},
			"puffs": [
				{
					"name": "Star_Closer",
					"team": "player",
					"data_path": "res://src/resources/puffs/base/star_wildcard.tres",
					"cell": Vector2i(1, 3)
				},
				{
					"name": "Leaf_Backup",
					"team": "player",
					"data_path": "res://src/resources/puffs/base/leaf_healer.tres",
					"cell": Vector2i(0, 4)
				},
				{
					"name": "Flame_Enemy",
					"team": "enemy",
					"data_path": "res://src/resources/puffs/base/flame_melee.tres",
					"cell": Vector2i(2, 3)
			},
			{
				"name": "Droplet_Enemy",
				"team": "enemy",
				"data_path": "res://src/resources/puffs/base/droplet_ranged.tres",
				"cell": Vector2i(4, 2)
			}
		],
		"enemy_intents": [
			{
				"action": &"skill",
				"actor_cell": Vector2i(2, 3),
				"move_cell": Vector2i(2, 3),
				"target_cell": Vector2i(1, 3),
				"skill_cells": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)],
				"direction": Vector2i(-1, 0)
			},
			{
				"action": &"attack",
				"actor_cell": Vector2i(4, 2),
				"move_cell": Vector2i(4, 2),
				"target_cell": Vector2i(1, 3),
				"skill_cells": [],
				"direction": Vector2i.ZERO
			}
		],
		"target_score": 280
	}
]

@onready var feed_track: Node2D = $FeedTrack
@onready var title_label: Label = $Hud/TopMargin/TopStack/TitleLabel
@onready var subtitle_label: Label = $Hud/TopMargin/TopStack/SubtitleLabel
@onready var swipe_hint_label: Label = $Hud/SwipeHintLabel
@onready var profile_button: Button = $Hud/FabRow/ProfileButton
@onready var create_button: Button = $Hud/FabRow/CreateButton
@onready var leaderboard_button: Button = $Hud/FabRow/LeaderboardButton

var _active_item_index: int = 0
var _is_dragging: bool = false
var _drag_start_position: Vector2 = Vector2.ZERO
var _drag_delta_y: float = 0.0
var _snap_tween: Tween
var _feed_items: Array[Node2D] = []
var _feed_snapshots: Array[Dictionary] = []
var _feed_sync: Node
var _collection_screen: Node
var _puzzle_editor: Node


func _ready() -> void:
	_setup_feed_sync()
	_setup_collection_screen()
	_setup_puzzle_editor()
	_load_initial_snapshots()
	_build_feed_items()
	_connect_fab_actions()
	_style_header_labels()
	_style_fab_buttons()
	_layout_feed_items()
	_layout_hud_overlays()
	_set_active_item(0, false)
	call_deferred("_fetch_next_batch_in_background")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_feed_items()
		_layout_hud_overlays()
		_snap_to_active_item(false)


func _unhandled_input(event: InputEvent) -> void:
	if _is_collection_visible() or _is_puzzle_editor_visible():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
		return

	if event is InputEventScreenDrag:
		_update_drag(event.position)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
		return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag(event.position)


func _begin_drag(screen_position: Vector2) -> void:
	if _feed_items.is_empty():
		return
	_stop_snap_tween()
	_is_dragging = true
	_drag_start_position = screen_position
	_drag_delta_y = 0.0


func _update_drag(screen_position: Vector2) -> void:
	if not _is_dragging:
		return

	_drag_delta_y = screen_position.y - _drag_start_position.y
	feed_track.position.y = _active_track_position_y() + _drag_delta_y


func _end_drag(screen_position: Vector2) -> void:
	if not _is_dragging:
		return

	_is_dragging = false
	_drag_delta_y = screen_position.y - _drag_start_position.y

	var next_index: int = _active_item_index
	if _drag_delta_y <= -SWIPE_THRESHOLD_PX:
		if _active_item_can_advance():
			next_index = mini(_active_item_index + 1, _feed_items.size() - 1)
		else:
			_update_subtitle_for_locked_swipe()
	elif _drag_delta_y >= SWIPE_THRESHOLD_PX:
		if _active_item_can_advance():
			next_index = maxi(_active_item_index - 1, 0)
		else:
			_update_subtitle_for_locked_swipe()

	_set_active_item(next_index, true)


func _set_active_item(index: int, animate: bool) -> void:
	if _feed_items.is_empty():
		_active_item_index = 0
		return

	_active_item_index = clampi(index, 0, _feed_items.size() - 1)
	_sync_feed_item_activation()
	_snap_to_active_item(animate)
	_layout_hud_overlays()
	_update_header_text()


func _snap_to_active_item(animate: bool) -> void:
	var target_track_y: float = _active_track_position_y()
	if not animate:
		feed_track.position.y = target_track_y
		return

	_stop_snap_tween()
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC)
	_snap_tween.set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(feed_track, "position:y", target_track_y, SNAP_DURATION)


func _stop_snap_tween() -> void:
	if _snap_tween == null:
		return
	if _snap_tween.is_running():
		_snap_tween.kill()
	_snap_tween = null


func _setup_feed_sync() -> void:
	var feed_sync_variant: Variant = FEED_SYNC_SCRIPT.new()
	if not (feed_sync_variant is Node):
		return
	_feed_sync = feed_sync_variant
	_feed_sync.name = "FeedSync"
	add_child(_feed_sync)


func _setup_collection_screen() -> void:
	if COLLECTION_SCREEN_SCENE == null:
		return
	var collection_variant: Node = COLLECTION_SCREEN_SCENE.instantiate()
	if collection_variant == null:
		return
	_collection_screen = collection_variant
	_collection_screen.name = "CollectionScreen"
	add_child(_collection_screen)


func _setup_puzzle_editor() -> void:
	if PUZZLE_EDITOR_SCENE == null:
		return
	var puzzle_editor_variant: Node = PUZZLE_EDITOR_SCENE.instantiate()
	if puzzle_editor_variant == null:
		return
	_puzzle_editor = puzzle_editor_variant
	_puzzle_editor.name = "PuzzleEditor"
	add_child(_puzzle_editor)
	_connect_if_available(_puzzle_editor, &"status_changed", Callable(self, "_on_puzzle_editor_status_changed"))
	_connect_if_available(_puzzle_editor, &"published", Callable(self, "_on_puzzle_editor_published"))


func _load_initial_snapshots() -> void:
	_feed_snapshots.clear()

	var cached_snapshots: Array[Dictionary] = []
	if _feed_sync != null and _feed_sync.has_method("load_cached_feed_items"):
		var cached_variant: Variant = _feed_sync.call("load_cached_feed_items")
		if cached_variant is Array:
			cached_snapshots = _to_snapshot_array(cached_variant)

	if cached_snapshots.is_empty():
		_feed_snapshots = _to_snapshot_array(FALLBACK_FEED_PUZZLE_SNAPSHOTS)
		return

	_feed_snapshots = cached_snapshots
	subtitle_label.text = "Loaded %d cached puzzles. Syncing next batch..." % _feed_snapshots.size()


func _fetch_next_batch_in_background() -> void:
	if _feed_sync == null:
		return
	if not _feed_sync.has_method("fetch_feed_items_batch"):
		return

	var offset: int = _feed_snapshots.size()
	var fetch_result_variant: Variant = await _feed_sync.call("fetch_feed_items_batch", offset, FEED_BATCH_SIZE)
	if not (fetch_result_variant is Dictionary):
		return

	var fetch_result: Dictionary = fetch_result_variant
	if not bool(fetch_result.get("ok", false)):
		if offset > 0:
			subtitle_label.text = "Offline mode: playing cached feed items"
		return

	var batch_variant: Variant = fetch_result.get("items", [])
	if not (batch_variant is Array):
		return

	var fetched_snapshots: Array[Dictionary] = _to_snapshot_array(batch_variant)
	if fetched_snapshots.is_empty():
		return

	var start_index: int = _feed_snapshots.size()
	_feed_snapshots.append_array(fetched_snapshots)
	_build_feed_items_from_index(start_index)
	_layout_feed_items()
	_update_header_text()


func _build_feed_items() -> void:
	_feed_items.clear()
	for child in feed_track.get_children():
		child.queue_free()

	_build_feed_items_from_index(0)


func _build_feed_items_from_index(start_index: int) -> void:
	for item_index in range(start_index, _feed_snapshots.size()):
		var feed_item_variant: Variant = FEED_ITEM_SCRIPT.new()
		if not (feed_item_variant is Node2D):
			continue

		var feed_item: Node2D = feed_item_variant
		feed_item.name = "FeedItem_%d" % item_index
		if feed_item.has_method("configure_snapshot"):
			var snapshot: Dictionary = _feed_snapshots[item_index].duplicate(true)
			feed_item.call("configure_snapshot", snapshot)

		feed_track.add_child(feed_item)
		_feed_items.append(feed_item)

		_connect_if_available(feed_item, &"cycle_completed", Callable(self, "_on_feed_item_cycle_completed").bind(item_index))
		_connect_if_available(feed_item, &"status_changed", Callable(self, "_on_feed_item_status_changed").bind(item_index))


func _to_snapshot_array(raw_array: Array) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for snapshot_variant in raw_array:
		if not (snapshot_variant is Dictionary):
			continue
		var snapshot: Dictionary = _normalize_snapshot_for_feed(snapshot_variant)
		if snapshot.is_empty():
			continue
		snapshots.append(snapshot)
	return snapshots


func _normalize_snapshot_for_feed(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot: Dictionary = raw_snapshot.duplicate(true)

	var map_config_variant: Variant = snapshot.get("map_config", {})
	if not (map_config_variant is Dictionary):
		return {}
	var map_config: Dictionary = map_config_variant.duplicate(true)
	snapshot["map_config"] = map_config

	var map_size: Vector2i = _resolve_map_size(map_config)
	var puffs: Array[Dictionary] = _normalize_snapshot_puffs(snapshot.get("puffs", []), map_size)
	if puffs.is_empty():
		return {}

	var occupied_cells: Dictionary = {}
	var unique_puffs: Array[Dictionary] = []
	var player_count: int = 0
	var enemy_count: int = 0
	for puff in puffs:
		var team_text: String = _normalize_team_text(puff.get("team", "enemy"))
		var cell: Vector2i = _to_cell(puff.get("cell", Vector2i.ZERO))
		if not _is_cell_available(cell, occupied_cells, map_size):
			cell = _find_first_available_cell(occupied_cells, map_size, [])
		if not _is_cell_in_bounds(cell, map_size):
			continue
		puff["team"] = team_text
		puff["cell"] = cell
		unique_puffs.append(puff)
		occupied_cells[cell] = true
		if team_text == "player":
			player_count += 1
		else:
			enemy_count += 1

	_append_missing_team_puffs(
		unique_puffs,
		occupied_cells,
		map_size,
		"player",
		MIN_PLAYER_PUFFS_PER_SNAPSHOT - player_count,
		SUPPLEMENTAL_PLAYER_PUFFS
	)
	_append_missing_team_puffs(
		unique_puffs,
		occupied_cells,
		map_size,
		"enemy",
		MIN_ENEMY_PUFFS_PER_SNAPSHOT - enemy_count,
		SUPPLEMENTAL_ENEMY_PUFFS
	)

	snapshot["puffs"] = unique_puffs

	var enemy_intents: Array[Dictionary] = _normalize_enemy_intents(snapshot.get("enemy_intents", []))
	if enemy_intents.is_empty():
		enemy_intents = _build_fallback_enemy_intents(unique_puffs)
	snapshot["enemy_intents"] = enemy_intents
	return snapshot


func _normalize_snapshot_puffs(raw_puffs_variant: Variant, map_size: Vector2i) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (raw_puffs_variant is Array):
		return normalized

	var raw_puffs: Array = raw_puffs_variant
	for puff_variant in raw_puffs:
		if not (puff_variant is Dictionary):
			continue
		var raw_puff: Dictionary = puff_variant.duplicate(true)
		var team_text: String = _normalize_team_text(raw_puff.get("team", "enemy"))
		var cell: Vector2i = _to_cell(raw_puff.get("cell", Vector2i.ZERO))
		if not _is_cell_in_bounds(cell, map_size):
			continue
		normalized.append(
			{
				"name": str(raw_puff.get("name", "Puff")),
				"team": team_text,
				"data_path": str(raw_puff.get("data_path", _default_data_path_for_team(team_text))),
				"cell": cell,
				"hp": int(raw_puff.get("hp", 0)),
				"max_hp": int(raw_puff.get("max_hp", 0))
			}
		)

	return normalized


func _normalize_enemy_intents(raw_intents_variant: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (raw_intents_variant is Array):
		return normalized

	var raw_intents: Array = raw_intents_variant
	for intent_variant in raw_intents:
		if not (intent_variant is Dictionary):
			continue
		var raw_intent: Dictionary = intent_variant

		var skill_cells: Array[Vector2i] = []
		var raw_skill_cells_variant: Variant = raw_intent.get("skill_cells", [])
		if raw_skill_cells_variant is Array:
			var raw_skill_cells: Array = raw_skill_cells_variant
			for skill_cell_variant in raw_skill_cells:
				skill_cells.append(_to_cell(skill_cell_variant))

		normalized.append(
			{
				"action": StringName(str(raw_intent.get("action", "wait")).to_lower()),
				"actor_cell": _to_cell(raw_intent.get("actor_cell", Vector2i.ZERO)),
				"move_cell": _to_cell(raw_intent.get("move_cell", raw_intent.get("actor_cell", Vector2i.ZERO))),
				"target_cell": _to_cell(raw_intent.get("target_cell", raw_intent.get("actor_cell", Vector2i.ZERO))),
				"skill_cells": skill_cells,
				"direction": _to_cell(raw_intent.get("direction", Vector2i.ZERO))
			}
		)

	return normalized


func _build_fallback_enemy_intents(puffs: Array[Dictionary]) -> Array[Dictionary]:
	var first_enemy_cell: Vector2i = Vector2i(-1, -1)
	var first_player_cell: Vector2i = Vector2i(-1, -1)

	for puff in puffs:
		var team_text: String = _normalize_team_text(puff.get("team", "enemy"))
		var cell: Vector2i = _to_cell(puff.get("cell", Vector2i.ZERO))
		if team_text == "enemy" and first_enemy_cell.x < 0:
			first_enemy_cell = cell
		elif team_text == "player" and first_player_cell.x < 0:
			first_player_cell = cell
		if first_enemy_cell.x >= 0 and first_player_cell.x >= 0:
			break

	if first_enemy_cell.x < 0 or first_player_cell.x < 0:
		return []

	return [
		{
			"action": &"attack",
			"actor_cell": first_enemy_cell,
			"move_cell": first_enemy_cell,
			"target_cell": first_player_cell,
			"skill_cells": [],
			"direction": _direction_from_to(first_enemy_cell, first_player_cell)
		}
	]


func _append_missing_team_puffs(
	puffs: Array[Dictionary],
	occupied_cells: Dictionary,
	map_size: Vector2i,
	team_text: String,
	missing_count: int,
	templates: Array[Dictionary]
) -> void:
	var to_add: int = maxi(0, missing_count)
	if to_add <= 0:
		return
	if templates.is_empty():
		return

	for index in range(to_add):
		var template: Dictionary = templates[index % templates.size()]
		var preferred_cells_variant: Variant = template.get("preferred_cells", [])
		var spawn_cell: Vector2i = _find_first_available_cell(occupied_cells, map_size, preferred_cells_variant)
		if not _is_cell_in_bounds(spawn_cell, map_size):
			break

		var puff_name: String = str(template.get("name", "Puff"))
		puffs.append(
			{
				"name": "%s_%d" % [puff_name, index + 1],
				"team": team_text,
				"data_path": str(template.get("data_path", _default_data_path_for_team(team_text))),
				"cell": spawn_cell
			}
		)
		occupied_cells[spawn_cell] = true


func _find_first_available_cell(occupied_cells: Dictionary, map_size: Vector2i, preferred_cells_variant: Variant) -> Vector2i:
	if preferred_cells_variant is Array:
		var preferred_cells: Array = preferred_cells_variant
		for preferred_cell_variant in preferred_cells:
			var preferred_cell: Vector2i = _to_cell(preferred_cell_variant)
			if _is_cell_available(preferred_cell, occupied_cells, map_size):
				return preferred_cell

	for y in range(map_size.y):
		for x in range(map_size.x):
			var candidate: Vector2i = Vector2i(x, y)
			if _is_cell_available(candidate, occupied_cells, map_size):
				return candidate

	return Vector2i(-1, -1)


func _resolve_map_size(map_config: Dictionary) -> Vector2i:
	var width: int = int(map_config.get("width", Constants.GRID_SIZE.x))
	var height: int = int(map_config.get("height", Constants.GRID_SIZE.y))

	var rows_variant: Variant = map_config.get("rows", [])
	if rows_variant is Array:
		var rows: Array = rows_variant
		if height <= 0:
			height = rows.size()
		if width <= 0 and not rows.is_empty() and rows[0] is Array:
			width = (rows[0] as Array).size()

	if width <= 0:
		width = Constants.GRID_SIZE.x
	if height <= 0:
		height = Constants.GRID_SIZE.y
	return Vector2i(width, height)


func _is_cell_available(cell: Vector2i, occupied_cells: Dictionary, map_size: Vector2i) -> bool:
	if not _is_cell_in_bounds(cell, map_size):
		return false
	return not occupied_cells.has(cell)


func _is_cell_in_bounds(cell: Vector2i, map_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y


func _default_data_path_for_team(team_text: String) -> String:
	if team_text == "player":
		return FALLBACK_PLAYER_DATA_PATH
	return FALLBACK_ENEMY_DATA_PATH


func _normalize_team_text(team_variant: Variant) -> String:
	var team_text: String = str(team_variant).strip_edges().to_lower()
	if team_text == "player":
		return "player"
	return "enemy"


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


func _direction_from_to(origin: Vector2i, target: Vector2i) -> Vector2i:
	return Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))


func _layout_feed_items() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for item_index in _feed_items.size():
		var feed_item: Node2D = _feed_items[item_index]
		feed_item.position = Vector2(
			viewport_size.x * 0.5,
			float(item_index) * _page_height() + viewport_size.y * SNAPSHOT_Y_RATIO
		)


func _layout_hud_overlays() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	profile_button.custom_minimum_size = Vector2(180.0, 76.0)
	create_button.custom_minimum_size = Vector2(180.0, 76.0)
	leaderboard_button.custom_minimum_size = Vector2(180.0, 76.0)

	profile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fab_row: HBoxContainer = profile_button.get_parent() as HBoxContainer
	if fab_row == null:
		return

	var bottom_margin: float = maxf(FAB_ROW_BOTTOM_MARGIN_MIN, viewport_size.y * FAB_ROW_BOTTOM_MARGIN_RATIO)
	var fallback_fab_top_y: float = viewport_size.y - bottom_margin - FAB_ROW_HEIGHT
	var fallback_swipe_gap: float = clampf(
		viewport_size.y * SWIPE_HINT_GAP_RATIO,
		SWIPE_HINT_GAP_MIN,
		SWIPE_HINT_GAP_MAX
	)
	var fallback_swipe_hint_top_y: float = fallback_fab_top_y - SWIPE_HINT_HEIGHT - fallback_swipe_gap
	var swipe_hint_top_y: float = fallback_swipe_hint_top_y
	var score_panel_bottom_y: float = _resolve_active_score_panel_bottom_y()
	if not is_nan(score_panel_bottom_y):
		swipe_hint_top_y = score_panel_bottom_y + SCORE_TO_SWIPE_HINT_GAP

	var fab_top_y: float = swipe_hint_top_y + SWIPE_HINT_HEIGHT + SWIPE_HINT_TO_FAB_GAP
	fab_top_y = maxf(fab_top_y, fallback_fab_top_y)
	var max_fab_top_y: float = viewport_size.y - FAB_ROW_HEIGHT - FAB_ROW_VIEWPORT_PADDING
	if fab_top_y > max_fab_top_y:
		fab_top_y = max_fab_top_y

	swipe_hint_top_y = fab_top_y - SWIPE_HINT_HEIGHT - SWIPE_HINT_TO_FAB_GAP

	var fab_top: float = fab_top_y - viewport_size.y
	var fab_bottom: float = fab_top + FAB_ROW_HEIGHT
	fab_row.offset_left = -FAB_ROW_HALF_WIDTH
	fab_row.offset_right = FAB_ROW_HALF_WIDTH
	fab_row.offset_top = fab_top
	fab_row.offset_bottom = fab_bottom

	var swipe_top: float = swipe_hint_top_y - viewport_size.y
	var swipe_bottom: float = swipe_top + SWIPE_HINT_HEIGHT
	swipe_hint_label.offset_left = -SWIPE_HINT_WIDTH * 0.5
	swipe_hint_label.offset_right = SWIPE_HINT_WIDTH * 0.5
	swipe_hint_label.offset_top = swipe_top
	swipe_hint_label.offset_bottom = swipe_bottom


func _resolve_active_score_panel_bottom_y() -> float:
	var active_feed_item: Node2D = _get_active_feed_item()
	if active_feed_item == null:
		return NAN
	if not active_feed_item.has_method("get_score_panel_bottom_global_y"):
		return NAN

	var bottom_variant: Variant = active_feed_item.call("get_score_panel_bottom_global_y")
	if bottom_variant is float or bottom_variant is int:
		return float(bottom_variant)
	return NAN


func _sync_feed_item_activation() -> void:
	for item_index in _feed_items.size():
		var feed_item: Node2D = _feed_items[item_index]
		if not feed_item.has_method("set_interaction_enabled"):
			continue
		feed_item.call("set_interaction_enabled", item_index == _active_item_index)


func _update_header_text() -> void:
	var total_items: int = _feed_items.size()
	title_label.text = "Puff Tactics Feed (%d/%d)" % [_active_item_index + 1, total_items]

	var active_feed_item: Node2D = _get_active_feed_item()
	if active_feed_item == null:
		subtitle_label.text = "Swipe up for the next tactical snapshot"
		return

	if active_feed_item.has_method("get_status_text"):
		var status_text: String = str(active_feed_item.call("get_status_text"))
		if not status_text.is_empty():
			subtitle_label.text = status_text
			return

	subtitle_label.text = "Solve the turn, then swipe to the next puzzle"


func _active_track_position_y() -> float:
	return -float(_active_item_index) * _page_height()


func _page_height() -> float:
	return get_viewport_rect().size.y


func _active_item_can_advance() -> bool:
	var active_feed_item: Node2D = _get_active_feed_item()
	if active_feed_item == null:
		return true
	if not active_feed_item.has_method("can_advance_to_next_item"):
		return true
	return bool(active_feed_item.call("can_advance_to_next_item"))


func _get_active_feed_item() -> Node2D:
	if _feed_items.is_empty():
		return null
	if _active_item_index < 0 or _active_item_index >= _feed_items.size():
		return null
	return _feed_items[_active_item_index]


func _update_subtitle_for_locked_swipe() -> void:
	subtitle_label.text = "Finish this 1-turn puzzle before swiping"


func _on_feed_item_cycle_completed(score: int, cycle_duration_seconds: float, item_index: int) -> void:
	_submit_feed_result(item_index, score, cycle_duration_seconds)

	if item_index != _active_item_index:
		return
	subtitle_label.text = "Score %d in %.1fs. Swipe up for next." % [score, cycle_duration_seconds]


func _on_feed_item_status_changed(status_text: String, swipe_unlocked: bool, item_index: int) -> void:
	if item_index != _active_item_index:
		return
	if swipe_unlocked:
		subtitle_label.text = "%s" % status_text
		return
	subtitle_label.text = status_text


func _submit_feed_result(item_index: int, score: int, cycle_duration_seconds: float) -> void:
	if _feed_sync == null:
		return
	if not _feed_sync.has_method("submit_feed_result"):
		return
	if item_index < 0 or item_index >= _feed_snapshots.size():
		return

	var snapshot: Dictionary = _feed_snapshots[item_index]
	_feed_sync.call("submit_feed_result", snapshot, score, cycle_duration_seconds)


func _connect_if_available(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)


func _connect_fab_actions() -> void:
	_connect_if_available(profile_button, &"pressed", Callable(self, "_on_profile_button_pressed"))
	_connect_if_available(create_button, &"pressed", Callable(self, "_on_create_button_pressed"))
	_connect_if_available(leaderboard_button, &"pressed", Callable(self, "_on_leaderboard_button_pressed"))


func _on_profile_button_pressed() -> void:
	if _is_puzzle_editor_visible():
		subtitle_label.text = "Close the UGC editor before opening collection."
		return

	if _collection_screen == null:
		return
	if not (_collection_screen is CanvasItem):
		return
	var collection_canvas: CanvasItem = _collection_screen
	if collection_canvas.visible:
		if _collection_screen.has_method("hide_collection"):
			_collection_screen.call("hide_collection")
		else:
			collection_canvas.visible = false
		_update_header_text()
		return

	if _collection_screen.has_method("show_collection"):
		_collection_screen.call("show_collection")
	else:
		collection_canvas.visible = true
	subtitle_label.text = "Collection open: view puff levels and owned accessories"


func _on_create_button_pressed() -> void:
	if _puzzle_editor == null:
		subtitle_label.text = "UGC puzzle editor scene is unavailable."
		return
	if not (_puzzle_editor is CanvasItem):
		subtitle_label.text = "UGC puzzle editor failed to initialize."
		return

	if _is_collection_visible():
		if _collection_screen.has_method("hide_collection"):
			_collection_screen.call("hide_collection")
		else:
			(_collection_screen as CanvasItem).visible = false

	var puzzle_editor_canvas: CanvasItem = _puzzle_editor
	if puzzle_editor_canvas.visible:
		if _puzzle_editor.has_method("hide_editor"):
			_puzzle_editor.call("hide_editor")
		else:
			puzzle_editor_canvas.visible = false
		_update_header_text()
		return

	if _puzzle_editor.has_method("show_editor"):
		_puzzle_editor.call("show_editor")
	else:
		puzzle_editor_canvas.visible = true
	subtitle_label.text = "UGC editor open: drag terrain/puffs, test-play, then publish."


func _on_leaderboard_button_pressed() -> void:
	var scene_change_error: Error = get_tree().change_scene_to_file(STORY_CHAPTER_1_SCENE_PATH)
	if scene_change_error != OK:
		subtitle_label.text = "Story mode is unavailable in this build."


func _is_collection_visible() -> bool:
	if not (_collection_screen is CanvasItem):
		return false
	return (_collection_screen as CanvasItem).visible


func _is_puzzle_editor_visible() -> bool:
	if not (_puzzle_editor is CanvasItem):
		return false
	return (_puzzle_editor as CanvasItem).visible


func _on_puzzle_editor_status_changed(status_text: String) -> void:
	if not _is_puzzle_editor_visible():
		return
	subtitle_label.text = status_text


func _on_puzzle_editor_published(_snapshot_id: String, status_text: String) -> void:
	subtitle_label.text = status_text


func _style_fab_buttons() -> void:
	VisualTheme.apply_button_theme(profile_button, Constants.PALETTE_SKY, Color.WHITE, Vector2(180.0, 76.0), Constants.FONT_SIZE_BUTTON)
	VisualTheme.apply_button_theme(create_button, Constants.PALETTE_PEACH, Color.WHITE, Vector2(180.0, 76.0), Constants.FONT_SIZE_BUTTON)
	VisualTheme.apply_button_theme(leaderboard_button, Constants.PALETTE_MINT, Color.WHITE, Vector2(180.0, 76.0), Constants.FONT_SIZE_BUTTON)


func _style_header_labels() -> void:
	VisualTheme.apply_label_theme(title_label, Constants.FONT_SIZE_TITLE, Constants.COLOR_TEXT_DARK)
	VisualTheme.apply_label_theme(subtitle_label, Constants.FONT_SIZE_SUBTITLE, Constants.COLOR_TEXT_DARK.lightened(0.24))
	VisualTheme.apply_label_theme(swipe_hint_label, Constants.FONT_SIZE_BODY, Constants.COLOR_TEXT_DARK.lightened(0.28))
