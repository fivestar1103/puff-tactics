extends RefCounted
class_name PuffAnimator

const DEFAULT_MOVE_STEP_DURATION: float = 0.14
const DEFAULT_ATTACK_DURATION: float = 0.26
const DEFAULT_BUMP_DURATION: float = 0.18
const DEFAULT_DEFEAT_DURATION: float = 0.24
const DEFAULT_HEAL_DURATION: float = 0.32

const MOVE_ARC_HEIGHT: float = 16.0
const BUMP_LANDING_LIFT: float = 8.0
const HEAL_LIFT_DISTANCE: float = 14.0

var _active_tween_by_puff_id: Dictionary = {}


func stop_active_tween(puff: Puff) -> void:
	if puff == null or not is_instance_valid(puff):
		return
	var puff_id: int = puff.get_instance_id()
	var tween_variant: Variant = _active_tween_by_puff_id.get(puff_id, null)
	if tween_variant is Tween:
		var active_tween: Tween = tween_variant
		if is_instance_valid(active_tween):
			active_tween.kill()
	_active_tween_by_puff_id.erase(puff_id)


func play_move_bounce(
	puff: Puff,
	world_path: Array[Vector2],
	step_duration: float = DEFAULT_MOVE_STEP_DURATION,
	arc_height: float = MOVE_ARC_HEIGHT
) -> Tween:
	if puff == null or not is_instance_valid(puff):
		return null
	if world_path.size() < 2:
		return null

	var tween: Tween = _create_bound_tween(puff)
	var clamped_step_duration: float = _clamp_duration(step_duration)
	var lift: float = absf(arc_height)

	for index in range(1, world_path.size()):
		var from_world: Vector2 = world_path[index - 1]
		var to_world: Vector2 = world_path[index]
		var mid_world: Vector2 = from_world.lerp(to_world, 0.5) + Vector2(0.0, -lift)

		var rise_duration: float = clamped_step_duration * 0.45
		var fall_duration: float = clamped_step_duration * 0.55
		var settle_duration: float = clamped_step_duration * 0.25

		tween.tween_property(puff, "global_position", mid_world, rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(puff, "scale", Vector2(0.9, 1.1), rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "global_position", to_world, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(puff, "scale", Vector2(1.1, 0.86), fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(puff, "scale", Vector2.ONE, settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	return tween


func play_attack_inflate_squish(
	puff: Puff,
	target_world: Vector2,
	total_duration: float = DEFAULT_ATTACK_DURATION
) -> Tween:
	if puff == null or not is_instance_valid(puff):
		return null

	var tween: Tween = _create_bound_tween(puff)
	var origin: Vector2 = puff.global_position
	var direction: Vector2 = target_world - origin
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	var lunge_distance: float = minf(24.0, origin.distance_to(target_world) * 0.35)
	var impact_world: Vector2 = origin + direction * lunge_distance
	var clamped_duration: float = _clamp_duration(total_duration)
	var inflate_duration: float = clamped_duration * 0.38
	var squish_duration: float = clamped_duration * 0.32
	var recover_duration: float = clamped_duration * 0.30

	tween.tween_property(puff, "scale", Vector2(1.18, 1.18), inflate_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(puff, "global_position", impact_world, inflate_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", _directional_squash(direction, 0.28), squish_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(puff, "global_position", origin, recover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(puff, "scale", Vector2.ONE, recover_duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	return tween


func play_bump_stretch_bounce(
	puff: Puff,
	from_world: Vector2,
	to_world: Vector2,
	direction: Vector2i,
	total_duration: float = DEFAULT_BUMP_DURATION
) -> Tween:
	if puff == null or not is_instance_valid(puff):
		return null

	var tween: Tween = _create_bound_tween(puff)
	var clamped_duration: float = _clamp_duration(total_duration)
	var travel_duration: float = clamped_duration * 0.72
	var settle_duration: float = clamped_duration * 0.28
	var stretch_scale: Vector2 = _directional_stretch(Vector2(direction), 0.24)
	var squash_scale: Vector2 = _directional_squash(Vector2(direction), 0.16)

	puff.global_position = from_world
	tween.tween_property(puff, "global_position", to_world, travel_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(puff, "scale", stretch_scale, travel_duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", squash_scale, travel_duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var bounce_top: Vector2 = to_world + Vector2(0.0, -BUMP_LANDING_LIFT)
	tween.tween_property(puff, "global_position", bounce_top, settle_duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(puff, "scale", Vector2(0.92, 1.08), settle_duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "global_position", to_world, settle_duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(puff, "scale", Vector2.ONE, settle_duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	return tween


func play_defeat_deflate_fade(
	puff: Puff,
	total_duration: float = DEFAULT_DEFEAT_DURATION
) -> Tween:
	if puff == null or not is_instance_valid(puff):
		return null

	var tween: Tween = _create_bound_tween(puff)
	var clamped_duration: float = _clamp_duration(total_duration)
	var spread_duration: float = clamped_duration * 0.35
	var collapse_duration: float = clamped_duration * 0.65

	tween.tween_property(puff, "scale", Vector2(1.12, 0.82), spread_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector2(0.08, 0.05), collapse_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(puff, "modulate:a", 0.0, collapse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	return tween


func play_heal_glow_float(
	puff: Puff,
	total_duration: float = DEFAULT_HEAL_DURATION,
	lift_distance: float = HEAL_LIFT_DISTANCE
) -> Tween:
	if puff == null or not is_instance_valid(puff):
		return null

	var tween: Tween = _create_bound_tween(puff)
	var origin: Vector2 = puff.global_position
	var base_modulate: Color = puff.modulate
	var glow_modulate: Color = base_modulate.lightened(0.24)
	glow_modulate.a = base_modulate.a

	var clamped_duration: float = _clamp_duration(total_duration)
	var rise_duration: float = clamped_duration * 0.45
	var settle_duration: float = clamped_duration * 0.55
	var lift_target: Vector2 = origin + Vector2(0.0, -absf(lift_distance))

	tween.tween_property(puff, "global_position", lift_target, rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(puff, "modulate", glow_modulate, rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(puff, "scale", Vector2(1.05, 1.05), rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "global_position", origin, settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(puff, "modulate", base_modulate, settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(puff, "scale", Vector2.ONE, settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	return tween


func _create_bound_tween(puff: Puff) -> Tween:
	stop_active_tween(puff)
	puff.scale = Vector2.ONE
	var tween: Tween = puff.create_tween()
	var puff_id: int = puff.get_instance_id()
	_active_tween_by_puff_id[puff_id] = tween
	tween.finished.connect(_on_tween_finished.bind(puff_id, tween), CONNECT_ONE_SHOT)
	return tween


func _on_tween_finished(puff_id: int, tween: Tween) -> void:
	var active_variant: Variant = _active_tween_by_puff_id.get(puff_id, null)
	if active_variant == tween:
		_active_tween_by_puff_id.erase(puff_id)


func _clamp_duration(duration_seconds: float) -> float:
	return maxf(0.05, duration_seconds)


func _directional_stretch(direction: Vector2, intensity: float) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return Vector2(1.0 + intensity, 1.0 - intensity * 0.6)

	var normalized: Vector2 = direction.normalized()
	if absf(normalized.x) >= absf(normalized.y):
		return Vector2(1.0 + intensity, 1.0 - intensity * 0.6)
	return Vector2(1.0 - intensity * 0.6, 1.0 + intensity)


func _directional_squash(direction: Vector2, intensity: float) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return Vector2(1.0 - intensity * 0.6, 1.0 + intensity)

	var normalized: Vector2 = direction.normalized()
	if absf(normalized.x) >= absf(normalized.y):
		return Vector2(1.0 - intensity * 0.6, 1.0 + intensity)
	return Vector2(1.0 + intensity, 1.0 - intensity * 0.6)
