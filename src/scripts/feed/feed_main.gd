extends Control
class_name FeedMain

const TURN_BATTLE_SCENE: PackedScene = preload("res://src/scenes/battle/TurnBattle.tscn")

const ITEM_COUNT: int = 3
const SNAP_DURATION: float = 0.28
const SWIPE_THRESHOLD_PX: float = 120.0
const SNAPSHOT_SCALE: Vector2 = Vector2(0.68, 0.68)
const SNAPSHOT_Y_RATIO: float = 0.34

const FEED_MAP_CONFIGS: Array[Dictionary] = [
	{
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
	{
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
	{
		"width": 5,
		"height": 5,
		"rows": [
			["cloud", "mushroom", "cloud", "high_cloud", "cloud"],
			["cloud", "cloud", "puddle", "cloud", "cloud"],
			["high_cloud", "cliff", "cloud", "puddle", "cloud"],
			["cloud", "cloud", "cotton_candy", "cloud", "mushroom"],
			["cloud", "high_cloud", "cloud", "cloud", "cliff"]
		]
	}
]

@onready var feed_track: Node2D = $FeedTrack
@onready var profile_button: Button = $Hud/FabRow/ProfileButton
@onready var create_button: Button = $Hud/FabRow/CreateButton
@onready var leaderboard_button: Button = $Hud/FabRow/LeaderboardButton

var _active_item_index: int = 0
var _is_dragging: bool = false
var _drag_start_position: Vector2 = Vector2.ZERO
var _drag_delta_y: float = 0.0
var _snap_tween: Tween
var _feed_items: Array[Node2D] = []


func _ready() -> void:
	_build_feed_items()
	_style_fab_buttons()
	_layout_feed_items()
	_snap_to_active_item(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_feed_items()
		_snap_to_active_item(false)


func _unhandled_input(event: InputEvent) -> void:
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
		next_index = mini(_active_item_index + 1, _feed_items.size() - 1)
	elif _drag_delta_y >= SWIPE_THRESHOLD_PX:
		next_index = maxi(_active_item_index - 1, 0)

	_set_active_item(next_index, true)


func _set_active_item(index: int, animate: bool) -> void:
	if _feed_items.is_empty():
		_active_item_index = 0
		return

	_active_item_index = clampi(index, 0, _feed_items.size() - 1)
	_snap_to_active_item(animate)


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


func _build_feed_items() -> void:
	for item_index in ITEM_COUNT:
		var feed_item: Node2D = Node2D.new()
		feed_item.name = "FeedItem_%d" % item_index
		feed_track.add_child(feed_item)
		_feed_items.append(feed_item)

		var snapshot_variant: Node = TURN_BATTLE_SCENE.instantiate()
		if not (snapshot_variant is Node2D):
			snapshot_variant.queue_free()
			continue

		var snapshot: Node2D = snapshot_variant
		feed_item.add_child(snapshot)
		snapshot.scale = SNAPSHOT_SCALE
		_configure_snapshot(snapshot, item_index)


func _configure_snapshot(snapshot: Node2D, item_index: int) -> void:
	var battle_map: Node = snapshot.get_node_or_null("BattleMap")
	if battle_map != null and battle_map.has_method("load_map_from_config"):
		var map_config: Dictionary = FEED_MAP_CONFIGS[item_index % FEED_MAP_CONFIGS.size()].duplicate(true)
		battle_map.call("load_map_from_config", map_config)

	var turn_manager: Node = snapshot.get_node_or_null("TurnManager")
	if turn_manager != null:
		# Feed cards are snapshots; disable direct battle tap input inside the feed.
		turn_manager.set_process_unhandled_input(false)


func _layout_feed_items() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for item_index in _feed_items.size():
		var feed_item: Node2D = _feed_items[item_index]
		feed_item.position = Vector2(
			viewport_size.x * 0.5,
			float(item_index) * _page_height() + viewport_size.y * SNAPSHOT_Y_RATIO
		)


func _active_track_position_y() -> float:
	return -float(_active_item_index) * _page_height()


func _page_height() -> float:
	return get_viewport_rect().size.y


func _style_fab_buttons() -> void:
	var button_specs: Array[Dictionary] = [
		{
			"button": profile_button,
			"base_color": Color(0.43, 0.64, 0.91, 1.0),
			"font_color": Color(0.95, 0.98, 1.0, 1.0)
		},
		{
			"button": create_button,
			"base_color": Color(0.99, 0.62, 0.46, 1.0),
			"font_color": Color(1.0, 0.98, 0.95, 1.0)
		},
		{
			"button": leaderboard_button,
			"base_color": Color(0.47, 0.75, 0.56, 1.0),
			"font_color": Color(0.95, 1.0, 0.96, 1.0)
		}
	]

	for spec_variant in button_specs:
		if not (spec_variant is Dictionary):
			continue
		var spec: Dictionary = spec_variant
		var button_variant: Variant = spec.get("button")
		if not (button_variant is Button):
			continue

		var button: Button = button_variant
		var base_color: Color = spec.get("base_color", Color(0.4, 0.4, 0.4, 1.0))
		var font_color: Color = spec.get("font_color", Color.WHITE)

		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(220.0, 88.0)
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_color_override("font_color", font_color)

		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = base_color
		normal_style.corner_radius_top_left = 44
		normal_style.corner_radius_top_right = 44
		normal_style.corner_radius_bottom_right = 44
		normal_style.corner_radius_bottom_left = 44
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = base_color.darkened(0.24)

		var hover_style: StyleBoxFlat = normal_style.duplicate()
		hover_style.bg_color = base_color.lightened(0.08)

		var pressed_style: StyleBoxFlat = normal_style.duplicate()
		pressed_style.bg_color = base_color.darkened(0.12)

		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
