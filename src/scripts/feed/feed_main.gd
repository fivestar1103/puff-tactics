extends Control
class_name FeedMain

const FEED_ITEM_SCRIPT: GDScript = preload("res://src/scripts/feed/feed_item.gd")
const FEED_SYNC_SCRIPT: GDScript = preload("res://src/scripts/network/feed_sync.gd")
const COLLECTION_SCREEN_SCENE: PackedScene = preload("res://src/scenes/ui/CollectionScreen.tscn")
const PUZZLE_EDITOR_SCENE: PackedScene = preload("res://src/scenes/ui/PuzzleEditor.tscn")
const STORY_CHAPTER_1_SCENE_PATH: String = "res://src/scenes/story/StoryChapter1.tscn"

const SNAP_DURATION: float = 0.28
const SWIPE_THRESHOLD_PX: float = 120.0
const SNAPSHOT_Y_RATIO: float = 0.34
const FEED_BATCH_SIZE: int = 50

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
				"name": "Cloud_Guard",
				"team": "enemy",
				"data_path": "res://src/resources/puffs/base/cloud_tank.tres",
				"cell": Vector2i(2, 2)
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
				"actor_cell": Vector2i(2, 2),
				"move_cell": Vector2i(2, 2),
				"target_cell": Vector2i(1, 3),
				"skill_cells": [Vector2i(1, 3), Vector2i(2, 3)],
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
	_set_active_item(0, false)
	call_deferred("_fetch_next_batch_in_background")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_feed_items()
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
		var snapshot: Dictionary = snapshot_variant.duplicate(true)
		snapshots.append(snapshot)
	return snapshots


func _layout_feed_items() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for item_index in _feed_items.size():
		var feed_item: Node2D = _feed_items[item_index]
		feed_item.position = Vector2(
			viewport_size.x * 0.5,
			float(item_index) * _page_height() + viewport_size.y * SNAPSHOT_Y_RATIO
		)


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
