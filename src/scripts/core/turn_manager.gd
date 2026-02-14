extends Node2D
class_name TurnManager

signal phase_changed(phase: StringName, active_side: StringName, turn_number: int)
signal puff_selected(puff: Puff)
signal action_resolved(side: StringName, action_payload: Dictionary)

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

const PHASE_PLAYER_SELECT: StringName = &"player_select"
const PHASE_PLAYER_ACTION: StringName = &"player_action"
const PHASE_ENEMY_ACTION: StringName = &"enemy_action"
const PHASE_RESOLVE: StringName = &"resolve"

const INTENT_ACTION_WAIT: StringName = &"wait"
const INTENT_ACTION_MOVE: StringName = &"move"
const INTENT_ACTION_ATTACK: StringName = &"attack"
const INTENT_ACTION_SKILL: StringName = &"skill"

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
const BUMP_SYSTEM_SCRIPT: GDScript = preload("res://src/scripts/battle/bump_system.gd")
const UTILITY_AI_SCRIPT: GDScript = preload("res://src/scripts/ai/utility_ai.gd")
const PUFF_ANIMATOR_SCRIPT: GDScript = preload("res://src/scripts/ui/puff_animator.gd")
const BUMP_PUSH_DURATION: float = 0.16
const BUMP_FALL_DURATION: float = 0.22
const BUMP_FALL_DROP_OFFSET: Vector2 = Vector2(0.0, 36.0)

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
@export var auto_begin_turn_cycle: bool = true
@export_range(0.0, 5.0, 0.05) var ai_attack_value_weight: float = 1.2
@export_range(0.0, 5.0, 0.05) var ai_survival_risk_weight: float = 1.0
@export_range(0.0, 5.0, 0.05) var ai_positional_advantage_weight: float = 0.8
@export_range(0.0, 5.0, 0.05) var ai_bump_opportunity_weight: float = 1.35

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
var _team_turn_index: Dictionary = {
	TEAM_PLAYER: 0,
	TEAM_ENEMY: 0
}
var _stun_state_by_puff_id: Dictionary = {}
var _bump_system: RefCounted = BUMP_SYSTEM_SCRIPT.new()
var _utility_ai: RefCounted = UTILITY_AI_SCRIPT.new()
var _puff_animator: RefCounted = PUFF_ANIMATOR_SCRIPT.new()
var _is_resolving_bump: bool = false
var _is_action_locked: bool = false
var _battle_has_ended: bool = false


func _ready() -> void:
	z_index = 10
	_sync_utility_ai_weights()
	_battle_map = _resolve_battle_map()
	if _battle_map == null:
		push_warning("TurnManager requires a BattleMap reference via battle_map_path.")
		set_process_unhandled_input(false)
		return

	if auto_spawn_demo_puffs and _puffs_by_id.is_empty():
		if auto_begin_turn_cycle:
			call_deferred("_spawn_demo_puffs_and_begin_turn")
		else:
			call_deferred("_spawn_demo_puffs")
		return

	if auto_begin_turn_cycle:
		begin_turn_cycle(true)
	else:
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if _is_resolving_bump or _is_action_locked:
		return
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
		if _is_team_member(tapped_puff, TEAM_ENEMY):
			if _can_bump(_selected_puff, tapped_puff):
				if _perform_bump(_selected_puff, tapped_puff):
					return
			if _can_attack(_selected_puff, tapped_puff):
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


func begin_turn_cycle(force: bool = true) -> void:
	if _battle_map == null:
		return
	_battle_has_ended = false
	_is_action_locked = false
	_is_resolving_bump = false
	set_process_unhandled_input(true)
	_begin_player_turn(force)


func end_battle(winner: StringName) -> void:
	if winner != TEAM_PLAYER and winner != TEAM_ENEMY:
		push_warning("Unsupported winner '%s' for battle end." % winner)
		return
	if _battle_has_ended:
		return

	_battle_has_ended = true
	_is_action_locked = false
	_is_resolving_bump = false
	_emit_signal_bus("battle_ended", [winner])
	set_process_unhandled_input(false)
	_clear_selection()


func get_alive_team_snapshot(team: StringName) -> Array[Puff]:
	var team_snapshot: Array[Puff] = []
	for puff in _get_alive_team_puffs(team):
		team_snapshot.append(puff)
	return team_snapshot


func get_current_hp(puff: Puff) -> int:
	if puff == null:
		return 0
	return _resolve_current_hp(puff)


func get_puff_team(puff: Puff) -> StringName:
	if puff == null:
		return &""
	return _team_by_puff_id.get(puff.get_instance_id(), &"")


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
	var team: StringName = puff_config.get("team", TEAM_ENEMY)
	var puff_data_resource: Resource = _load_puff_data_for_team(puff_data_path, team)
	if puff_data_resource != null:
		puff.set_puff_data(puff_data_resource)

	var spawn_cell: Vector2i = puff_config.get("cell", Vector2i.ZERO)
	puff.set_grid_cell(spawn_cell)
	puff.set_battle_map(_battle_map)
	puff.name = _build_demo_puff_name(puff_config)

	register_puff(puff, team)


func _build_demo_puff_name(puff_config: Dictionary) -> String:
	var team_label: String = str(puff_config.get("team", TEAM_ENEMY))
	var spawn_cell: Vector2i = puff_config.get("cell", Vector2i.ZERO)
	return "%s_%d_%d" % [team_label.capitalize(), spawn_cell.x, spawn_cell.y]


func _begin_player_turn(force: bool = false) -> void:
	if _battle_has_ended:
		return
	active_side_index = turn_order.find(TEAM_PLAYER)
	_increment_team_turn(TEAM_PLAYER)
	_recover_stunned_puffs_for_team(TEAM_PLAYER)
	_clear_selection()
	if _set_phase(PHASE_PLAYER_SELECT, force) and _get_actionable_team_puffs(TEAM_PLAYER).is_empty():
		call_deferred("_skip_player_turn_without_actions")


func _begin_enemy_turn() -> void:
	if _battle_has_ended:
		return
	active_side_index = turn_order.find(TEAM_ENEMY)
	_increment_team_turn(TEAM_ENEMY)
	_recover_stunned_puffs_for_team(TEAM_ENEMY)
	_clear_selection()
	if _set_phase(PHASE_ENEMY_ACTION):
		call_deferred("_execute_enemy_action")


func get_enemy_intent_snapshot() -> Dictionary:
	_sync_utility_ai_weights()
	var intents_by_enemy_id: Dictionary = {}
	for enemy_puff in _get_actionable_team_puffs(TEAM_ENEMY):
		var puff_id: int = enemy_puff.get_instance_id()
		intents_by_enemy_id[puff_id] = _build_enemy_intent(enemy_puff)
	return intents_by_enemy_id


func _execute_enemy_action() -> void:
	if current_phase != PHASE_ENEMY_ACTION or _is_resolving_bump or _is_action_locked:
		return

	_sync_utility_ai_weights()
	var enemy_units: Array[Puff] = _get_actionable_team_puffs(TEAM_ENEMY)
	if enemy_units.is_empty():
		_finish_current_action()
		return

	var enemy_actor: Puff = enemy_units[0]
	var planned_intent: Dictionary = _build_enemy_intent(enemy_actor)
	var action_type: StringName = planned_intent.get("action", INTENT_ACTION_WAIT)
	var target_puff: Puff = _resolve_intent_target_puff(planned_intent)

	match action_type:
		INTENT_ACTION_SKILL:
			if target_puff != null and _can_bump(enemy_actor, target_puff):
				if _perform_bump(enemy_actor, target_puff):
					return
		INTENT_ACTION_ATTACK:
			if target_puff != null and _can_attack(enemy_actor, target_puff):
				_perform_attack(enemy_actor, target_puff)
				return
		INTENT_ACTION_MOVE:
			var move_cell: Vector2i = planned_intent.get("move_cell", enemy_actor.grid_cell)
			if move_cell != enemy_actor.grid_cell:
				_perform_move(enemy_actor, move_cell)
				return

	_finish_current_action()


func _select_player_puff(puff: Puff) -> void:
	if puff == null:
		return
	if not _is_team_member(puff, TEAM_PLAYER):
		return
	if not _is_puff_actionable(puff):
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
	if not _is_puff_actionable(actor):
		return

	var from_cell: Vector2i = actor.grid_cell
	_is_action_locked = true
	var path_cells: Array[Vector2i] = _build_shortest_path(from_cell, target_cell, actor)
	var world_path: Array[Vector2] = _build_world_path(path_cells)
	var move_tween: Tween = _puff_animator.play_move_bounce(actor, world_path)
	if move_tween != null:
		await move_tween.finished
	if actor == null or not is_instance_valid(actor):
		_is_action_locked = false
		_finish_current_action()
		return
	actor.scale = Vector2.ONE
	actor.set_grid_cell(target_cell)
	_emit_signal_bus("puff_moved", [StringName(actor.name), from_cell, target_cell])

	var action_payload: Dictionary = _build_action_payload_base(actor, INTENT_ACTION_MOVE)
	action_payload["actor_cell_before"] = from_cell
	action_payload["actor_cell_after"] = target_cell
	action_payload["target_cell"] = target_cell
	_emit_action_resolved(action_payload)

	_is_action_locked = false
	_finish_current_action()


func _perform_attack(attacker: Puff, defender: Puff) -> void:
	if attacker == null or defender == null:
		return
	if not _is_puff_actionable(attacker) or not _is_puff_actionable(defender):
		return

	_is_action_locked = true
	var attack_tween: Tween = _puff_animator.play_attack_inflate_squish(attacker, defender.global_position)
	if attack_tween != null:
		await attack_tween.finished
	if attacker == null or not is_instance_valid(attacker):
		_is_action_locked = false
		_finish_current_action()
		return
	if defender == null or not is_instance_valid(defender):
		attacker.scale = Vector2.ONE
		_is_action_locked = false
		_finish_current_action()
		return
	attacker.scale = Vector2.ONE

	var defender_name: String = defender.name
	var defender_cell: Vector2i = defender.grid_cell
	var defending_team: StringName = get_puff_team(defender)
	var opposing_team_hp_before: int = _compute_team_total_hp(defending_team)
	var defender_hp_before: int = _resolve_current_hp(defender)
	var defender_id: int = defender.get_instance_id()
	var damage: int = _calculate_damage(attacker, defender)
	var new_hp: int = defender_hp_before - damage
	_hp_by_puff_id[defender_id] = new_hp

	var was_knocked_out: bool = new_hp <= 0
	if new_hp <= 0:
		var defeat_tween: Tween = _puff_animator.play_defeat_deflate_fade(defender)
		if defeat_tween != null:
			await defeat_tween.finished
		_unregister_puff(defender)
		if defender != null and is_instance_valid(defender):
			defender.queue_free()

	var opposing_team_hp_after: int = _compute_team_total_hp(defending_team)
	var hp_swing: int = maxi(0, opposing_team_hp_before - opposing_team_hp_after)
	var hp_swing_ratio: float = 0.0
	if opposing_team_hp_before > 0:
		hp_swing_ratio = float(hp_swing) / float(opposing_team_hp_before)

	var action_payload: Dictionary = _build_action_payload_base(attacker, INTENT_ACTION_ATTACK)
	action_payload["target_id"] = defender_name
	action_payload["target_cell"] = defender_cell
	action_payload["damage"] = damage
	action_payload["target_hp_before"] = defender_hp_before
	action_payload["target_hp_after"] = maxi(0, new_hp)
	action_payload["hp_swing"] = hp_swing
	action_payload["hp_swing_ratio"] = hp_swing_ratio
	action_payload["knockout"] = was_knocked_out
	action_payload["knockout_count"] = 1 if was_knocked_out else 0
	action_payload["changed_outcome"] = was_knocked_out or hp_swing_ratio >= 0.3
	_emit_action_resolved(action_payload)

	_is_action_locked = false
	_finish_current_action()


func _perform_bump(attacker: Puff, defender: Puff) -> bool:
	if attacker == null or defender == null:
		return false
	if _is_resolving_bump:
		return false
	if not _is_puff_actionable(attacker) or not _is_puff_actionable(defender):
		return false

	var bump_result: Dictionary = _bump_system.resolve_bump(
		attacker,
		defender,
		Callable(self, "_get_actionable_puff_at_cell"),
		Callable(self, "_is_cell_in_bounds"),
		Callable(self, "_is_cliff_cell")
	)
	if not bool(bump_result.get("valid", false)):
		return false

	var pushes: Array = bump_result.get("pushes", [])
	if pushes.is_empty():
		return false

	var direction: Vector2i = bump_result.get("direction", Vector2i.ZERO)
	var cliff_falls: int = _count_cliff_falls(pushes)
	var bump_action_payload: Dictionary = _build_action_payload_base(attacker, INTENT_ACTION_SKILL)
	bump_action_payload["target_id"] = str(defender.name)
	bump_action_payload["target_cell"] = defender.grid_cell
	bump_action_payload["push_count"] = pushes.size()
	bump_action_payload["direction"] = direction
	bump_action_payload["cliff_falls"] = cliff_falls
	bump_action_payload["knockout"] = cliff_falls > 0
	bump_action_payload["knockout_count"] = cliff_falls
	bump_action_payload["knocked_out_ids"] = _collect_cliff_fall_puff_names(pushes)
	bump_action_payload["changed_outcome"] = cliff_falls > 0 or pushes.size() > 1
	if str(bump_action_payload.get("skill_id", "")).is_empty():
		bump_action_payload["skill_id"] = "core_bump"

	_is_action_locked = true
	_is_resolving_bump = true
	call_deferred("_run_bump_resolution", pushes, direction, bump_action_payload)
	return true


func _run_bump_resolution(pushes: Array, direction: Vector2i, action_payload: Dictionary = {}) -> void:
	await _animate_bump_pushes(pushes, direction)
	_apply_bump_pushes(pushes, direction)
	if not action_payload.is_empty():
		_emit_action_resolved(action_payload)
	_is_resolving_bump = false
	_is_action_locked = false
	_finish_current_action()


func _animate_bump_pushes(pushes: Array, direction: Vector2i) -> void:
	var active_tweens: Array[Tween] = []

	for push_variant in pushes:
		if not (push_variant is Dictionary):
			continue
		var push: Dictionary = push_variant
		var puff_variant: Variant = push.get("puff")
		if not (puff_variant is Puff):
			continue
		var puff: Puff = puff_variant
		if not is_instance_valid(puff):
			continue

		var from_cell: Vector2i = push.get("from_cell", puff.grid_cell)
		var fell_from_cliff: bool = bool(push.get("fell_from_cliff", false))
		if fell_from_cliff:
			var from_world: Vector2 = _cell_to_world(from_cell)
			var step_world: Vector2 = _cell_to_world(from_cell + direction) - from_world
			var fall_target: Vector2 = from_world + step_world + BUMP_FALL_DROP_OFFSET
			var fall_tween: Tween = _puff_animator.play_defeat_deflate_fade(puff, BUMP_FALL_DURATION)
			if fall_tween != null:
				fall_tween.parallel().tween_property(puff, "global_position", fall_target, BUMP_FALL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				active_tweens.append(fall_tween)
			continue

		var to_cell: Vector2i = push.get("to_cell", from_cell)
		var from_world_move: Vector2 = _cell_to_world(from_cell)
		var target_world: Vector2 = _cell_to_world(to_cell)
		var push_tween: Tween = _puff_animator.play_bump_stretch_bounce(
			puff,
			from_world_move,
			target_world,
			direction,
			BUMP_PUSH_DURATION
		)
		if push_tween != null:
			active_tweens.append(push_tween)

	for tween in active_tweens:
		if tween != null and is_instance_valid(tween):
			await tween.finished


func _apply_bump_pushes(pushes: Array, direction: Vector2i) -> void:
	for push_variant in pushes:
		if not (push_variant is Dictionary):
			continue
		var push: Dictionary = push_variant
		var puff_variant: Variant = push.get("puff")
		if not (puff_variant is Puff):
			continue
		var puff: Puff = puff_variant
		if not is_instance_valid(puff):
			continue

		var puff_name: StringName = StringName(puff.name)
		var from_cell: Vector2i = push.get("from_cell", puff.grid_cell)
		var fell_from_cliff: bool = bool(push.get("fell_from_cliff", false))
		_emit_signal_bus("puff_bumped", [puff_name, direction])

		if fell_from_cliff:
			_apply_cliff_stun(puff, from_cell)
			continue

		var to_cell: Vector2i = push.get("to_cell", from_cell)
		puff.modulate.a = 1.0
		puff.set_grid_cell(to_cell)
		_emit_signal_bus("puff_moved", [puff_name, from_cell, to_cell])


func _finish_current_action() -> void:
	_is_action_locked = false
	if not _set_phase(PHASE_RESOLVE):
		return
	_resolve_phase()


func _skip_player_turn_without_actions() -> void:
	if _active_side() != TEAM_PLAYER:
		return
	if current_phase != PHASE_PLAYER_SELECT:
		return
	if not _get_actionable_team_puffs(TEAM_PLAYER).is_empty():
		return
	if _set_phase(PHASE_PLAYER_ACTION):
		_finish_current_action()


func _resolve_phase() -> void:
	if _check_for_battle_end():
		return

	_emit_signal_bus("turn_ended", [turn_number])
	if _battle_has_ended:
		return

	if _active_side() == TEAM_PLAYER:
		_begin_enemy_turn()
		return

	turn_number += 1
	_begin_player_turn()


func _check_for_battle_end() -> bool:
	if _battle_has_ended:
		return true

	var player_alive: bool = _has_alive_members(TEAM_PLAYER)
	var enemy_alive: bool = _has_alive_members(TEAM_ENEMY)

	if player_alive and enemy_alive:
		return false

	var winner: StringName = TEAM_PLAYER if player_alive else TEAM_ENEMY
	end_battle(winner)
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
	if not _is_puff_actionable(_selected_puff):
		return false
	if not _is_cell_in_bounds(target_cell):
		return false
	if target_cell == _selected_puff.grid_cell:
		return false
	return _reachable_cells.has(target_cell)


func _can_bump(attacker: Puff, defender: Puff) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker == defender:
		return false
	if not _is_puff_actionable(attacker) or not _is_puff_actionable(defender):
		return false
	return _bump_system.can_bump(attacker.grid_cell, defender.grid_cell)


func _can_attack(attacker: Puff, defender: Puff) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker == defender:
		return false
	if not _is_puff_actionable(attacker) or not _is_puff_actionable(defender):
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


func _build_shortest_path(origin: Vector2i, target: Vector2i, moving_puff: Puff) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if origin == target:
		path.append(origin)
		return path
	if not _is_cell_in_bounds(origin) or not _is_cell_in_bounds(target):
		path.append(origin)
		path.append(target)
		return path

	var frontier: Array[Vector2i] = [origin]
	var came_from: Dictionary = {}
	var visited: Dictionary = {origin: true}

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == target:
			break

		for offset in CARDINAL_OFFSETS:
			var candidate: Vector2i = current + offset
			if not _is_cell_in_bounds(candidate):
				continue
			if visited.has(candidate):
				continue
			if candidate != target and _is_cell_occupied(candidate, moving_puff):
				continue

			visited[candidate] = true
			came_from[candidate] = current
			frontier.push_back(candidate)

	if not visited.has(target):
		path.append(origin)
		path.append(target)
		return path

	var cursor: Vector2i = target
	path.append(cursor)
	while cursor != origin:
		var previous_cell_variant: Variant = came_from.get(cursor, origin)
		if previous_cell_variant is Vector2i:
			cursor = previous_cell_variant
		else:
			cursor = origin
		path.append(cursor)
	path.reverse()
	return path


func _build_world_path(cell_path: Array[Vector2i]) -> Array[Vector2]:
	var world_path: Array[Vector2] = []
	for cell in cell_path:
		world_path.append(_cell_to_world(cell))
	return world_path


func _build_enemy_intent(enemy_actor: Puff) -> Dictionary:
	var wait_intent: Dictionary = _build_wait_intent(enemy_actor)
	if enemy_actor == null or not _is_puff_actionable(enemy_actor):
		return wait_intent

	var candidate_intents: Array[Dictionary] = _build_enemy_candidate_intents(enemy_actor)
	if candidate_intents.is_empty():
		return wait_intent

	var ai_context: Dictionary = _build_utility_ai_context()
	var selected_intent: Dictionary = _utility_ai.pick_best_intent(enemy_actor, candidate_intents, ai_context)
	if selected_intent.is_empty():
		return wait_intent
	return selected_intent


func _build_enemy_candidate_intents(enemy_actor: Puff) -> Array[Dictionary]:
	var candidate_intents: Array[Dictionary] = []
	var wait_intent: Dictionary = _build_wait_intent(enemy_actor)
	candidate_intents.append(wait_intent)

	if enemy_actor == null or not _is_puff_actionable(enemy_actor):
		return candidate_intents

	var player_targets: Array[Puff] = _get_actionable_team_puffs(TEAM_PLAYER)
	if player_targets.is_empty():
		return candidate_intents

	var move_range: int = _resolve_move_range(enemy_actor)
	var reachable_cells: Array[Vector2i] = _compute_reachable_cells(enemy_actor.grid_cell, move_range, enemy_actor)
	for reachable_cell in reachable_cells:
		if reachable_cell == enemy_actor.grid_cell:
			continue
		var move_intent: Dictionary = wait_intent.duplicate(true)
		move_intent["action"] = INTENT_ACTION_MOVE
		move_intent["move_cell"] = reachable_cell
		candidate_intents.append(move_intent)

	for player_target in player_targets:
		if _can_attack(enemy_actor, player_target):
			var attack_intent: Dictionary = wait_intent.duplicate(true)
			attack_intent["action"] = INTENT_ACTION_ATTACK
			attack_intent["target_puff_id"] = player_target.get_instance_id()
			attack_intent["target_cell"] = player_target.grid_cell
			candidate_intents.append(attack_intent)

		if not _can_bump(enemy_actor, player_target):
			continue

		var bump_preview: Dictionary = _build_bump_preview(enemy_actor, player_target)
		if not bool(bump_preview.get("valid", false)):
			continue

		var pushes: Array = bump_preview.get("pushes", [])
		if pushes.is_empty():
			continue

		var skill_intent: Dictionary = wait_intent.duplicate(true)
		skill_intent["action"] = INTENT_ACTION_SKILL
		skill_intent["target_puff_id"] = player_target.get_instance_id()
		skill_intent["target_cell"] = player_target.grid_cell
		skill_intent["skill_cells"] = _collect_bump_preview_cells(bump_preview)
		skill_intent["direction"] = bump_preview.get("direction", Vector2i.ZERO)
		skill_intent["bump_push_count"] = pushes.size()
		skill_intent["bump_cliff_falls"] = _count_cliff_falls(pushes)
		candidate_intents.append(skill_intent)

	return candidate_intents


func _build_bump_preview(attacker: Puff, defender: Puff) -> Dictionary:
	return _bump_system.resolve_bump(
		attacker,
		defender,
		Callable(self, "_get_actionable_puff_at_cell"),
		Callable(self, "_is_cell_in_bounds"),
		Callable(self, "_is_cliff_cell")
	)


func _count_cliff_falls(pushes: Array) -> int:
	var cliff_falls: int = 0
	for push_variant in pushes:
		if not (push_variant is Dictionary):
			continue
		var push: Dictionary = push_variant
		if bool(push.get("fell_from_cliff", false)):
			cliff_falls += 1
	return cliff_falls


func _collect_cliff_fall_puff_names(pushes: Array) -> Array[String]:
	var puff_names: Array[String] = []
	for push_variant in pushes:
		if not (push_variant is Dictionary):
			continue
		var push: Dictionary = push_variant
		if not bool(push.get("fell_from_cliff", false)):
			continue

		var puff_variant: Variant = push.get("puff")
		if not (puff_variant is Puff):
			continue
		var puff: Puff = puff_variant
		if not is_instance_valid(puff):
			continue
		puff_names.append(str(puff.name))

	return puff_names


func _build_utility_ai_context() -> Dictionary:
	return {
		"player_targets": _get_actionable_team_puffs(TEAM_PLAYER),
		"lookup_puff_by_id": Callable(self, "_lookup_actionable_puff_by_id"),
		"grid_distance": Callable(self, "_grid_distance"),
		"resolve_damage": Callable(self, "_calculate_damage"),
		"resolve_current_hp": Callable(self, "_resolve_current_hp"),
		"resolve_attack_range": Callable(self, "_resolve_attack_range"),
		"resolve_terrain_effect_at": Callable(self, "_resolve_terrain_effect_at"),
		"is_cliff_cell": Callable(self, "_is_cliff_cell")
	}


func _build_wait_intent(actor: Puff) -> Dictionary:
	var actor_id: int = -1
	var actor_name: StringName = &""
	var actor_cell: Vector2i = Vector2i.ZERO
	if actor != null:
		actor_id = actor.get_instance_id()
		actor_name = StringName(actor.name)
		actor_cell = actor.grid_cell

	return {
		"actor_id": actor_id,
		"actor_name": actor_name,
		"actor_cell": actor_cell,
		"action": INTENT_ACTION_WAIT,
		"move_cell": actor_cell,
		"target_cell": actor_cell,
		"target_puff_id": -1,
		"skill_cells": [],
		"direction": Vector2i.ZERO
	}


func _collect_bump_preview_cells(bump_preview: Dictionary) -> Array[Vector2i]:
	var preview_cells: Array[Vector2i] = []
	if not bool(bump_preview.get("valid", false)):
		return preview_cells

	var pushes: Array = bump_preview.get("pushes", [])
	for push_variant in pushes:
		if not (push_variant is Dictionary):
			continue
		var push: Dictionary = push_variant
		var from_cell: Vector2i = push.get("from_cell", Vector2i.ZERO)
		if _is_cell_in_bounds(from_cell) and not preview_cells.has(from_cell):
			preview_cells.append(from_cell)

		var fell_from_cliff: bool = bool(push.get("fell_from_cliff", false))
		if fell_from_cliff:
			continue

		var to_cell: Vector2i = push.get("to_cell", from_cell)
		if _is_cell_in_bounds(to_cell) and not preview_cells.has(to_cell):
			preview_cells.append(to_cell)

	return preview_cells


func _resolve_intent_target_puff(intent: Dictionary) -> Puff:
	var target_id: int = int(intent.get("target_puff_id", -1))
	return _lookup_actionable_puff_by_id(target_id)


func _lookup_actionable_puff_by_id(puff_id: int) -> Puff:
	if puff_id < 0:
		return null

	var target_variant: Variant = _puffs_by_id.get(puff_id)
	if not (target_variant is Puff):
		return null

	var target_puff: Puff = target_variant
	if not _is_puff_actionable(target_puff):
		return null

	return target_puff


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
	if puff_data.has_method("get_effective_attack"):
		return maxi(1, int(puff_data.call("get_effective_attack")))
	return maxi(1, puff_data.attack)


func _resolve_defense_stat(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 0
	if puff_data.has_method("get_effective_defense"):
		return maxi(0, int(puff_data.call("get_effective_defense")))
	return maxi(0, puff_data.defense)


func _resolve_move_range(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	if puff_data.has_method("get_effective_move_range"):
		return maxi(1, int(puff_data.call("get_effective_move_range")))
	return maxi(1, puff_data.move_range)


func _resolve_attack_range(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	if puff_data.has_method("get_effective_attack_range"):
		return maxi(1, int(puff_data.call("get_effective_attack_range")))
	return maxi(1, puff_data.attack_range)


func _resolve_max_hp(puff: Puff) -> int:
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return 1
	if puff_data.has_method("get_effective_hp"):
		return maxi(1, int(puff_data.call("get_effective_hp")))
	return maxi(1, puff_data.hp)


func _resolve_current_hp(puff: Puff) -> int:
	var puff_id: int = puff.get_instance_id()
	if not _hp_by_puff_id.has(puff_id):
		_hp_by_puff_id[puff_id] = _resolve_max_hp(puff)
	return int(_hp_by_puff_id[puff_id])


func _compute_team_total_hp(team: StringName) -> int:
	var total_hp: int = 0
	for puff in _get_alive_team_puffs(team):
		total_hp += maxi(0, _resolve_current_hp(puff))
	return maxi(0, total_hp)


func _resolve_unique_skill_id(puff: Puff) -> String:
	if puff == null:
		return ""
	var puff_data: PuffData = puff.puff_data as PuffData
	if puff_data == null:
		return ""
	return str(puff_data.unique_skill_id)


func _build_action_payload_base(actor: Puff, action: StringName) -> Dictionary:
	var actor_team: StringName = _active_side()
	var actor_name: String = ""
	var actor_cell: Vector2i = Vector2i.ZERO
	var skill_id: String = ""

	if actor != null:
		actor_name = str(actor.name)
		actor_cell = actor.grid_cell
		var mapped_team: StringName = get_puff_team(actor)
		if mapped_team == TEAM_PLAYER or mapped_team == TEAM_ENEMY:
			actor_team = mapped_team
		skill_id = _resolve_unique_skill_id(actor)

	return {
		"turn_number": turn_number,
		"phase": str(current_phase),
		"action": str(action),
		"actor_id": actor_name,
		"actor_team": str(actor_team),
		"actor_cell_before": actor_cell,
		"actor_cell_after": actor_cell,
		"target_id": "",
		"target_cell": actor_cell,
		"damage": 0,
		"target_hp_before": 0,
		"target_hp_after": 0,
		"hp_swing": 0,
		"hp_swing_ratio": 0.0,
		"knockout": false,
		"knockout_count": 0,
		"cliff_falls": 0,
		"skill_id": skill_id,
		"changed_outcome": false
	}


func _emit_action_resolved(action_payload: Dictionary) -> void:
	if action_payload.is_empty():
		return

	var payload: Dictionary = action_payload.duplicate(true)
	var side: StringName = StringName(str(payload.get("actor_team", str(_active_side()))))
	if side != TEAM_PLAYER and side != TEAM_ENEMY:
		side = _active_side()
		payload["actor_team"] = str(side)

	emit_signal("action_resolved", side, payload)


func _resolve_tile_map_layer() -> TileMapLayer:
	if _battle_map == null:
		return null
	return _battle_map.get_node_or_null("TileMapLayer")


func _resolve_tile_size(tile_map_layer: TileMapLayer) -> Vector2:
	if tile_map_layer == null or tile_map_layer.tile_set == null:
		return DEFAULT_TILE_SIZE
	return Vector2(tile_map_layer.tile_set.tile_size)


func _cell_to_world(cell: Vector2i) -> Vector2:
	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return Vector2.ZERO
	var cell_local: Vector2 = tile_map_layer.map_to_local(cell)
	return tile_map_layer.to_global(cell_local)


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	if _battle_map == null:
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < _battle_map.map_size.x and cell.y < _battle_map.map_size.y


func _is_cliff_cell(cell: Vector2i) -> bool:
	if _battle_map == null:
		return false
	return _battle_map.get_terrain_at(cell) == "cliff"


func _resolve_terrain_effect_at(cell: Vector2i) -> Dictionary:
	if _battle_map == null:
		return {}
	if not _is_cell_in_bounds(cell):
		return {}
	return _battle_map.get_terrain_effect_at(cell)


func _is_cell_occupied(cell: Vector2i, ignored_puff: Puff = null) -> bool:
	for puff_variant in _puffs_by_id.values():
		var puff: Puff = puff_variant
		if puff == null or not is_instance_valid(puff):
			continue
		if puff == ignored_puff:
			continue
		if _is_puff_stunned(puff):
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


func _get_actionable_team_puffs(team: StringName) -> Array[Puff]:
	var team_puffs: Array[Puff] = []
	for puff in _get_alive_team_puffs(team):
		if _is_puff_actionable(puff):
			team_puffs.append(puff)
	return team_puffs


func _get_actionable_puff_at_cell(cell: Vector2i) -> Puff:
	for puff_variant in _puffs_by_id.values():
		var puff: Puff = puff_variant
		if puff == null or not is_instance_valid(puff):
			continue
		if not _is_puff_actionable(puff):
			continue
		if puff.grid_cell == cell:
			return puff
	return null


func _is_puff_actionable(puff: Puff) -> bool:
	if puff == null or not is_instance_valid(puff):
		return false
	return not _is_puff_stunned(puff)


func _is_puff_stunned(puff: Puff) -> bool:
	if puff == null:
		return false
	return _stun_state_by_puff_id.has(puff.get_instance_id())


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _active_side() -> StringName:
	if active_side_index < 0 or active_side_index >= turn_order.size():
		return TEAM_PLAYER
	return turn_order[active_side_index]


func _increment_team_turn(team: StringName) -> void:
	var current_index: int = int(_team_turn_index.get(team, 0))
	_team_turn_index[team] = current_index + 1


func _apply_cliff_stun(puff: Puff, return_cell: Vector2i) -> void:
	if puff == null or not is_instance_valid(puff):
		return
	var puff_id: int = puff.get_instance_id()
	var team: StringName = _team_by_puff_id.get(puff_id, &"")
	if team != TEAM_PLAYER and team != TEAM_ENEMY:
		return

	var current_team_turn: int = int(_team_turn_index.get(team, 0))
	_stun_state_by_puff_id[puff_id] = {
		"team": team,
		"recover_on_team_turn": current_team_turn + 2,
		"return_cell": return_cell
	}

	puff.monitoring = false
	puff.monitorable = false
	puff.visible = false
	puff.modulate.a = 1.0
	puff.set_grid_cell(return_cell)


func _recover_stunned_puffs_for_team(team: StringName) -> void:
	var current_team_turn: int = int(_team_turn_index.get(team, 0))
	var recovered_ids: Array[int] = []

	for puff_id_variant in _stun_state_by_puff_id.keys():
		var puff_id: int = int(puff_id_variant)
		var stun_state: Dictionary = _stun_state_by_puff_id[puff_id]
		if stun_state.get("team", &"") != team:
			continue

		var recover_on_turn: int = int(stun_state.get("recover_on_team_turn", current_team_turn))
		if current_team_turn < recover_on_turn:
			continue

		var puff_variant: Variant = _puffs_by_id.get(puff_id)
		if not (puff_variant is Puff):
			recovered_ids.append(puff_id)
			continue

		var puff: Puff = puff_variant
		if not is_instance_valid(puff):
			recovered_ids.append(puff_id)
			continue

		var return_cell: Vector2i = stun_state.get("return_cell", puff.grid_cell)
		puff.set_grid_cell(_find_reentry_cell(return_cell, puff))
		puff.monitoring = true
		puff.monitorable = true
		puff.visible = true
		puff.modulate.a = 1.0
		puff.scale = Vector2.ONE
		_puff_animator.play_heal_glow_float(puff)
		recovered_ids.append(puff_id)

	for recovered_id in recovered_ids:
		_stun_state_by_puff_id.erase(recovered_id)


func _find_reentry_cell(preferred_cell: Vector2i, reentering_puff: Puff) -> Vector2i:
	if _is_cell_in_bounds(preferred_cell) and not _is_cell_occupied(preferred_cell, reentering_puff):
		return preferred_cell

	var queue: Array[Vector2i] = [preferred_cell]
	var visited: Dictionary = {preferred_cell: true}

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for offset in CARDINAL_OFFSETS:
			var candidate: Vector2i = cell + offset
			if visited.has(candidate):
				continue
			if not _is_cell_in_bounds(candidate):
				continue

			visited[candidate] = true
			if not _is_cell_occupied(candidate, reentering_puff):
				return candidate
			queue.append(candidate)

	if _is_cell_in_bounds(preferred_cell):
		return preferred_cell
	return Vector2i.ZERO


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
	_stun_state_by_puff_id.erase(puff_id)


func _emit_signal_bus(signal_name: StringName, args: Array = []) -> void:
	var signal_bus: Node = get_node_or_null("/root/SignalBus")
	if signal_bus == null:
		return
	var emit_args: Array = [signal_name]
	emit_args.append_array(args)
	signal_bus.callv("emit_signal", emit_args)


func _sync_utility_ai_weights() -> void:
	if _utility_ai == null:
		return
	_utility_ai.set_weights(
		ai_attack_value_weight,
		ai_survival_risk_weight,
		ai_positional_advantage_weight,
		ai_bump_opportunity_weight
	)


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
