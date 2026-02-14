extends RefCounted
class_name PuzzleGenerator

const TEMPLATE_BUMP_TO_CLIFF_KILL: StringName = &"bump-to-cliff-kill"
const TEMPLATE_DEFEAT_N_IN_1_TURN: StringName = &"defeat-n-in-1-turn"
const TEMPLATE_HEAL_ALL_ALLIES: StringName = &"heal-all-allies"
const TEMPLATE_MINIMUM_MOVES: StringName = &"minimum-moves"

const SUPPORTED_TEMPLATES: Array[StringName] = [
	TEMPLATE_BUMP_TO_CLIFF_KILL,
	TEMPLATE_DEFEAT_N_IN_1_TURN,
	TEMPLATE_HEAL_ALL_ALLIES,
	TEMPLATE_MINIMUM_MOVES
]

const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

const ACTION_MOVE: StringName = &"move"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_BUMP: StringName = &"bump"
const ACTION_HEAL: StringName = &"heal"

const MAP_WIDTH: int = Constants.GRID_WIDTH
const MAP_HEIGHT: int = Constants.GRID_HEIGHT

const MIN_DIFFICULTY: int = 1
const MAX_DIFFICULTY: int = 10
const MAX_GENERATION_ATTEMPTS: int = 24

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT
]

const PUFF_PATH_CLOUD: String = "res://src/resources/puffs/base/cloud_tank.tres"
const PUFF_PATH_FLAME: String = "res://src/resources/puffs/base/flame_melee.tres"
const PUFF_PATH_DROPLET: String = "res://src/resources/puffs/base/droplet_ranged.tres"
const PUFF_PATH_LEAF: String = "res://src/resources/puffs/base/leaf_healer.tres"
const PUFF_PATH_WHIRL: String = "res://src/resources/puffs/base/whirl_mobility.tres"
const PUFF_PATH_STAR: String = "res://src/resources/puffs/base/star_wildcard.tres"

const PUFF_DATA_SCRIPT: GDScript = preload("res://src/scripts/puffs/puff_data.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stats_cache_by_data_path: Dictionary = {}


func get_supported_templates() -> Array[StringName]:
	return SUPPORTED_TEMPLATES.duplicate()


func generate_random_puzzle(difficulty: int = MIN_DIFFICULTY, seed: int = -1) -> Dictionary:
	_configure_rng(seed)
	var template_index: int = _rng.randi_range(0, SUPPORTED_TEMPLATES.size() - 1)
	var template_id: StringName = SUPPORTED_TEMPLATES[template_index]
	return generate_puzzle(template_id, difficulty, int(_rng.seed))


func generate_puzzle(template_id: StringName, difficulty: int = MIN_DIFFICULTY, seed: int = -1) -> Dictionary:
	var normalized_template: StringName = _normalize_template_id(template_id)
	if normalized_template == &"":
		return {}

	_configure_rng(seed)
	var clamped_difficulty: int = clampi(difficulty, MIN_DIFFICULTY, MAX_DIFFICULTY)
	var stable_seed: int = int(_rng.seed)

	for _attempt_index in MAX_GENERATION_ATTEMPTS:
		var puzzle_candidate: Dictionary = _build_template_candidate(normalized_template, clamped_difficulty)
		if puzzle_candidate.is_empty():
			return {}

		var validation_result: Dictionary = validate_generated_puzzle(puzzle_candidate)
		if not bool(validation_result.get("solvable", false)):
			continue

		return _build_feed_snapshot(
			puzzle_candidate,
			validation_result,
			normalized_template,
			clamped_difficulty,
			stable_seed
		)

	return {}


func validate_generated_puzzle(puzzle_candidate: Dictionary) -> Dictionary:
	if puzzle_candidate.is_empty():
		return {"solvable": false, "reason": "empty_candidate"}

	var objective_variant: Variant = puzzle_candidate.get("objective", {})
	if not (objective_variant is Dictionary):
		return {"solvable": false, "reason": "missing_objective"}
	var objective: Dictionary = objective_variant

	var simulation_state: Dictionary = _build_simulation_state(puzzle_candidate)
	var candidate_actions: Array[Dictionary] = _enumerate_player_actions(simulation_state, objective)
	for action in candidate_actions:
		var simulation_result: Dictionary = _simulate_action(simulation_state, action, objective)
		if bool(simulation_result.get("objective_complete", false)):
			return {
				"solvable": true,
				"reason": "",
				"solution": action.duplicate(true),
				"metrics": {
					"defeated_enemies": int(simulation_result.get("defeated_enemies", 0)),
					"cliff_falls": int(simulation_result.get("cliff_falls", 0)),
					"healed_points": int(simulation_result.get("healed_points", 0)),
					"moved_steps": int(simulation_result.get("moved_steps", 0))
				}
			}

	return {
		"solvable": false,
		"reason": "no_winning_action",
		"attempted_action_count": candidate_actions.size()
	}


func _build_template_candidate(template_id: StringName, difficulty: int) -> Dictionary:
	match template_id:
		TEMPLATE_BUMP_TO_CLIFF_KILL:
			return _build_bump_to_cliff_kill_candidate(difficulty)
		TEMPLATE_DEFEAT_N_IN_1_TURN:
			return _build_defeat_n_in_one_turn_candidate(difficulty)
		TEMPLATE_HEAL_ALL_ALLIES:
			return _build_heal_all_allies_candidate(difficulty)
		TEMPLATE_MINIMUM_MOVES:
			return _build_minimum_moves_candidate(difficulty)
		_:
			return {}


func _build_bump_to_cliff_kill_candidate(difficulty: int) -> Dictionary:
	var rows: Array = _build_cloud_rows(MAP_WIDTH, MAP_HEIGHT)
	var lane_y: int = _rng.randi_range(1, MAP_HEIGHT - 2)
	var required_cliff_falls: int = clampi(1 + int((difficulty - 1) / 5), 1, 2)
	var attacker_x: int = _rng.randi_range(0, MAP_WIDTH - required_cliff_falls - 2)

	var attacker_cell: Vector2i = Vector2i(attacker_x, lane_y)
	var enemy_cells: Array[Vector2i] = []
	for enemy_offset in required_cliff_falls:
		var enemy_cell: Vector2i = Vector2i(attacker_x + enemy_offset + 1, lane_y)
		enemy_cells.append(enemy_cell)
		_set_terrain(rows, enemy_cell, "cliff")

	var units: Array[Dictionary] = []
	units.append(_make_unit("player_0", "Flame_Bumper", TEAM_PLAYER, PUFF_PATH_FLAME, attacker_cell))
	for enemy_index in enemy_cells.size():
		var enemy_data_path: String = PUFF_PATH_CLOUD if enemy_index == 0 else PUFF_PATH_DROPLET
		units.append(
			_make_unit(
				"enemy_%d" % enemy_index,
				"Cliff_Target_%d" % enemy_index,
				TEAM_ENEMY,
				enemy_data_path,
				enemy_cells[enemy_index]
			)
		)

	if difficulty >= 7:
		var trailing_cell: Vector2i = Vector2i(attacker_x + required_cliff_falls + 1, lane_y)
		if _is_cell_in_bounds(trailing_cell, Vector2i(MAP_WIDTH, MAP_HEIGHT)):
			units.append(_make_unit("enemy_trailing", "Trailing_Blocker", TEAM_ENEMY, PUFF_PATH_CLOUD, trailing_cell))
			_set_terrain(rows, trailing_cell, "high_cloud")

	_paint_random_terrain(rows, ["high_cloud", "puddle", "mushroom"], 1 + int(difficulty / 3), units)

	return {
		"map_config": {"width": MAP_WIDTH, "height": MAP_HEIGHT, "rows": rows},
		"units": units,
		"objective": {
			"type": TEMPLATE_BUMP_TO_CLIFF_KILL,
			"required_cliff_falls": required_cliff_falls,
			"actor_id": "player_0"
		},
		"target_score": 220 + difficulty * 16
	}


func _build_defeat_n_in_one_turn_candidate(difficulty: int) -> Dictionary:
	var rows: Array = _build_cloud_rows(MAP_WIDTH, MAP_HEIGHT)
	var lane_y: int = _rng.randi_range(1, MAP_HEIGHT - 2)
	var required_defeats: int = clampi(1 + int((difficulty - 1) / 3), 1, 3)
	var attacker_x: int = maxi(0, MAP_WIDTH - required_defeats - 2)

	var attacker_cell: Vector2i = Vector2i(attacker_x, lane_y)
	var units: Array[Dictionary] = []
	units.append(_make_unit("player_0", "Whirl_Closer", TEAM_PLAYER, PUFF_PATH_WHIRL, attacker_cell))

	for enemy_offset in required_defeats:
		var enemy_cell: Vector2i = Vector2i(attacker_x + enemy_offset + 1, lane_y)
		_set_terrain(rows, enemy_cell, "cliff")
		units.append(
			_make_unit(
				"enemy_%d" % enemy_offset,
				"Defeat_Target_%d" % enemy_offset,
				TEAM_ENEMY,
				PUFF_PATH_CLOUD,
				enemy_cell
			)
		)

	if difficulty >= 8:
		var reserve_cell: Vector2i = Vector2i(MAP_WIDTH - 1, 0)
		if _cell_is_free_for_spawn(reserve_cell, units):
			units.append(_make_unit("enemy_reserve", "Reserve_Enemy", TEAM_ENEMY, PUFF_PATH_DROPLET, reserve_cell))

	_paint_random_terrain(rows, ["high_cloud", "cotton_candy", "puddle"], 2 + int(difficulty / 2), units)

	return {
		"map_config": {"width": MAP_WIDTH, "height": MAP_HEIGHT, "rows": rows},
		"units": units,
		"objective": {
			"type": TEMPLATE_DEFEAT_N_IN_1_TURN,
			"required_defeats": required_defeats
		},
		"target_score": 240 + difficulty * 18
	}


func _build_heal_all_allies_candidate(difficulty: int) -> Dictionary:
	var rows: Array = _build_cloud_rows(MAP_WIDTH, MAP_HEIGHT)
	var healer_cell: Vector2i = Vector2i(2, 2)
	var heal_range: int = 2
	var heal_amount: int = 4 + int(difficulty / 2)
	var wounded_ally_count: int = clampi(2 + int((difficulty - 1) / 4), 2, 3)

	var units: Array[Dictionary] = []
	units.append(_make_unit("player_healer", "Leaf_Healer", TEAM_PLAYER, PUFF_PATH_LEAF, healer_cell))

	var ally_positions: Array[Vector2i] = [
		Vector2i(1, 2),
		Vector2i(2, 1),
		Vector2i(3, 2),
		Vector2i(2, 3),
		Vector2i(1, 1),
		Vector2i(3, 3),
		Vector2i(1, 3),
		Vector2i(3, 1)
	]
	var selected_positions: Array[Vector2i] = _pick_unique_cells(ally_positions, wounded_ally_count)
	var ally_data_paths: Array[String] = [PUFF_PATH_FLAME, PUFF_PATH_CLOUD, PUFF_PATH_DROPLET, PUFF_PATH_STAR]

	for ally_index in selected_positions.size():
		var ally_cell: Vector2i = selected_positions[ally_index]
		var ally_data_path: String = ally_data_paths[ally_index % ally_data_paths.size()]
		var ally_stats: Dictionary = _get_puff_stats(ally_data_path)
		var max_hp: int = int(ally_stats.get("max_hp", 10))
		var missing_hp: int = clampi(2 + int(difficulty / 2), 1, max_hp - 1)
		missing_hp = mini(missing_hp, heal_amount)
		var ally_hp: int = maxi(1, max_hp - missing_hp)

		units.append(
			_make_unit(
				"player_ally_%d" % ally_index,
				"Wounded_Ally_%d" % ally_index,
				TEAM_PLAYER,
				ally_data_path,
				ally_cell,
				ally_hp
			)
		)
		_set_terrain(rows, ally_cell, "mushroom")

	var enemy_anchor_cell: Vector2i = Vector2i(4, 0)
	if _cell_is_free_for_spawn(enemy_anchor_cell, units):
		units.append(_make_unit("enemy_anchor", "Enemy_Anchor", TEAM_ENEMY, PUFF_PATH_CLOUD, enemy_anchor_cell))

	_paint_random_terrain(rows, ["high_cloud", "puddle"], 1 + int(difficulty / 3), units)

	return {
		"map_config": {"width": MAP_WIDTH, "height": MAP_HEIGHT, "rows": rows},
		"units": units,
		"objective": {
			"type": TEMPLATE_HEAL_ALL_ALLIES,
			"heal_actor_id": "player_healer",
			"heal_range": heal_range,
			"heal_amount": heal_amount,
			"require_all_allies_full": true
		},
		"target_score": 190 + difficulty * 12
	}


func _build_minimum_moves_candidate(difficulty: int) -> Dictionary:
	var rows: Array = _build_cloud_rows(MAP_WIDTH, MAP_HEIGHT)
	var lane_y: int = _rng.randi_range(1, MAP_HEIGHT - 2)
	var minimum_moves: int = clampi(2 + int((difficulty - 1) / 3), 2, 4)

	var start_cell: Vector2i = Vector2i(0, lane_y)
	var goal_cell: Vector2i = Vector2i(minimum_moves, lane_y)

	var units: Array[Dictionary] = []
	units.append(_make_unit("player_runner", "Whirl_Runner", TEAM_PLAYER, PUFF_PATH_WHIRL, start_cell))

	var observer_cell: Vector2i = Vector2i(4, clampi(lane_y - 1, 0, MAP_HEIGHT - 1))
	if _cell_is_free_for_spawn(observer_cell, units):
		units.append(_make_unit("enemy_observer", "Enemy_Observer", TEAM_ENEMY, PUFF_PATH_DROPLET, observer_cell))

	if difficulty >= 6:
		var block_cells: Array[Vector2i] = [
			Vector2i(2, clampi(lane_y - 1, 0, MAP_HEIGHT - 1)),
			Vector2i(2, clampi(lane_y + 1, 0, MAP_HEIGHT - 1))
		]
		for block_index in block_cells.size():
			var block_cell: Vector2i = block_cells[block_index]
			if _cell_is_free_for_spawn(block_cell, units) and block_cell != goal_cell:
				units.append(
					_make_unit(
						"enemy_block_%d" % block_index,
						"Path_Blocker_%d" % block_index,
						TEAM_ENEMY,
						PUFF_PATH_CLOUD,
						block_cell
					)
				)

	_set_terrain(rows, goal_cell, "high_cloud")
	_paint_random_terrain(rows, ["puddle", "cotton_candy", "mushroom"], 1 + int(difficulty / 3), units)

	return {
		"map_config": {"width": MAP_WIDTH, "height": MAP_HEIGHT, "rows": rows},
		"units": units,
		"objective": {
			"type": TEMPLATE_MINIMUM_MOVES,
			"runner_id": "player_runner",
			"goal_cell": goal_cell,
			"minimum_moves": minimum_moves
		},
		"target_score": 200 + difficulty * 14
	}


func _build_feed_snapshot(
	puzzle_candidate: Dictionary,
	validation_result: Dictionary,
	template_id: StringName,
	difficulty: int,
	seed: int
) -> Dictionary:
	var units_variant: Variant = puzzle_candidate.get("units", [])
	var units: Array = units_variant if units_variant is Array else []
	var feed_puffs: Array = []

	for unit_variant in units:
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if bool(unit.get("removed", false)):
			continue

		feed_puffs.append(
			{
				"name": str(unit.get("name", unit.get("id", "puff"))),
				"team": str(unit.get("team", TEAM_ENEMY)),
				"data_path": str(unit.get("data_path", "")),
				"cell": unit.get("cell", Vector2i.ZERO),
				"hp": int(unit.get("hp", 1)),
				"max_hp": int(unit.get("max_hp", 1))
			}
		)

	var snapshot: Dictionary = {
		"map_config": puzzle_candidate.get("map_config", {}).duplicate(true),
		"puffs": feed_puffs,
		"enemy_intents": [],
		"target_score": int(puzzle_candidate.get("target_score", 220)),
		"puzzle_meta": {
			"template": template_id,
			"difficulty": difficulty,
			"seed": seed,
			"objective": puzzle_candidate.get("objective", {}).duplicate(true),
			"validation": {
				"solvable": true,
				"solution": validation_result.get("solution", {}).duplicate(true),
				"metrics": validation_result.get("metrics", {}).duplicate(true)
			}
		}
	}

	return _to_json_safe(snapshot)


func _build_simulation_state(puzzle_candidate: Dictionary) -> Dictionary:
	return {
		"map_config": puzzle_candidate.get("map_config", {}).duplicate(true),
		"objective": puzzle_candidate.get("objective", {}).duplicate(true),
		"units": puzzle_candidate.get("units", []).duplicate(true)
	}


func _enumerate_player_actions(state: Dictionary, objective: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var units_variant: Variant = state.get("units", [])
	if not (units_variant is Array):
		return actions

	var units: Array = units_variant
	for unit_variant in units:
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if not _is_active_team_member(unit, TEAM_PLAYER):
			continue

		var actor_id: String = str(unit.get("id", ""))
		var reachable_distances: Dictionary = _compute_reachable_cell_distances(state, unit)
		for cell_variant in reachable_distances.keys():
			var destination_cell: Vector2i = cell_variant
			var origin_cell: Vector2i = _as_cell(unit.get("cell", Vector2i.ZERO))
			if destination_cell == origin_cell:
				continue

			actions.append(
				{
					"type": ACTION_MOVE,
					"actor_id": actor_id,
					"to_cell": destination_cell,
					"path_steps": int(reachable_distances[destination_cell])
				}
			)

		for enemy_variant in units:
			if not (enemy_variant is Dictionary):
				continue
			var enemy: Dictionary = enemy_variant
			if not _is_active_team_member(enemy, TEAM_ENEMY):
				continue

			var enemy_id: String = str(enemy.get("id", ""))
			var actor_cell: Vector2i = _as_cell(unit.get("cell", Vector2i.ZERO))
			var enemy_cell: Vector2i = _as_cell(enemy.get("cell", Vector2i.ZERO))

			if _grid_distance(actor_cell, enemy_cell) <= int(unit.get("attack_range", 1)):
				actions.append(
					{
						"type": ACTION_ATTACK,
						"actor_id": actor_id,
						"target_id": enemy_id
					}
				)

			if _is_cardinal_offset(enemy_cell - actor_cell):
				actions.append(
					{
						"type": ACTION_BUMP,
						"actor_id": actor_id,
						"target_id": enemy_id
					}
				)

		if _can_unit_heal(unit, objective):
			actions.append(
				{
					"type": ACTION_HEAL,
					"actor_id": actor_id
				}
			)

	return actions


func _simulate_action(state: Dictionary, action: Dictionary, objective: Dictionary) -> Dictionary:
	var state_after_action: Dictionary = state.duplicate(true)
	var action_type: StringName = action.get("type", ACTION_MOVE)

	var simulation_result: Dictionary = {
		"valid": false,
		"defeated_enemies": 0,
		"cliff_falls": 0,
		"healed_points": 0,
		"moved_steps": 0,
		"state": state_after_action
	}

	match action_type:
		ACTION_MOVE:
			simulation_result["valid"] = _apply_move_action(state_after_action, action, simulation_result)
		ACTION_ATTACK:
			simulation_result["valid"] = _apply_attack_action(state_after_action, action, simulation_result)
		ACTION_BUMP:
			simulation_result["valid"] = _apply_bump_action(state_after_action, action, simulation_result)
		ACTION_HEAL:
			simulation_result["valid"] = _apply_heal_action(state_after_action, action, objective, simulation_result)
		_:
			simulation_result["valid"] = false

	if bool(simulation_result.get("valid", false)):
		simulation_result["all_allies_full"] = _are_all_player_units_full(state_after_action)
		simulation_result["objective_complete"] = _is_objective_complete(
			state_after_action,
			objective,
			action,
			simulation_result
		)
	else:
		simulation_result["all_allies_full"] = false
		simulation_result["objective_complete"] = false

	return simulation_result


func _apply_move_action(state: Dictionary, action: Dictionary, simulation_result: Dictionary) -> bool:
	var actor_id: String = str(action.get("actor_id", ""))
	var actor_index: int = _find_active_unit_index_by_id(state, actor_id)
	if actor_index == -1:
		return false

	var units: Array = state.get("units", [])
	var actor: Dictionary = units[actor_index]
	var destination_cell: Vector2i = _as_cell(action.get("to_cell", actor.get("cell", Vector2i.ZERO)))
	var reachable_distances: Dictionary = _compute_reachable_cell_distances(state, actor)

	if not reachable_distances.has(destination_cell):
		return false

	actor["cell"] = destination_cell
	units[actor_index] = actor
	state["units"] = units
	simulation_result["moved_steps"] = int(reachable_distances[destination_cell])
	return true


func _apply_attack_action(state: Dictionary, action: Dictionary, simulation_result: Dictionary) -> bool:
	var actor_id: String = str(action.get("actor_id", ""))
	var target_id: String = str(action.get("target_id", ""))
	var actor_index: int = _find_active_unit_index_by_id(state, actor_id)
	var target_index: int = _find_active_unit_index_by_id(state, target_id)
	if actor_index == -1 or target_index == -1:
		return false

	var units: Array = state.get("units", [])
	var actor: Dictionary = units[actor_index]
	var target: Dictionary = units[target_index]
	var actor_cell: Vector2i = _as_cell(actor.get("cell", Vector2i.ZERO))
	var target_cell: Vector2i = _as_cell(target.get("cell", Vector2i.ZERO))
	var attack_range: int = int(actor.get("attack_range", 1))
	if _grid_distance(actor_cell, target_cell) > attack_range:
		return false

	var damage: int = _calculate_damage(actor, target)
	var next_hp: int = int(target.get("hp", 1)) - damage
	target["hp"] = next_hp
	if next_hp <= 0:
		target["removed"] = true
		if str(target.get("team", "")) == TEAM_ENEMY:
			simulation_result["defeated_enemies"] = int(simulation_result.get("defeated_enemies", 0)) + 1

	units[target_index] = target
	state["units"] = units
	return true


func _apply_bump_action(state: Dictionary, action: Dictionary, simulation_result: Dictionary) -> bool:
	var actor_id: String = str(action.get("actor_id", ""))
	var target_id: String = str(action.get("target_id", ""))
	var actor_index: int = _find_active_unit_index_by_id(state, actor_id)
	var target_index: int = _find_active_unit_index_by_id(state, target_id)
	if actor_index == -1 or target_index == -1:
		return false

	var units: Array = state.get("units", [])
	var actor: Dictionary = units[actor_index]
	var target: Dictionary = units[target_index]
	var actor_cell: Vector2i = _as_cell(actor.get("cell", Vector2i.ZERO))
	var target_cell: Vector2i = _as_cell(target.get("cell", Vector2i.ZERO))
	var direction: Vector2i = target_cell - actor_cell
	if not _is_cardinal_offset(direction):
		return false

	var push_chain: Array[int] = _collect_push_chain_indices(state, target_index, direction)
	if push_chain.is_empty():
		return false

	for chain_index in range(push_chain.size() - 1, -1, -1):
		var pushed_unit_index: int = int(push_chain[chain_index])
		var pushed_unit: Dictionary = units[pushed_unit_index]
		if bool(pushed_unit.get("removed", false)):
			continue

		var from_cell: Vector2i = _as_cell(pushed_unit.get("cell", Vector2i.ZERO))
		if _terrain_at(state, from_cell) == "cliff":
			pushed_unit["removed"] = true
			units[pushed_unit_index] = pushed_unit
			simulation_result["cliff_falls"] = int(simulation_result.get("cliff_falls", 0)) + 1
			if str(pushed_unit.get("team", "")) == TEAM_ENEMY:
				simulation_result["defeated_enemies"] = int(simulation_result.get("defeated_enemies", 0)) + 1
			continue

		var to_cell: Vector2i = from_cell + direction
		var map_size: Vector2i = _resolve_map_size_from_state(state)
		if not _is_cell_in_bounds(to_cell, map_size):
			return false

		pushed_unit["cell"] = to_cell
		units[pushed_unit_index] = pushed_unit

	state["units"] = units
	return true


func _apply_heal_action(
	state: Dictionary,
	action: Dictionary,
	objective: Dictionary,
	simulation_result: Dictionary
) -> bool:
	if StringName(objective.get("type", "")) != TEMPLATE_HEAL_ALL_ALLIES:
		return false

	var actor_id: String = str(action.get("actor_id", ""))
	var required_actor_id: String = str(objective.get("heal_actor_id", ""))
	if actor_id != required_actor_id:
		return false

	var actor_index: int = _find_active_unit_index_by_id(state, actor_id)
	if actor_index == -1:
		return false

	var heal_range: int = maxi(1, int(objective.get("heal_range", 2)))
	var heal_amount: int = maxi(1, int(objective.get("heal_amount", 4)))
	var units: Array = state.get("units", [])
	var actor: Dictionary = units[actor_index]
	var actor_cell: Vector2i = _as_cell(actor.get("cell", Vector2i.ZERO))
	var healed_points: int = 0

	for unit_index in units.size():
		var unit_variant: Variant = units[unit_index]
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if not _is_active_team_member(unit, TEAM_PLAYER):
			continue
		var unit_cell: Vector2i = _as_cell(unit.get("cell", Vector2i.ZERO))
		if _grid_distance(actor_cell, unit_cell) > heal_range:
			continue

		var current_hp: int = int(unit.get("hp", 1))
		var max_hp: int = int(unit.get("max_hp", current_hp))
		var healed_hp: int = mini(max_hp, current_hp + heal_amount)
		healed_points += maxi(0, healed_hp - current_hp)
		unit["hp"] = healed_hp
		units[unit_index] = unit

	state["units"] = units
	simulation_result["healed_points"] = healed_points
	return healed_points > 0


func _is_objective_complete(
	state_after_action: Dictionary,
	objective: Dictionary,
	action: Dictionary,
	simulation_result: Dictionary
) -> bool:
	var objective_type: StringName = objective.get("type", &"")
	match objective_type:
		TEMPLATE_BUMP_TO_CLIFF_KILL:
			return (
				StringName(action.get("type", "")) == ACTION_BUMP
				and int(simulation_result.get("cliff_falls", 0)) >= int(objective.get("required_cliff_falls", 1))
			)
		TEMPLATE_DEFEAT_N_IN_1_TURN:
			return int(simulation_result.get("defeated_enemies", 0)) >= int(objective.get("required_defeats", 1))
		TEMPLATE_HEAL_ALL_ALLIES:
			return bool(simulation_result.get("all_allies_full", false))
		TEMPLATE_MINIMUM_MOVES:
			if StringName(action.get("type", "")) != ACTION_MOVE:
				return false
			if str(action.get("actor_id", "")) != str(objective.get("runner_id", "")):
				return false

			var runner_index: int = _find_active_unit_index_by_id(state_after_action, str(objective.get("runner_id", "")))
			if runner_index == -1:
				return false
			var units: Array = state_after_action.get("units", [])
			var runner: Dictionary = units[runner_index]
			var goal_cell: Vector2i = _as_cell(objective.get("goal_cell", Vector2i.ZERO))
			var runner_cell: Vector2i = _as_cell(runner.get("cell", Vector2i.ZERO))
			var minimum_moves: int = int(objective.get("minimum_moves", 1))
			return (
				runner_cell == goal_cell
				and int(simulation_result.get("moved_steps", 0)) == minimum_moves
			)
		_:
			return false


func _are_all_player_units_full(state: Dictionary) -> bool:
	var units_variant: Variant = state.get("units", [])
	if not (units_variant is Array):
		return false
	var units: Array = units_variant

	var found_player: bool = false
	for unit_variant in units:
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if not _is_active_team_member(unit, TEAM_PLAYER):
			continue
		found_player = true
		var hp: int = int(unit.get("hp", 1))
		var max_hp: int = int(unit.get("max_hp", hp))
		if hp < max_hp:
			return false

	return found_player


func _collect_push_chain_indices(state: Dictionary, defender_index: int, direction: Vector2i) -> Array[int]:
	var units_variant: Variant = state.get("units", [])
	if not (units_variant is Array):
		return []
	var units: Array = units_variant
	if defender_index < 0 or defender_index >= units.size():
		return []

	var chain_indices: Array[int] = [defender_index]
	var current_index: int = defender_index
	var guard: int = 0

	while guard < 64:
		guard += 1
		var current_unit: Dictionary = units[current_index]
		var next_cell: Vector2i = _as_cell(current_unit.get("cell", Vector2i.ZERO)) + direction
		var next_index: int = _find_active_unit_index_at_cell(state, next_cell)
		if next_index == -1:
			break
		if chain_indices.has(next_index):
			break
		chain_indices.append(next_index)
		current_index = next_index

	return chain_indices


func _find_active_unit_index_by_id(state: Dictionary, unit_id: String) -> int:
	var units_variant: Variant = state.get("units", [])
	if not (units_variant is Array):
		return -1

	var units: Array = units_variant
	for unit_index in units.size():
		var unit_variant: Variant = units[unit_index]
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if str(unit.get("id", "")) != unit_id:
			continue
		if bool(unit.get("removed", false)):
			continue
		return unit_index

	return -1


func _find_active_unit_index_at_cell(state: Dictionary, cell: Vector2i, ignored_unit_id: String = "") -> int:
	var units_variant: Variant = state.get("units", [])
	if not (units_variant is Array):
		return -1
	var units: Array = units_variant

	for unit_index in units.size():
		var unit_variant: Variant = units[unit_index]
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if bool(unit.get("removed", false)):
			continue
		if ignored_unit_id != "" and str(unit.get("id", "")) == ignored_unit_id:
			continue
		if _as_cell(unit.get("cell", Vector2i.ZERO)) == cell:
			return unit_index

	return -1


func _compute_reachable_cell_distances(state: Dictionary, unit: Dictionary) -> Dictionary:
	var map_size: Vector2i = _resolve_map_size_from_state(state)
	var move_range: int = maxi(1, int(unit.get("move_range", 1)))
	var origin: Vector2i = _as_cell(unit.get("cell", Vector2i.ZERO))
	var ignored_id: String = str(unit.get("id", ""))

	var distance_by_cell: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]

	while not frontier.is_empty():
		var current_cell: Vector2i = frontier.pop_front()
		var current_steps: int = int(distance_by_cell[current_cell])
		if current_steps >= move_range:
			continue

		for offset in CARDINAL_OFFSETS:
			var candidate_cell: Vector2i = current_cell + offset
			if not _is_cell_in_bounds(candidate_cell, map_size):
				continue
			if distance_by_cell.has(candidate_cell):
				continue
			if _find_active_unit_index_at_cell(state, candidate_cell, ignored_id) != -1:
				continue

			var next_steps: int = current_steps + 1
			distance_by_cell[candidate_cell] = next_steps
			frontier.push_back(candidate_cell)

	return distance_by_cell


func _calculate_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var attack_value: int = maxi(1, int(attacker.get("attack", 1)))
	var defense_value: int = maxi(0, int(defender.get("defense", 0)))
	var base_damage: int = maxi(1, attack_value - defense_value)

	var attacker_element: int = int(attacker.get("element", Constants.Element.STAR))
	var defender_element: int = int(defender.get("element", Constants.Element.STAR))
	var affinity_multiplier: float = PUFF_DATA_SCRIPT.get_damage_multiplier(attacker_element, defender_element)
	return maxi(1, int(round(float(base_damage) * affinity_multiplier)))


func _make_unit(
	unit_id: String,
	name: String,
	team: String,
	data_path: String,
	cell: Vector2i,
	hp_override: int = -1
) -> Dictionary:
	var stats: Dictionary = _get_puff_stats(data_path)
	var max_hp: int = int(stats.get("max_hp", 10))
	var current_hp: int = max_hp if hp_override < 0 else clampi(hp_override, 1, max_hp)

	return {
		"id": unit_id,
		"name": name,
		"team": team,
		"data_path": data_path,
		"cell": cell,
		"hp": current_hp,
		"max_hp": max_hp,
		"move_range": int(stats.get("move_range", 2)),
		"attack_range": int(stats.get("attack_range", 1)),
		"attack": int(stats.get("attack", 3)),
		"defense": int(stats.get("defense", 2)),
		"element": int(stats.get("element", Constants.Element.STAR))
	}


func _get_puff_stats(data_path: String) -> Dictionary:
	if _stats_cache_by_data_path.has(data_path):
		return _stats_cache_by_data_path[data_path].duplicate(true)

	var default_stats: Dictionary = {
		"move_range": 2,
		"attack_range": 1,
		"max_hp": 10,
		"attack": 3,
		"defense": 2,
		"element": Constants.Element.STAR
	}

	var data_resource: Resource = load(data_path)
	if data_resource == null:
		_stats_cache_by_data_path[data_path] = default_stats
		return default_stats.duplicate(true)

	var resolved_stats: Dictionary = {
		"move_range": maxi(1, int(data_resource.get("move_range"))),
		"attack_range": maxi(1, int(data_resource.get("attack_range"))),
		"max_hp": maxi(1, int(data_resource.get("hp"))),
		"attack": maxi(1, int(data_resource.get("attack"))),
		"defense": maxi(0, int(data_resource.get("defense"))),
		"element": int(data_resource.get("element"))
	}
	_stats_cache_by_data_path[data_path] = resolved_stats
	return resolved_stats.duplicate(true)


func _paint_random_terrain(rows: Array, terrain_pool: Array, count: int, units: Array[Dictionary]) -> void:
	if terrain_pool.is_empty():
		return

	var occupied_cells: Dictionary = {}
	for unit in units:
		occupied_cells[_as_cell(unit.get("cell", Vector2i.ZERO))] = true

	var placed_count: int = 0
	var guard: int = 0
	while placed_count < count and guard < 200:
		guard += 1
		var cell: Vector2i = Vector2i(_rng.randi_range(0, MAP_WIDTH - 1), _rng.randi_range(0, MAP_HEIGHT - 1))
		if occupied_cells.has(cell):
			continue
		if _terrain_at_rows(rows, cell) != "cloud":
			continue

		var terrain_index: int = _rng.randi_range(0, terrain_pool.size() - 1)
		var terrain_name: String = str(terrain_pool[terrain_index])
		_set_terrain(rows, cell, terrain_name)
		placed_count += 1


func _build_cloud_rows(width: int, height: int) -> Array:
	var rows: Array = []
	for _row_index in height:
		var row: Array = []
		for _column_index in width:
			row.append("cloud")
		rows.append(row)
	return rows


func _set_terrain(rows: Array, cell: Vector2i, terrain_type: String) -> void:
	if not _is_cell_in_bounds(cell, Vector2i(MAP_WIDTH, MAP_HEIGHT)):
		return
	if cell.y < 0 or cell.y >= rows.size():
		return
	var row_variant: Variant = rows[cell.y]
	if not (row_variant is Array):
		return
	var row: Array = row_variant
	if cell.x < 0 or cell.x >= row.size():
		return
	row[cell.x] = terrain_type
	rows[cell.y] = row


func _terrain_at(state: Dictionary, cell: Vector2i) -> String:
	var map_config_variant: Variant = state.get("map_config", {})
	if not (map_config_variant is Dictionary):
		return "cloud"
	var map_config: Dictionary = map_config_variant
	var rows_variant: Variant = map_config.get("rows", [])
	if not (rows_variant is Array):
		return "cloud"
	var rows: Array = rows_variant
	return _terrain_at_rows(rows, cell)


func _terrain_at_rows(rows: Array, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return "cloud"
	var row_variant: Variant = rows[cell.y]
	if not (row_variant is Array):
		return "cloud"
	var row: Array = row_variant
	if cell.x < 0 or cell.x >= row.size():
		return "cloud"
	return str(row[cell.x])


func _resolve_map_size_from_state(state: Dictionary) -> Vector2i:
	var map_config_variant: Variant = state.get("map_config", {})
	if not (map_config_variant is Dictionary):
		return Vector2i(MAP_WIDTH, MAP_HEIGHT)
	var map_config: Dictionary = map_config_variant
	var width: int = int(map_config.get("width", MAP_WIDTH))
	var height: int = int(map_config.get("height", MAP_HEIGHT))
	return Vector2i(maxi(1, width), maxi(1, height))


func _cell_is_free_for_spawn(cell: Vector2i, units: Array[Dictionary]) -> bool:
	if not _is_cell_in_bounds(cell, Vector2i(MAP_WIDTH, MAP_HEIGHT)):
		return false
	for unit in units:
		if _as_cell(unit.get("cell", Vector2i.ZERO)) == cell:
			return false
	return true


func _is_active_team_member(unit: Dictionary, team: String) -> bool:
	if bool(unit.get("removed", false)):
		return false
	return str(unit.get("team", "")) == team


func _can_unit_heal(unit: Dictionary, objective: Dictionary) -> bool:
	if StringName(objective.get("type", "")) != TEMPLATE_HEAL_ALL_ALLIES:
		return false
	return str(unit.get("id", "")) == str(objective.get("heal_actor_id", ""))


func _pick_unique_cells(candidates: Array[Vector2i], count: int) -> Array[Vector2i]:
	var shuffled: Array[Vector2i] = candidates.duplicate()
	shuffled.shuffle()
	var picked: Array[Vector2i] = []
	for index in mini(count, shuffled.size()):
		picked.append(shuffled[index])
	return picked


func _normalize_template_id(template_id: StringName) -> StringName:
	var template_text: String = String(template_id).strip_edges().to_lower()
	for supported_template in SUPPORTED_TEMPLATES:
		if template_text == String(supported_template):
			return supported_template
	return &""


func _configure_rng(seed: int) -> void:
	if seed >= 0:
		_rng.seed = seed
		return
	_rng.randomize()


func _as_cell(cell_variant: Variant) -> Vector2i:
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


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _is_cardinal_offset(offset: Vector2i) -> bool:
	return CARDINAL_OFFSETS.has(offset)


func _is_cell_in_bounds(cell: Vector2i, map_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y


func _to_json_safe(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Vector2i:
		var cell: Vector2i = value
		return {"x": cell.x, "y": cell.y}
	if value is Vector2:
		var point: Vector2 = value
		return {"x": point.x, "y": point.y}
	if value is Array:
		var array_value: Array = value
		var normalized_array: Array = []
		for item in array_value:
			normalized_array.append(_to_json_safe(item))
		return normalized_array
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var normalized_dictionary: Dictionary = {}
		for key_variant in dictionary_value.keys():
			var key: String = str(_to_json_safe(key_variant))
			normalized_dictionary[key] = _to_json_safe(dictionary_value[key_variant])
		return normalized_dictionary
	return value
