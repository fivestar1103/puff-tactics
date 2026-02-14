extends Node2D
class_name EnemyIntent

const DEFAULT_TILE_SIZE: Vector2 = Vector2(128.0, 64.0)

const INTENT_ACTION_WAIT: StringName = &"wait"
const INTENT_ACTION_MOVE: StringName = &"move"
const INTENT_ACTION_ATTACK: StringName = &"attack"
const INTENT_ACTION_SKILL: StringName = &"skill"

const MOVE_ARROW_COLOR: Color = Color(0.53, 0.78, 0.98, 0.62)
const MOVE_DEST_FILL_COLOR: Color = Color(0.53, 0.78, 0.98, 0.22)
const MOVE_DEST_BORDER_COLOR: Color = Color(0.53, 0.78, 0.98, 0.78)

const ATTACK_FILL_COLOR: Color = Color(0.99, 0.49, 0.57, 0.24)
const ATTACK_BORDER_COLOR: Color = Color(0.99, 0.49, 0.57, 0.8)

const SKILL_FILL_COLOR: Color = Color(0.86, 0.72, 0.99, 0.21)
const SKILL_BORDER_COLOR: Color = Color(0.86, 0.72, 0.99, 0.76)
const SKILL_PRIMARY_FILL_COLOR: Color = Color(0.99, 0.82, 0.47, 0.23)
const SKILL_PRIMARY_BORDER_COLOR: Color = Color(0.99, 0.82, 0.47, 0.82)

@export var battle_map_path: NodePath
@export var turn_manager_path: NodePath

var enemy_intents: Dictionary = {}

var _battle_map: Node2D
var _turn_manager: Node
var _signal_bus: Node


func _ready() -> void:
	z_index = 20
	_battle_map = _resolve_battle_map()
	_turn_manager = _resolve_turn_manager()
	if _battle_map == null or _turn_manager == null:
		push_warning("EnemyIntent requires battle_map_path and turn_manager_path references.")
		return

	_connect_turn_manager_signals()
	_connect_signal_bus_signals()
	call_deferred("recalculate_intents")


func recalculate_intents() -> void:
	if _turn_manager == null or not _turn_manager.has_method("get_enemy_intent_snapshot"):
		enemy_intents.clear()
		queue_redraw()
		return

	var snapshot_variant: Variant = _turn_manager.call("get_enemy_intent_snapshot")
	if snapshot_variant is Dictionary:
		enemy_intents = snapshot_variant.duplicate(true)
	else:
		enemy_intents.clear()

	queue_redraw()


func get_enemy_intents() -> Dictionary:
	return enemy_intents.duplicate(true)


func _draw() -> void:
	if enemy_intents.is_empty():
		return

	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return

	var tile_size: Vector2 = _resolve_tile_size(tile_map_layer)
	for intent_variant in enemy_intents.values():
		if not (intent_variant is Dictionary):
			continue
		var intent: Dictionary = intent_variant
		var action: StringName = intent.get("action", INTENT_ACTION_WAIT)
		var actor_cell: Vector2i = intent.get("actor_cell", Vector2i.ZERO)
		if not _is_cell_in_bounds(actor_cell):
			continue

		match action:
			INTENT_ACTION_MOVE:
				var move_cell: Vector2i = intent.get("move_cell", actor_cell)
				_draw_move_intent(actor_cell, move_cell, tile_map_layer, tile_size)
			INTENT_ACTION_ATTACK:
				var target_cell: Vector2i = intent.get("target_cell", actor_cell)
				_draw_attack_intent(target_cell, tile_map_layer, tile_size)
			INTENT_ACTION_SKILL:
				var target_cell: Vector2i = intent.get("target_cell", actor_cell)
				var skill_cells: Array[Vector2i] = _to_vector2i_array(intent.get("skill_cells", []))
				_draw_skill_intent(skill_cells, target_cell, tile_map_layer, tile_size)
			_:
				pass


func _draw_move_intent(from_cell: Vector2i, move_cell: Vector2i, tile_map_layer: TileMapLayer, tile_size: Vector2) -> void:
	if not _is_cell_in_bounds(move_cell):
		return

	var from_center: Vector2 = _cell_to_local_center(from_cell, tile_map_layer)
	var move_center: Vector2 = _cell_to_local_center(move_cell, tile_map_layer)

	if from_cell != move_cell:
		draw_line(from_center, move_center, MOVE_ARROW_COLOR, 4.0, true)
		_draw_arrow_head(from_center, move_center, MOVE_ARROW_COLOR)

	_draw_diamond_at_cell(move_cell, MOVE_DEST_FILL_COLOR, MOVE_DEST_BORDER_COLOR, tile_map_layer, tile_size)
	draw_circle(move_center, 5.0, MOVE_DEST_BORDER_COLOR)


func _draw_attack_intent(target_cell: Vector2i, tile_map_layer: TileMapLayer, tile_size: Vector2) -> void:
	if not _is_cell_in_bounds(target_cell):
		return

	_draw_diamond_at_cell(target_cell, ATTACK_FILL_COLOR, ATTACK_BORDER_COLOR, tile_map_layer, tile_size)
	var center: Vector2 = _cell_to_local_center(target_cell, tile_map_layer)
	var radius: float = minf(tile_size.x, tile_size.y) * 0.16
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), ATTACK_BORDER_COLOR, 2.0, true)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), ATTACK_BORDER_COLOR, 2.0, true)


func _draw_skill_intent(skill_cells: Array[Vector2i], primary_target_cell: Vector2i, tile_map_layer: TileMapLayer, tile_size: Vector2) -> void:
	for cell in skill_cells:
		if not _is_cell_in_bounds(cell):
			continue
		_draw_diamond_at_cell(cell, SKILL_FILL_COLOR, SKILL_BORDER_COLOR, tile_map_layer, tile_size)

	if _is_cell_in_bounds(primary_target_cell):
		_draw_diamond_at_cell(primary_target_cell, SKILL_PRIMARY_FILL_COLOR, SKILL_PRIMARY_BORDER_COLOR, tile_map_layer, tile_size)
		var center: Vector2 = _cell_to_local_center(primary_target_cell, tile_map_layer)
		draw_circle(center, 6.0, SKILL_PRIMARY_BORDER_COLOR)


func _draw_arrow_head(start: Vector2, finish: Vector2, color: Color) -> void:
	var direction: Vector2 = finish - start
	if direction.length_squared() <= 0.001:
		return

	var unit_direction: Vector2 = direction.normalized()
	var tangent: Vector2 = Vector2(-unit_direction.y, unit_direction.x)
	var head_length: float = 13.0
	var head_width: float = 7.0

	var tip: Vector2 = finish
	var left: Vector2 = tip - (unit_direction * head_length) + (tangent * head_width)
	var right: Vector2 = tip - (unit_direction * head_length) - (tangent * head_width)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), color)


func _draw_diamond_at_cell(
	cell: Vector2i,
	fill_color: Color,
	border_color: Color,
	tile_map_layer: TileMapLayer,
	tile_size: Vector2
) -> void:
	var center: Vector2 = _cell_to_local_center(cell, tile_map_layer)
	var top: Vector2 = center + Vector2(0.0, -tile_size.y * 0.5)
	var right: Vector2 = center + Vector2(tile_size.x * 0.5, 0.0)
	var bottom: Vector2 = center + Vector2(0.0, tile_size.y * 0.5)
	var left: Vector2 = center + Vector2(-tile_size.x * 0.5, 0.0)

	var diamond: PackedVector2Array = PackedVector2Array([top, right, bottom, left])
	draw_colored_polygon(diamond, fill_color)

	var border: PackedVector2Array = PackedVector2Array([top, right, bottom, left, top])
	draw_polyline(border, border_color, 2.0, true)


func _cell_to_local_center(cell: Vector2i, tile_map_layer: TileMapLayer) -> Vector2:
	var world_center: Vector2 = tile_map_layer.to_global(tile_map_layer.map_to_local(cell))
	return to_local(world_center)


func _resolve_battle_map() -> Node2D:
	var candidate: Node
	if battle_map_path.is_empty():
		candidate = get_parent()
	else:
		candidate = get_node_or_null(battle_map_path)
	if candidate is Node2D:
		return candidate
	return null


func _resolve_turn_manager() -> Node:
	var candidate: Node
	if turn_manager_path.is_empty():
		candidate = get_parent().get_node_or_null("TurnManager")
	else:
		candidate = get_node_or_null(turn_manager_path)
	if candidate != null and candidate.has_method("get_enemy_intent_snapshot"):
		return candidate
	return null


func _resolve_tile_map_layer() -> TileMapLayer:
	if _battle_map == null:
		return null
	if _battle_map is TileMapLayer:
		return _battle_map
	return _battle_map.get_node_or_null("TileMapLayer")


func _resolve_tile_size(tile_map_layer: TileMapLayer) -> Vector2:
	if tile_map_layer == null or tile_map_layer.tile_set == null:
		return DEFAULT_TILE_SIZE
	return Vector2(tile_map_layer.tile_set.tile_size)


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	if _battle_map == null:
		return false
	var map_size_variant: Variant = _battle_map.get("map_size")
	if not (map_size_variant is Vector2i):
		return false

	var map_size: Vector2i = map_size_variant
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y


func _to_vector2i_array(cells_variant: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not (cells_variant is Array):
		return cells

	var raw_cells: Array = cells_variant
	for cell_variant in raw_cells:
		if not (cell_variant is Vector2i):
			continue
		var cell: Vector2i = cell_variant
		if cells.has(cell):
			continue
		cells.append(cell)

	return cells


func _connect_turn_manager_signals() -> void:
	if _turn_manager == null:
		return
	_connect_if_available(_turn_manager, &"phase_changed", Callable(self, "_on_turn_phase_changed"))


func _connect_signal_bus_signals() -> void:
	_signal_bus = get_node_or_null("/root/SignalBus")
	if _signal_bus == null:
		return

	_connect_if_available(_signal_bus, &"puff_moved", Callable(self, "_on_signal_bus_puff_moved"))
	_connect_if_available(_signal_bus, &"puff_bumped", Callable(self, "_on_signal_bus_puff_bumped"))
	_connect_if_available(_signal_bus, &"turn_ended", Callable(self, "_on_signal_bus_turn_ended"))
	_connect_if_available(_signal_bus, &"battle_ended", Callable(self, "_on_signal_bus_battle_ended"))


func _connect_if_available(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)


func _on_turn_phase_changed(_phase: StringName, _active_side: StringName, _turn_number: int) -> void:
	recalculate_intents()


func _on_signal_bus_puff_moved(_puff_id: StringName, _from_cell: Vector2i, _to_cell: Vector2i) -> void:
	recalculate_intents()


func _on_signal_bus_puff_bumped(_puff_id: StringName, _direction: Vector2i) -> void:
	recalculate_intents()


func _on_signal_bus_turn_ended(_turn_number: int) -> void:
	recalculate_intents()


func _on_signal_bus_battle_ended(_result: StringName) -> void:
	enemy_intents.clear()
	queue_redraw()
