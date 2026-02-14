extends Control
class_name CollectionScreen

@export var progression_path: NodePath = NodePath("/root/PuffProgression")

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/RootLayout/Header/CloseButton
@onready var subtitle_label: Label = $Panel/RootLayout/Subtitle
@onready var title_label: Label = $Panel/RootLayout/Header/Title
@onready var puff_list: VBoxContainer = $Panel/RootLayout/Body/PuffColumn/PuffScroll/PuffList
@onready var accessory_list: VBoxContainer = $Panel/RootLayout/Body/AccessoryColumn/AccessoryScroll/AccessoryList

var _progression: Node


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_themed_styles()
	_resolve_progression()
	if close_button != null:
		_connect_if_needed(close_button, &"pressed", Callable(self, "hide_collection"))
	if _progression != null:
		_connect_if_needed(_progression, &"progression_updated", Callable(self, "_on_progression_updated"))


func _apply_themed_styles() -> void:
	if panel != null:
		panel.add_theme_stylebox_override("panel", VisualTheme.create_panel_stylebox(Constants.COLOR_BG_CREAM, 22, Constants.COLOR_TEXT_DARK))
	if title_label != null:
		VisualTheme.apply_label_theme(title_label, Constants.FONT_SIZE_TITLE, Constants.PALETTE_LAVENDER)
	if close_button != null:
		VisualTheme.apply_button_theme(close_button, Constants.PALETTE_PINK, Color.WHITE, Vector2(150.0, 56.0), Constants.FONT_SIZE_BUTTON)


func show_collection() -> void:
	_resolve_progression()
	_refresh_contents()
	visible = true
	move_to_front()


func hide_collection() -> void:
	visible = false


func _refresh_contents() -> void:
	if puff_list == null or accessory_list == null:
		return

	_clear_list(puff_list)
	_clear_list(accessory_list)

	if _progression == null or not _progression.has_method("get_collection_snapshot"):
		subtitle_label.text = "Progression unavailable in this build."
		return

	var snapshot_variant: Variant = _progression.call("get_collection_snapshot")
	if not (snapshot_variant is Dictionary):
		subtitle_label.text = "No progression data available."
		return

	var snapshot: Dictionary = snapshot_variant
	var puffs_variant: Variant = snapshot.get("puffs", [])
	var accessories_variant: Variant = snapshot.get("owned_accessories", [])

	var puffs: Array = puffs_variant if puffs_variant is Array else []
	var accessories: Array = accessories_variant if accessories_variant is Array else []

	subtitle_label.text = "Owned accessories: %d | Tracked puffs: %d" % [accessories.size(), puffs.size()]
	_populate_puff_entries(puffs)
	_populate_accessory_entries(accessories)


func _populate_puff_entries(puffs: Array) -> void:
	for puff_variant in puffs:
		if not (puff_variant is Dictionary):
			continue
		var puff: Dictionary = puff_variant
		var unlock_label: String = "Unlocked"
		if not bool(puff.get("story_unlocked", true)):
			unlock_label = "Locked (Story)"
		var equipped_variant: Variant = puff.get("equipped", {})
		var equipped: Dictionary = equipped_variant if equipped_variant is Dictionary else {}

		var effective_stats_variant: Variant = puff.get("effective_stats", {})
		var effective_stats: Dictionary = effective_stats_variant if effective_stats_variant is Dictionary else {}

		var line: String = "%s [%s] Lv.%d  XP %d/%d\nStats: HP %d | ATK %d | DEF %d | MOV %d | RNG %d\nGear: Hat %s | Scarf %s | Ribbon %s" % [
			str(puff.get("display_name", "Puff")),
			unlock_label,
			int(puff.get("level", 1)),
			int(puff.get("xp", 0)),
			int(puff.get("xp_to_next", 0)),
			int(effective_stats.get("hp", 0)),
			int(effective_stats.get("attack", 0)),
			int(effective_stats.get("defense", 0)),
			int(effective_stats.get("move_range", 0)),
			int(effective_stats.get("attack_range", 0)),
			str(equipped.get("hat", "None")),
			str(equipped.get("scarf", "None")),
			str(equipped.get("ribbon", "None"))
		]

		var label: Label = Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		puff_list.add_child(label)

		var separator: HSeparator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		puff_list.add_child(separator)


func _populate_accessory_entries(accessories: Array) -> void:
	for accessory_variant in accessories:
		if not (accessory_variant is Dictionary):
			continue
		var accessory: Dictionary = accessory_variant

		var label: Label = Label.new()
		label.text = "%s (%s)\n%s" % [
			str(accessory.get("display_name", "Accessory")),
			str(accessory.get("slot", "unknown")),
			str(accessory.get("bonuses", "No bonus"))
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		accessory_list.add_child(label)

		var separator: HSeparator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accessory_list.add_child(separator)


func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_progression_updated(_reason: StringName, _payload: Dictionary) -> void:
	if visible:
		_refresh_contents()


func _resolve_progression() -> void:
	if progression_path.is_empty():
		_progression = null
		return
	_progression = get_node_or_null(progression_path)


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
