extends CanvasLayer

@export var turn_manager_path: NodePath = NodePath("../TurnManager")

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

@onready var _turn_banner: Label = $TurnBanner
@onready var _score_panel: PanelContainer = $ScorePanel
@onready var _score_label: Label = $ScorePanel/ScoreLabel
@onready var _result_overlay: ColorRect = $ResultOverlay
@onready var _result_label: Label = $ResultOverlay/ResultLabel

var _turn_manager: TurnManager


func _ready() -> void:
	_resolve_turn_manager()
	_configure_layout()
	_apply_styles()
	_connect_turn_manager_signals()
	_set_turn_banner_text(TEAM_PLAYER, 1, TurnManager.PHASE_PLAYER_SELECT)
	_hide_result_overlay()


func _resolve_turn_manager() -> void:
	if turn_manager_path == NodePath():
		return

	var candidate: Node = get_node_or_null(turn_manager_path)
	if candidate is TurnManager:
		_turn_manager = candidate


func _configure_layout() -> void:
	_configure_turn_banner_layout()
	_configure_score_panel_layout()
	_configure_result_overlay_layout()


func _configure_turn_banner_layout() -> void:
	_turn_banner.anchor_left = 0.5
	_turn_banner.anchor_right = 0.5
	_turn_banner.anchor_top = 0.04
	_turn_banner.anchor_bottom = 0.04
	_turn_banner.offset_left = -140.0
	_turn_banner.offset_top = -28.0
	_turn_banner.offset_right = 140.0
	_turn_banner.offset_bottom = 28.0
	_turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_banner.text = ""
	_turn_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_turn_banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _configure_score_panel_layout() -> void:
	_score_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score_panel.offset_left = -210.0
	_score_panel.offset_top = 24.0
	_score_panel.offset_right = -16.0
	_score_panel.offset_bottom = 92.0
	_score_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_score_panel.size_flags_horizontal = Control.SIZE_SHRINK_END

	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.text = "Turn 1"
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_result_overlay_layout() -> void:
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.text = ""
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_result_label.set_anchors_preset(Control.PRESET_CENTER)
	_result_label.offset_left = -220.0
	_result_label.offset_top = -64.0
	_result_label.offset_right = 220.0
	_result_label.offset_bottom = 64.0


func _apply_styles() -> void:
	VisualTheme.apply_label_theme(_turn_banner, Constants.FONT_SIZE_HUD, Color.WHITE)
	var banner_box: StyleBoxFlat = VisualTheme.create_panel_stylebox(
		Constants.PALETTE_LAVENDER,
		22,
		Color.WHITE
	)
	_turn_banner.add_theme_stylebox_override("normal", banner_box)

	var panel_box: StyleBoxFlat = VisualTheme.create_panel_stylebox(
		Constants.COLOR_BG_DARK_OVERLAY,
		14,
		Color.WHITE
	)
	_score_panel.add_theme_stylebox_override("panel", panel_box)
	VisualTheme.apply_label_theme(_score_label, Constants.FONT_SIZE_BODY, Constants.COLOR_TEXT_LIGHT)

	_result_overlay.color = Constants.COLOR_BG_DARK_OVERLAY
	VisualTheme.apply_label_theme(_result_label, Constants.FONT_SIZE_TITLE, Color.WHITE)
	_result_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	_result_label.add_theme_constant_override("shadow_offset_x", 2)
	_result_label.add_theme_constant_override("shadow_offset_y", 2)
	_result_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))


func _connect_turn_manager_signals() -> void:
	if _turn_manager == null:
		return

	if not _turn_manager.phase_changed.is_connected(_on_turn_manager_phase_changed):
		_turn_manager.phase_changed.connect(_on_turn_manager_phase_changed)
	if not _turn_manager.battle_ended.is_connected(_on_turn_manager_battle_ended):
		_turn_manager.battle_ended.connect(_on_turn_manager_battle_ended)


func _on_turn_manager_phase_changed(phase: StringName, active_side: StringName, turn_number: int) -> void:
	_set_turn_banner_text(active_side, turn_number, phase)


func _set_turn_banner_text(active_side: StringName, turn_number: int, phase: StringName) -> void:
	match phase:
		TurnManager.PHASE_PLAYER_SELECT, TurnManager.PHASE_PLAYER_ACTION:
			_turn_banner.text = "Your Turn"
		TurnManager.PHASE_ENEMY_ACTION:
			_turn_banner.text = "Enemy Turn"
		TurnManager.PHASE_RESOLVE:
			_turn_banner.text = "Resolving..."
		_:
			if active_side == TEAM_PLAYER:
				_turn_banner.text = "Your Turn"
			else:
				_turn_banner.text = "Enemy Turn"

	_score_label.text = "Turn %d" % [turn_number]


func _on_turn_manager_battle_ended(winner: StringName) -> void:
	_result_overlay.visible = true
	if winner == TEAM_PLAYER:
		_result_label.text = "Victory!"
	else:
		_result_label.text = "Defeat"


func _hide_result_overlay() -> void:
	_result_overlay.visible = false
