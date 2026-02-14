extends Node2D
class_name TurnManager

signal phase_changed(phase: StringName, active_side: StringName, turn_number: int)
signal puff_selected(puff: Puff)

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

const PHASE_PLAYER_SELECT: StringName = &"player_select"
const PHASE_PLAYER_ACTION: StringName = &"player_action"
const PHASE_ENEMY_ACTION: StringName = &"enemy_action"
const PHASE_RESOLVE: StringName = &"resolve"

const VALID_PHASE_TRANSITIONS: Dictionary = {
	PHASE_PLAYER_SELECT: [PHASE_PLAYER_ACTION],
	PHASE_PLAYER_ACTION: [PHASE_RESOLVE],
	PHASE_ENEMY_ACTION: [PHASE_RESOLVE],
	PHASE_RESOLVE: [PHASE_ENEMY_ACTION, PHASE_PLAYER_SELECT]
}

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT
]

const DEFAULT_TILE_SIZE: Vector2 = Vector2(128.0, 64.0)
const MOVE_HIGHLIGHT_COLOR: Color = Color(0.5, 0.87, 0.64, 0.38)
const MOVE_HIGHLIGHT_BORDER_COLOR: Color = Color(0.18, 0.56, 0.32, 0.9)

const DEMO_PUFFS: Array[Dictionary] = [
	{
		"team": TEAM_PLAYER,
		"data_path": "res://src/resources/puffs/base/flame_melee.tres",
		"cell": Vector2i(1, 3)
	},
	{
		"team": TEAM_PLAYER,
		"data_path": "res://src/resources/puffs/base/leaf_healer.tres",
		"cell": Vector2i(0, 4)
	},
	{
		"team": TEAM_ENEMY,
		"data_path": "res://src/resources/puffs/base/cloud_tank.tres",
		"cell": Vector2i(1, 2)
	},
	{
		"team": TEAM_ENEMY,
		"data_path": "res://src/resources/puffs/base/droplet_ranged.tres",
		"cell": Vector2i(4, 1)
	}
]

@export var battle_map_path: NodePath
@export var puff_scene: PackedScene = preload("res://src/scenes/puffs/Puff.tscn")
@export var auto_spawn_demo_puffs: bool = true

var turn_order: Array[StringName] = [TEAM_PLAYER, TEAM_ENEMY]
var active_side_index: int = 0
var turn_number: int = 1
var current_phase: StringName = PHASE_PLAYER_SELECT

var _battle_map: BattleMap
var _selected_puff: Puff
var _reachable_cells: Array[Vector2i] = []
var _highlighted_move_cells: Array[Vector2i] = []

var _puffs_by_id: Dictionary = {}
var _team_by_puff_id: Dictionary = {}
var _hp_by_puff_id: Dictionary = {}


func _ready() -> void:
	z_index = 10
	_battle_map = _resolve_battle_map()
	if _battle_map == null:
		push_warning("TurnManager requires a BattleMap reference via battle_map_path.")
		set_process_unhandled_input(false)
		return

	if auto_spawn_demo_puffs and _puffs_by_id.is_empty():
		call_deferred("_spawn_demo_puffs_and_begin_turn")
		return

	_begin_player_turn(true)


func _unhandled_input(event: InputEvent) -> void:
	var tap_screen_position: Variant = _extract_tap_screen_position(event)
	if tap_screen_position == null:
		return
	if _active_side() != TEAM_PLAYER:
		return
	if current_phase != PHASE_PLAYER_SELECT and current_phase != PHASE_PLAYER_ACTION:
		return

	var screen_position: Vector2 = tap_screen_position
	var world_position: Vector2 = _screen_to_world(screen_position)
	var tapped_puff: Puff = _get_puff_at_world_position(world_position)

	if current_phase == PHASE_PLAYER_SELECT:
		if tapped_puff != null and _is_team_member(tapped_puff, TEAM_PLAYER):
			_select_player_puff(tapped_puff)
		return

	if _selected_puff == null:
		return

	if tapped_puff != null:
		if _is_team_member(tapped_puff, TEAM_PLAYER):
			_select_player_puff(tapped_puff)
			return
		if _is_team_member(tapped_puff, TEAM_ENEMY) and _can_attack(_selected_puff, tapped_puff):
			_perform_attack(_selected_puff, tapped_puff)
			return

	var tapped_cell: Vector2i = _world_to_cell(world_position)
	if _can_move_to_cell(tapped_cell):
		_perform_move(_selected_puff, tapped_cell)


func _draw() -> void:
	if _highlighted_move_cells.is_empty():
		return

	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return

	var tile_size: Vector2 = _resolve_tile_size(tile_map_layer)
	for cell in _highlighted_move_cells:
		if not _is_cell_in_bounds(cell):
			continue

		var world_center: Vector2 = tile_map_layer.to_global(tile_map_layer.map_to_local(cell))
		var local_center: Vector2 = to_local(world_center)
		var top: Vector2 = local_center + Vector2(0.0, -tile_size.y * 0.5)
		var right: Vector2 = local_center + Vector2(tile_size.x * 0.5, 0.0)
		var bottom: Vector2 = local_center + Vector2(0.0, tile_size.y * 0.5)
		var left: Vector2 = local_center + Vector2(-tile_size.x * 0.5, 0.0)

		var diamond: PackedVector2Array = PackedVector2Array([top, right, bottom, left])
		draw_colored_polygon(diamond, MOVE_HIGHLIGHT_COLOR)

		var border: PackedVector2Array = PackedVector2Array([top, right, bottom, left, top])
		draw_polyline(border, MOVE_HIGHLIGHT_BORDER_COLOR, 2.0, true)


func register_puff(puff: Puff, team: StringName) -> void:
	if puff == null:
		return
	if team != TEAM_PLAYER and team != TEAM_ENEMY:
		push_warning("Unsupported team '%s' while registering puff." % team)
		return

	var puff_id: int = puff.get_instance_id()
	_puffs_by_id[puff_id] = puff
	_team_by_puff_id[puff_id] = team
	_hp_by_puff_id[puff_id] = _resolve_max_hp(puff)
	puff.set_battle_map(_battle_map)
	puff.tree_exited.connect(_on_registered_puff_exited.bind(puff_id), CONNECT_ONE_SHOT)


func _resolve_battle_map() -> BattleMap:
	var candidate: Node
	if battle_map_path.is_empty():
		candidate = get_parent()
	else:
		candidate = get_node_or_null(battle_map_path)
	if candidate is BattleMap:
		return candidate
	return null


func _spawn_demo_puffs() -> void:
	for puff_config in DEMO_PUFFS:
		_spawn_demo_puff(puff_config)


func _spawn_demo_puffs_and_begin_turn() -> void:
	_spawn_demo_puffs()
	_begin_player_turn(true)


func _spawn_demo_puff(puff_config: Dictionary) -> void:
	if puff_scene == null:
		return

	var puff_instance: Node = puff_scene.instantiate()
	if not (puff_instance is Puff):
		puff_instance.queue_free()
		return

	var puff: Puff = puff_instance
	var puff_parent: Node = get_parent() if get_parent() != null else self
	puff_parent.add_child(puff)

	var puff_data_path: String = str(puff_config.get("data_path", ""))
	var puff_data_resource: Resource = load(puff_data_path)
	if puff_data_resource != null:
		puff.set_puff_data(puff_data_resource)

	var spawn_cell: Vector2i = puff_config.get("cell", Vector2i.ZERO)
	puff.set_grid_cell(spawn_cell)
	puff.set_battle_map(_battle_map)
	puff.name = _build_demo_puff_name(puff_config)

	var team: StringName = puff_config.get("team", TEAM_ENEMY)
	register_puff(puff, team)


func _build_demo_puff_name(puff_config: Dictionary) -> String:
	var team_label: String = str(puff_config.get("team", TEAM_ENEMY))
	var spawn_cell: Vector2i = puff_config.get("cell", Vector2i.ZERO)
	return "%s_%d_%d" % [team_label.capitalize(), spawn_cell.x, spawn_cell.y]


func _begin_player_turn(force: bool = false) -> void:
	active_side_index = turn_order.find(TEAM_PLAYER)
	_clear_selection()
	_set_phase(PHASE_PLAYER_SELECT, force)


func _begin_enemy_turn() -> void:
	active_side_index = turn_order.find(TEAM_ENEMY)
	_clear_selection()
	if _set_phase(PHASE_ENEMY_ACTION):
		call_deferred("_execute_enemy_action")


func _execute_enemy_action() -> void:
	if current_phase != PHASE_ENEMY_ACTION:
		return

	var enemy_units: Array[Puff] = _get_alive_team_puffs(TEAM_ENEMY)
	if enemy_units.is_empty():
		_finish_current_action()
		return

	var enemy_actor: Puff = enemy_units[0]
	var player_target: Puff = _find_closest_target(enemy_actor, TEAM_PLAYER)
	if player_target == null:
		_finish_current_action()
		return

	if _can_attack(enemy_actor, player_target):
		_perform_attack(enemy_actor, player_target)
		return

	var move_range: int = _resolve_move_range(enemy_actor)
	var next_step: Vector2i = _find_next_step_toward(enemy_actor.grid_cell, player_target.grid_cell, move_range, enemy_actor)
	if next_step != enemy_actor.grid_cell:
		_perform_move(enemy_actor, next_step)
	else:
		_finish_current_action()


func _select_player_puff(puff: Puff) -> void:
	if puff == null:
		return
	if not _is_team_member(puff, TEAM_PLAYER):
		return

	_selected_puff = puff
	var move_range: int = _resolve_move_range(puff)
	_reachable_cells = _compute_reachable_cells(puff.grid_cell, move_range, puff)
	_highlighted_move_cells = _reachable_cells.duplicate()
	_highlighted_move_cells.erase(puff.grid_cell)
	queue_redraw()
	emit_signal("puff_selected", puff)

	if current_phase == PHASE_PLAYER_SELECT:
		_set_phase(PHASE_PLAYER_ACTION)


func _perform_move(actor: Puff, target_cell: Vector2i) -> void:
	if actor == null:
		return
	var from_cell: Vector2i = actor.grid_cell
	actor.set_grid_cell(target_cell)
	_emit_signal_bus("puff_moved", [StringName(actor.name), from_cell, target_cell])
	_finish_current_action()


func _perform_attack(attacker: Puff, defender: Puff) -> void:
	if attacker == null or defender == null:
		return

	var defender_id: int = defender.get_instance_id()
	var damage: int = _calculate_damage(attacker, defender)
	var new_hp: int = _resolve_current_hp(defender) - damage
	_hp_by_puff_id[defender_id] = new_hp

	if new_hp <= 0:
		_unregister_puff(defender)
		defender.queue_free()

	_finish_current_action()


func _finish_current_action() -> void:
	if not _set_phase(PHASE_RESOLVE):
		return
	_resolve_phase()


func _resolve_phase() -> void:
	if _check_for_battle_end():
		return

	_emit_signal_bus("turn_ended", [turn_number])

	if _active_side() == TEAM_PLAYER:
		_begin_enemy_turn()
		return

	turn_number += 1
	_begin_player_turn()


func _check_for_battle_end() -> bool:
	var player_alive: bool = _has_alive_members(TEAM_PLAYER)
	var enemy_alive: bool = _has_alive_members(TEAM_ENEMY)

	if player_alive and enemy_alive:
		return false

	var winner: StringName = TEAM_PLAYER if player_alive else TEAM_ENEMY
	_emit_signal_bus("battle_ended", [winner])
	set_process_unhandled_input(false)
	_clear_selection()
	return true


func _set_phase(new_phase: StringName, force: bool = false) -> bool:
	if not force:
		var allowed_phases: Array = VALID_PHASE_TRANSITIONS.get(current_phase, [])
		if not allowed_phases.has(new_phase):
			push_warning("Invalid phase transition: %s -> %s" % [current_phase, new_phase])
			return false
	current_phase = new_phase
	emit_signal("phase_changed", current_phase, _active_side(), turn_number)
	return true


func _extract_tap_screen_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		return event.position
	return null


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _world_to_cell(world_position: Vector2) -> Vector2i:
	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return Vector2i(-1, -1)
	var local_position: Vector2 = tile_map_layer.to_local(world_position)
	return tile_map_layer.local_to_map(local_position)


func _get_puff_at_world_position(world_position: Vector2) -> Puff:
	var state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits: Array[Dictionary] = state.intersect_point(query, 8)
	for hit in hits:
		var collider: Variant = hit.get("collider")
		if collider is Puff:
			var puff_id: int = collider.get_instance_id()
			if _puffs_by_id.has(puff_id):
				return collider
	return null


func _can_move_to_cell(target_cell: Vector2i) -> bool:
	if _selected_puff == null:
		return false
	if not _is_cell_in_bounds(target_cell):
		return false
	if target_cell == _selected_puff.grid_cell:
		return false
	return _reachable_cells.has(target_cell)


func _can_attack(attacker: Puff, defender: Puff) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker == defender:
		return false
	if not _is_cell_in_bounds(attacker.grid_cell) or not _is_cell_in_bounds(defender.grid_cell):
		return false
	var attack_range: int = _resolve_attack_range(attacker)
	return _grid_distance(attacker.grid_cell, defender.grid_cell) <= attack_range


func _compute_reachable_cells(origin: Vector2i, max_steps: int, moving_puff: Puff) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = [origin]
	if max_steps <= 0:
		return reachable

	var frontier: Array[Vector2i] = [origin]
	var distance_by_cell: Dictionary = {origin: 0}

	while not frontier.is_empty():
		var current_cell: Vector2i = frontier.pop_front()
		var current_distance: int = int(distance_by_cell[current_cell])
		if current_distance >= max_steps:
			continue

		for offset in CARDINAL_OFFSETS:
			var candidate_cell: Vector2i = current_cell + offset
			if not _is_cell_in_bounds(candidate_cell):
				continue
			if distance_by_cell.has(candidate_cell):
				continue
			if _is_cell_occupied(candidate_cell, moving_puff):
				continue

			var next_distance: int = current_distance + 1
			distance_by_cell[candidate_cell] = next_distance
			frontier.push_back(candidate_cell)
			reachable.append(candidate_cell)

	return reachable


func _find_next_step_toward(origin: Vector2i, target: Vector2i, max_steps: int, moving_puff: Puff) -> Vector2i:
	if origin == target or max_steps <= 0:
		return origin

	var reachable: Array[Vector2i] = _compute_reachable_cells(origin, max_steps, moving_puff)
	var best_cell: Vector2i = origin
	var best_distance: int = _grid_distance(origin, target)

	for cell in reachable:
		var candidate_distance: int = _grid_distance(cell, target)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_cell = cell

	return best_cell


func _find_closest_target(actor: Puff, target_team: StringName) -> Puff:
	var targets: Array[Puff] = _get_alive_team_puffs(target_team)
	if targets.is_empty():
		return null

	var closest_target: Puff = targets[0]
	var closest_distance: int = _grid_distance(actor.grid_cell, closest_target.grid_cell)

	for target in targets:
		var candidate_distance: int = _grid_distance(actor.grid_cell, target.grid_cell)
		if candidate_distance < closest_distance:
			closest_target = target
			closest_distance = candidate_distance

	return closest_target


func _calculate_damage(attacker: Puff, defender: Puff) -> int:
	var base_damage: int = maxi(1, _resolve_attack_stat(attacker) - _resolve_defense_stat(defender))
	var multiplier: float = _resolve_element_multiplier(attacker, defender)
	return maxi(1, int(round(float(base_damage) * multiplier)))


func _resolve_element_multiplier(attacker: Puff, defender: Puff) -> float:
	var attacker_data: PuffData = attacker.puff_data as PuffData
	var defender_data: PuffData = defender.puff_data as PuffData
	if attacker_data == null or defender_data == null:
		return 1.0
	return attacker_data.get_damage_multiplier_against(defender_data.element)


func _resolve_attack_stat(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	return maxi(1, puff_data.attack)


func _resolve_defense_stat(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 0
	return maxi(0, puff_data.defense)


func _resolve_move_range(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	return maxi(1, puff_data.move_range)


func _resolve_attack_range(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	return maxi(1, puff_data.attack_range)


func _resolve_max_hp(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	return maxi(1, puff_data.hp)


func _resolve_current_hp(puff: Puff) -> int:
	var puff_id: int = puff.get_instance_id()
	if not _hp_by_puff_id.has(puff_id):
		_hp_by_puff_id[puff_id] = _resolve_max_hp(puff)
	return int(_hp_by_puff_id[puff_id])


func _resolve_tile_map_layer() -> TileMapLayer:
	if _battle_map == null:
		return null
	return _battle_map.get_node_or_null("TileMapLayer")


func _resolve_tile_size(tile_map_layer: TileMapLayer) -> Vector2:
	if tile_map_layer == null or tile_map_layer.tile_set == null:
		return DEFAULT_TILE_SIZE
	return Vector2(tile_map_layer.tile_set.tile_size)


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	if _battle_map == null:
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < _battle_map.map_size.x and cell.y < _battle_map.map_size.y


func _is_cell_occupied(cell: Vector2i, ignored_puff: Puff = null) -> bool:
	for puff_variant in _puffs_by_id.values():
		var puff: Puff = puff_variant
		if puff == null or not is_instance_valid(puff):
			continue
		if puff == ignored_puff:
			continue
		if puff.grid_cell == cell:
			return true
	return false


func _is_team_member(puff: Puff, team: StringName) -> bool:
	if puff == null:
		return false
	var puff_id: int = puff.get_instance_id()
	return _team_by_puff_id.get(puff_id, &"") == team


func _has_alive_members(team: StringName) -> bool:
	for puff_id in _puffs_by_id.keys():
		var puff: Puff = _puffs_by_id[puff_id]
		if puff == null or not is_instance_valid(puff):
			continue
		if _team_by_puff_id.get(puff_id, &"") == team:
			return true
	return false


func _get_alive_team_puffs(team: StringName) -> Array[Puff]:
	var team_puffs: Array[Puff] = []
	for puff_id in _puffs_by_id.keys():
		var puff: Puff = _puffs_by_id[puff_id]
		if puff == null or not is_instance_valid(puff):
			continue
		if _team_by_puff_id.get(puff_id, &"") == team:
			team_puffs.append(puff)
	return team_puffs


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _active_side() -> StringName:
	if active_side_index < 0 or active_side_index >= turn_order.size():
		return TEAM_PLAYER
	return turn_order[active_side_index]


func _clear_selection() -> void:
	_selected_puff = null
	_reachable_cells.clear()
	_highlighted_move_cells.clear()
	queue_redraw()


func _on_registered_puff_exited(puff_id: int) -> void:
	_unregister_puff_id(puff_id)


func _unregister_puff(puff: Puff) -> void:
	if puff == null:
		return
	_unregister_puff_id(puff.get_instance_id())


func _unregister_puff_id(puff_id: int) -> void:
	_puffs_by_id.erase(puff_id)
	_team_by_puff_id.erase(puff_id)
	_hp_by_puff_id.erase(puff_id)


func _emit_signal_bus(signal_name: StringName, args: Array = []) -> void:
	var signal_bus: Node = get_node_or_null("/root/SignalBus")
	if signal_bus == null:
		return
	var emit_args: Array = [signal_name]
	emit_args.append_array(args)
	signal_bus.callv("emit_signal", emit_args)
