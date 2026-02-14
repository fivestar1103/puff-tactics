extends RefCounted
class_name UtilityAI

const ACTION_WAIT: StringName = &"wait"
const ACTION_MOVE: StringName = &"move"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_SKILL: StringName = &"skill"

const WEIGHT_ATTACK_VALUE: StringName = &"attack_value"
const WEIGHT_SURVIVAL_RISK: StringName = &"survival_risk"
const WEIGHT_POSITIONAL_ADVANTAGE: StringName = &"positional_advantage"
const WEIGHT_BUMP_OPPORTUNITY: StringName = &"bump_opportunity"

const DEFAULT_WEIGHTS: Dictionary = {
	WEIGHT_ATTACK_VALUE: 1.0,
	WEIGHT_SURVIVAL_RISK: 1.0,
	WEIGHT_POSITIONAL_ADVANTAGE: 0.8,
	WEIGHT_BUMP_OPPORTUNITY: 1.15
}

const SCORE_EPSILON: float = 0.0001

var _weights: Dictionary = DEFAULT_WEIGHTS.duplicate(true)


func set_weights(
	attack_value: float,
	survival_risk: float,
	positional_advantage: float,
	bump_opportunity: float
) -> void:
	_weights[WEIGHT_ATTACK_VALUE] = maxf(0.0, attack_value)
	_weights[WEIGHT_SURVIVAL_RISK] = maxf(0.0, survival_risk)
	_weights[WEIGHT_POSITIONAL_ADVANTAGE] = maxf(0.0, positional_advantage)
	_weights[WEIGHT_BUMP_OPPORTUNITY] = maxf(0.0, bump_opportunity)


func get_weights() -> Dictionary:
	return _weights.duplicate(true)


func pick_best_intent(actor: Puff, candidate_intents: Array[Dictionary], context: Dictionary) -> Dictionary:
	if actor == null or candidate_intents.is_empty():
		return _build_wait_intent(actor)

	var best_intent: Dictionary = {}
	var best_score: float = -1.0e20
	var best_priority: int = -1

	for candidate_intent in candidate_intents:
		var scored_intent: Dictionary = _score_candidate_intent(actor, candidate_intent, context)
		var candidate_score: float = float(scored_intent.get("utility_score", -1.0e20))
		var candidate_priority: int = _action_priority(scored_intent.get("action", ACTION_WAIT))

		if best_intent.is_empty():
			best_intent = scored_intent
			best_score = candidate_score
			best_priority = candidate_priority
			continue

		if candidate_score > best_score + SCORE_EPSILON:
			best_intent = scored_intent
			best_score = candidate_score
			best_priority = candidate_priority
			continue

		if is_equal_approx(candidate_score, best_score) and candidate_priority > best_priority:
			best_intent = scored_intent
			best_score = candidate_score
			best_priority = candidate_priority

	if best_intent.is_empty():
		return _build_wait_intent(actor)
	return best_intent


func _score_candidate_intent(actor: Puff, candidate_intent: Dictionary, context: Dictionary) -> Dictionary:
	var scored_intent: Dictionary = candidate_intent.duplicate(true)
	var resulting_cell: Vector2i = _resolve_resulting_cell(actor, candidate_intent)

	var attack_value_score: float = _score_attack_value(actor, candidate_intent, context)
	var survival_risk_score: float = _score_survival_risk(actor, resulting_cell, context)
	var positional_advantage_score: float = _score_positional_advantage(actor, resulting_cell, context)
	var bump_opportunity_score: float = _score_bump_opportunity(candidate_intent, resulting_cell, context)

	var weighted_score: float = 0.0
	weighted_score += attack_value_score * _resolve_weight(WEIGHT_ATTACK_VALUE)
	weighted_score += survival_risk_score * _resolve_weight(WEIGHT_SURVIVAL_RISK)
	weighted_score += positional_advantage_score * _resolve_weight(WEIGHT_POSITIONAL_ADVANTAGE)
	weighted_score += bump_opportunity_score * _resolve_weight(WEIGHT_BUMP_OPPORTUNITY)

	scored_intent["utility_score"] = weighted_score
	scored_intent["utility_factors"] = {
		WEIGHT_ATTACK_VALUE: attack_value_score,
		WEIGHT_SURVIVAL_RISK: survival_risk_score,
		WEIGHT_POSITIONAL_ADVANTAGE: positional_advantage_score,
		WEIGHT_BUMP_OPPORTUNITY: bump_opportunity_score
	}

	return scored_intent


func _score_attack_value(actor: Puff, candidate_intent: Dictionary, context: Dictionary) -> float:
	var action: StringName = candidate_intent.get("action", ACTION_WAIT)
	var resolve_damage_callable: Callable = _resolve_callable(context, "resolve_damage")
	var resolve_hp_callable: Callable = _resolve_callable(context, "resolve_current_hp")

	match action:
		ACTION_ATTACK:
			var target: Puff = _resolve_target_puff(candidate_intent, context)
			if target == null:
				return 0.0
			var estimated_damage: int = _call_int(resolve_damage_callable, [actor, target], 1)
			var target_hp: int = maxi(1, _call_int(resolve_hp_callable, [target], 1))
			var attack_score: float = float(estimated_damage)
			attack_score += clampf(float(estimated_damage) / float(target_hp), 0.0, 1.5) * 2.0
			if estimated_damage >= target_hp:
				attack_score += 1.8
			return attack_score
		ACTION_SKILL:
			var push_count: int = int(candidate_intent.get("bump_push_count", 0))
			var cliff_falls: int = int(candidate_intent.get("bump_cliff_falls", 0))
			var chain_bonus: float = float(maxi(0, push_count - 1)) * 0.6
			return float(push_count) * 0.6 + float(cliff_falls) * 1.4 + chain_bonus
		_:
			return 0.0


func _score_survival_risk(actor: Puff, resulting_cell: Vector2i, context: Dictionary) -> float:
	var player_targets: Array[Puff] = _resolve_player_targets(context)
	if player_targets.is_empty():
		return 0.0

	var resolve_attack_range_callable: Callable = _resolve_callable(context, "resolve_attack_range")
	var resolve_damage_callable: Callable = _resolve_callable(context, "resolve_damage")
	var resolve_hp_callable: Callable = _resolve_callable(context, "resolve_current_hp")
	var grid_distance_callable: Callable = _resolve_callable(context, "grid_distance")
	var is_cliff_cell_callable: Callable = _resolve_callable(context, "is_cliff_cell")

	var projected_threat: float = 0.0
	for player_target in player_targets:
		var distance_to_target: int = _call_int(grid_distance_callable, [resulting_cell, player_target.grid_cell], 99)
		var target_attack_range: int = maxi(1, _call_int(resolve_attack_range_callable, [player_target], 1))
		if distance_to_target <= target_attack_range:
			var projected_damage: int = maxi(1, _call_int(resolve_damage_callable, [player_target, actor], 1))
			projected_threat += float(projected_damage)

		if distance_to_target == 1:
			projected_threat += 0.75
			if _call_bool(is_cliff_cell_callable, [resulting_cell], false):
				projected_threat += 1.1

	var actor_hp: int = maxi(1, _call_int(resolve_hp_callable, [actor], 1))
	var threat_ratio: float = projected_threat / float(actor_hp)
	return -threat_ratio * 3.0


func _score_positional_advantage(actor: Puff, resulting_cell: Vector2i, context: Dictionary) -> float:
	var player_targets: Array[Puff] = _resolve_player_targets(context)
	if player_targets.is_empty():
		return 0.0

	var resolve_attack_range_callable: Callable = _resolve_callable(context, "resolve_attack_range")
	var resolve_terrain_effect_callable: Callable = _resolve_callable(context, "resolve_terrain_effect_at")
	var is_cliff_cell_callable: Callable = _resolve_callable(context, "is_cliff_cell")
	var grid_distance_callable: Callable = _resolve_callable(context, "grid_distance")

	var nearest_target_distance: int = 99
	for player_target in player_targets:
		var distance_to_target: int = _call_int(grid_distance_callable, [resulting_cell, player_target.grid_cell], 99)
		nearest_target_distance = mini(nearest_target_distance, distance_to_target)

	var preferred_distance: int = maxi(1, _call_int(resolve_attack_range_callable, [actor], 1))
	var distance_delta: int = absi(nearest_target_distance - preferred_distance)
	var distance_score: float = clampf(2.2 - float(distance_delta), -2.0, 2.2)

	var terrain_effect: Dictionary = _call_dictionary(resolve_terrain_effect_callable, [resulting_cell], {})
	var terrain_score: float = 0.0
	terrain_score += float(terrain_effect.get("attack_bonus", 0)) * 0.9
	terrain_score += float(terrain_effect.get("push_resistance", 0)) * 0.5
	terrain_score -= float(terrain_effect.get("entry_move_penalty", 0)) * 0.35
	if bool(terrain_effect.get("entry_buff", false)):
		terrain_score += 0.4
	if _call_bool(is_cliff_cell_callable, [resulting_cell], false):
		terrain_score -= 0.9

	return distance_score + terrain_score


func _score_bump_opportunity(candidate_intent: Dictionary, resulting_cell: Vector2i, context: Dictionary) -> float:
	var action: StringName = candidate_intent.get("action", ACTION_WAIT)
	if action == ACTION_SKILL:
		var pushes: int = int(candidate_intent.get("bump_push_count", 0))
		var cliff_falls: int = int(candidate_intent.get("bump_cliff_falls", 0))
		var chain_bonus: float = float(maxi(0, pushes - 1)) * 1.1
		return float(pushes) * 1.3 + float(cliff_falls) * 2.6 + chain_bonus

	var player_targets: Array[Puff] = _resolve_player_targets(context)
	if player_targets.is_empty():
		return 0.0

	var is_cliff_cell_callable: Callable = _resolve_callable(context, "is_cliff_cell")
	var grid_distance_callable: Callable = _resolve_callable(context, "grid_distance")
	var future_opportunity: float = 0.0

	for player_target in player_targets:
		var distance_to_target: int = _call_int(grid_distance_callable, [resulting_cell, player_target.grid_cell], 99)
		if distance_to_target != 1:
			continue

		future_opportunity += 0.55
		if _call_bool(is_cliff_cell_callable, [player_target.grid_cell], false):
			future_opportunity += 0.95

	return future_opportunity


func _resolve_resulting_cell(actor: Puff, intent: Dictionary) -> Vector2i:
	var action: StringName = intent.get("action", ACTION_WAIT)
	if action == ACTION_MOVE:
		return intent.get("move_cell", actor.grid_cell)
	return actor.grid_cell


func _resolve_target_puff(intent: Dictionary, context: Dictionary) -> Puff:
	var target_id: int = int(intent.get("target_puff_id", -1))
	if target_id < 0:
		return null

	var lookup_callable: Callable = _resolve_callable(context, "lookup_puff_by_id")
	if not lookup_callable.is_valid():
		return null

	var target_variant: Variant = lookup_callable.call(target_id)
	if not (target_variant is Puff):
		return null

	var target_puff: Puff = target_variant
	if not is_instance_valid(target_puff):
		return null
	return target_puff


func _resolve_player_targets(context: Dictionary) -> Array[Puff]:
	var player_targets: Array[Puff] = []
	var targets_variant: Variant = context.get("player_targets", [])
	if not (targets_variant is Array):
		return player_targets

	var targets: Array = targets_variant
	for target_variant in targets:
		if not (target_variant is Puff):
			continue
		var target_puff: Puff = target_variant
		if not is_instance_valid(target_puff):
			continue
		player_targets.append(target_puff)

	return player_targets


func _resolve_weight(weight_key: StringName) -> float:
	var weight_variant: Variant = _weights.get(weight_key, DEFAULT_WEIGHTS.get(weight_key, 1.0))
	if weight_variant is float:
		return float(weight_variant)
	if weight_variant is int:
		return float(weight_variant)
	return 1.0


func _resolve_callable(context: Dictionary, callable_key: String) -> Callable:
	var callable_variant: Variant = context.get(callable_key)
	if callable_variant is Callable:
		return callable_variant
	return Callable()


func _call_bool(callable_value: Callable, args: Array, fallback: bool) -> bool:
	if not callable_value.is_valid():
		return fallback
	var value: Variant = callable_value.callv(args)
	if value is bool:
		return bool(value)
	return fallback


func _call_int(callable_value: Callable, args: Array, fallback: int) -> int:
	if not callable_value.is_valid():
		return fallback
	var value: Variant = callable_value.callv(args)
	if value is int:
		return int(value)
	if value is float:
		return int(round(float(value)))
	return fallback


func _call_dictionary(callable_value: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if not callable_value.is_valid():
		return fallback
	var value: Variant = callable_value.callv(args)
	if value is Dictionary:
		return value
	return fallback


func _action_priority(action: StringName) -> int:
	match action:
		ACTION_SKILL:
			return 4
		ACTION_ATTACK:
			return 3
		ACTION_MOVE:
			return 2
		_:
			return 1


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
		"action": ACTION_WAIT,
		"move_cell": actor_cell,
		"target_cell": actor_cell,
		"target_puff_id": -1,
		"skill_cells": [],
		"direction": Vector2i.ZERO
	}
