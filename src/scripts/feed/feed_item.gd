extends Node2D
class_name FeedItem

signal cycle_completed(score: int, cycle_duration_seconds: float)
signal status_changed(status_text: String, swipe_unlocked: bool)

const TURN_BATTLE_SCENE: PackedScene = preload("res://src/scenes/battle/TurnBattle.tscn")
const PUFF_SCENE: PackedScene = preload("res://src/scenes/puffs/Puff.tscn")
const PUFF_DATA_SCRIPT: GDScript = preload("res://src/scripts/puffs/puff_data.gd")

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"
const PHASE_RESOLVE: StringName = &"resolve"

const MIN_DECISION_SECONDS: float = 15.0
const MAX_DECISION_SECONDS: float = 30.0
const RESULT_PHASE_SECONDS: float = 3.0
const SCORE_PHASE_SECONDS: float = 2.0

const SNAPSHOT_SCALE: Vector2 = Vector2(0.68, 0.68)
const DEFAULT_TARGET_SCORE: int = 230

const DEFAULT_SNAPSHOT: Dictionary = {
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
			"team": TEAM_PLAYER,
			"data_path": "res://src/resources/puffs/base/flame_melee.tres",
			"cell": Vector2i(1, 3)
		},
		{
			"name": "Cloud_Guard",
			"team": TEAM_ENEMY,
			"data_path": "res://src/resources/puffs/base/cloud_tank.tres",
			"cell": Vector2i(2, 2)
		},
		{
			"name": "Droplet_Backline",
			"team": TEAM_ENEMY,
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
	"target_score": DEFAULT_TARGET_SCORE
}

var _snapshot: Dictionary = DEFAULT_SNAPSHOT.duplicate(true)

var _battle_root: Node2D
var _battle_map: BattleMap
var _turn_manager: TurnManager
var _enemy_intent: EnemyIntent

var _status_panel: ColorRect
var _status_label: Label
var _detail_label: Label
var _decision_timeout_timer: Timer

var _puff_team_by_id: Dictionary = {}
var _initial_enemy_count: int = 0
var _initial_player_count: int = 0

var _is_active: bool = false
var _decision_started: bool = false
var _decision_locked: bool = false
var _cycle_done: bool = false

var _decision_start_time_seconds: float = 0.0
var _decision_lock_time_seconds: float = 0.0
var _cycle_completion_time_seconds: float = 0.0


func configure_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if is_node_ready():
		_rebuild_battle_snapshot()


func set_interaction_enabled(enabled: bool) -> void:
	_is_active = enabled
	if _turn_manager == null:
		return

	if _cycle_done or _decision_locked:
		_turn_manager.set_process_unhandled_input(false)
		return

	if enabled and not _decision_started:
		_begin_decision_phase()

	_turn_manager.set_process_unhandled_input(enabled and _decision_started and not _decision_locked)


func is_cycle_complete() -> bool:
	return _cycle_done


func can_advance_to_next_item() -> bool:
	return _cycle_done


func get_status_text() -> String:
	if _status_label == null:
		return ""
	return _status_label.text


func _ready() -> void:
	_build_status_overlay()
	_setup_decision_timeout_timer()
	_rebuild_battle_snapshot()


func _build_status_overlay() -> void:
	_status_panel = ColorRect.new()
	_status_panel.name = "StatusPanel"
	_status_panel.position = Vector2(-402.0, -620.0)
	_status_panel.size = Vector2(804.0, 170.0)
	_status_panel.color = Color(0.08, 0.11, 0.19, 0.68)
	add_child(_status_panel)

	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 20.0)
	_status_label.size = Vector2(756.0, 62.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 34)
	_status_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
	_status_panel.add_child(_status_label)

	_detail_label = Label.new()
	_detail_label.position = Vector2(24.0, 86.0)
	_detail_label.size = Vector2(756.0, 64.0)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 24)
	_detail_label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0, 0.92))
	_status_panel.add_child(_detail_label)

	_set_status(
		"One-turn puzzle: choose move, attack, or bump",
		"Play the tactical turn, then watch 3s resolve + 2s scoring."
	)


func _setup_decision_timeout_timer() -> void:
	_decision_timeout_timer = Timer.new()
	_decision_timeout_timer.one_shot = true
	_decision_timeout_timer.wait_time = MAX_DECISION_SECONDS
	add_child(_decision_timeout_timer)
	_connect_if_needed(_decision_timeout_timer, &"timeout", Callable(self, "_on_decision_timeout"))


func _rebuild_battle_snapshot() -> void:
	_clear_existing_battle_snapshot()

	var battle_variant: Node = TURN_BATTLE_SCENE.instantiate()
	if not (battle_variant is Node2D):
		battle_variant.queue_free()
		push_warning("FeedItem requires TurnBattle.tscn to instantiate as Node2D.")
		return

	_battle_root = battle_variant
	var turn_manager_candidate: Node = _battle_root.get_node_or_null("TurnManager")
	if turn_manager_candidate is TurnManager:
		turn_manager_candidate.auto_spawn_demo_puffs = false

	add_child(_battle_root)
	_battle_root.scale = SNAPSHOT_SCALE

	_cache_battle_nodes()
	_connect_turn_manager_signals()
	_apply_snapshot_map()
	_spawn_snapshot_puffs()
	_seed_snapshot_enemy_intents()

	if _turn_manager != null:
		_turn_manager.set_process_unhandled_input(false)

	_set_status(
		"One-turn puzzle: choose move, attack, or bump",
		"Decision window %.0fs to %.0fs before result reveal." % [MIN_DECISION_SECONDS, MAX_DECISION_SECONDS]
	)


func _cache_battle_nodes() -> void:
	_battle_map = null
	_turn_manager = null
	_enemy_intent = null

	if _battle_root == null:
		return

	var map_candidate: Node = _battle_root.get_node_or_null("BattleMap")
	if map_candidate is BattleMap:
		_battle_map = map_candidate

	var turn_manager_candidate: Node = _battle_root.get_node_or_null("TurnManager")
	if turn_manager_candidate is TurnManager:
		_turn_manager = turn_manager_candidate

	var intent_candidate: Node = _battle_root.get_node_or_null("EnemyIntent")
	if intent_candidate is EnemyIntent:
		_enemy_intent = intent_candidate


func _connect_turn_manager_signals() -> void:
	if _turn_manager == null:
		return
	_connect_if_needed(_turn_manager, &"phase_changed", Callable(self, "_on_turn_phase_changed"))


func _apply_snapshot_map() -> void:
	if _battle_map == null:
		return
	var map_config_variant: Variant = _snapshot.get("map_config", {})
	if map_config_variant is Dictionary and not map_config_variant.is_empty():
		_battle_map.load_map_from_config(map_config_variant)


func _spawn_snapshot_puffs() -> void:
	_puff_team_by_id.clear()
	_initial_enemy_count = 0
	_initial_player_count = 0

	if _turn_manager == null or _battle_root == null:
		return

	var puffs_variant: Variant = _snapshot.get("puffs", [])
	if not (puffs_variant is Array):
		return

	var puff_configs: Array = puffs_variant
	for puff_config_variant in puff_configs:
		if not (puff_config_variant is Dictionary):
			continue
		var puff_config: Dictionary = puff_config_variant
		_spawn_snapshot_puff(puff_config)

	var counts: Dictionary = _count_alive_puffs_by_team()
	_initial_player_count = int(counts.get(TEAM_PLAYER, 0))
	_initial_enemy_count = int(counts.get(TEAM_ENEMY, 0))


func _spawn_snapshot_puff(puff_config: Dictionary) -> void:
	if _turn_manager == null:
		return

	var puff_variant: Node = PUFF_SCENE.instantiate()
	if not (puff_variant is Puff):
		puff_variant.queue_free()
		return

	var puff: Puff = puff_variant
	_battle_root.add_child(puff)
	puff.set_battle_map(_battle_map)

	var team: StringName = _normalize_team(puff_config.get("team", TEAM_ENEMY))
	var data_path: String = str(puff_config.get("data_path", ""))
	var puff_data_resource: Resource = null
	if not data_path.is_empty():
		puff_data_resource = _load_puff_data_for_team(data_path, team)
	puff_data_resource = _apply_snapshot_puff_overrides(puff_data_resource, puff_config)
	if puff_data_resource != null:
		puff.set_puff_data(puff_data_resource)

	var cell: Vector2i = _to_cell(puff_config.get("cell", Vector2i.ZERO))
	puff.set_grid_cell(cell)

	var puff_name: String = str(puff_config.get("name", ""))
	if puff_name.is_empty():
		puff_name = _build_snapshot_puff_name(puff_config, cell)
	puff.name = puff_name

	_turn_manager.register_puff(puff, team)

	var puff_id: int = puff.get_instance_id()
	_puff_team_by_id[puff_id] = team
	puff.tree_exited.connect(_on_snapshot_puff_exited.bind(puff_id), CONNECT_ONE_SHOT)


func _seed_snapshot_enemy_intents() -> void:
	if _enemy_intent == null:
		return

	var intents_variant: Variant = _snapshot.get("enemy_intents", [])
	if not (intents_variant is Array):
		return
	var intents: Array = intents_variant
	_enemy_intent.load_snapshot_intents(intents)


func _begin_decision_phase() -> void:
	if _decision_started or _cycle_done:
		return
	_decision_started = true
	_decision_start_time_seconds = _now_seconds()
	_decision_lock_time_seconds = 0.0
	_cycle_completion_time_seconds = 0.0
	_decision_timeout_timer.start(MAX_DECISION_SECONDS)

	_set_status(
		"Your turn: move, attack, or bump",
		"Decision timer: %.0f seconds max" % MAX_DECISION_SECONDS
	)


func _on_turn_phase_changed(phase: StringName, active_side: StringName, _turn_number: int) -> void:
	if _cycle_done or _decision_locked or not _decision_started:
		return
	if phase != PHASE_RESOLVE:
		return
	if active_side != TEAM_PLAYER:
		return

	_decision_locked = true
	_decision_lock_time_seconds = _now_seconds()
	call_deferred("_run_completion_flow", true)


func _on_decision_timeout() -> void:
	if _cycle_done or _decision_locked or not _decision_started:
		return
	_decision_locked = true
	_decision_lock_time_seconds = _now_seconds()
	call_deferred("_run_completion_flow", false)


func _run_completion_flow(player_acted: bool) -> void:
	if _turn_manager != null:
		_turn_manager.set_process_unhandled_input(false)

	if _decision_timeout_timer != null and not _decision_timeout_timer.is_stopped():
		_decision_timeout_timer.stop()

	var elapsed_decision: float = _decision_elapsed_seconds()
	var min_hold_seconds: float = maxf(0.0, MIN_DECISION_SECONDS - elapsed_decision)
	if min_hold_seconds > 0.0:
		_set_status(
			"Locking tactical result...",
			"Holding %.1fs so each feed cycle stays within 20-35 seconds." % min_hold_seconds
		)
		await get_tree().create_timer(min_hold_seconds).timeout

	_set_status(
		"Resolving turn result",
		"Outcome animation (%.0f seconds)." % RESULT_PHASE_SECONDS
	)
	await _play_result_animation()

	var final_score: int = _calculate_score(player_acted)
	var target_score: int = int(_snapshot.get("target_score", DEFAULT_TARGET_SCORE))
	var delta: int = final_score - target_score
	var comparison_label: String = "You outscored the benchmark by %d" % delta if delta >= 0 else "Benchmark leads by %d" % absi(delta)
	_set_status(
		"Score: %d" % final_score,
		"%s. Comparison screen (%.0f seconds)." % [comparison_label, SCORE_PHASE_SECONDS]
	)
	await get_tree().create_timer(SCORE_PHASE_SECONDS).timeout

	_cycle_done = true
	_cycle_completion_time_seconds = _now_seconds()

	_emit_feed_item_completed(final_score)
	_set_status(
		"Swipe up for next feed item",
		"Cycle complete in %.1fs." % _cycle_duration_seconds()
	)

	emit_signal("cycle_completed", final_score, _cycle_duration_seconds())


func _play_result_animation() -> void:
	if _status_panel == null:
		await get_tree().create_timer(RESULT_PHASE_SECONDS).timeout
		return

	_status_panel.modulate = Color(1.0, 1.0, 1.0, 0.76)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_status_panel, "modulate:a", 0.98, RESULT_PHASE_SECONDS * 0.45)
	tween.tween_property(_status_panel, "modulate:a", 0.78, RESULT_PHASE_SECONDS * 0.55)
	await tween.finished


func _calculate_score(player_acted: bool) -> int:
	var counts: Dictionary = _count_alive_puffs_by_team()
	var enemies_alive: int = int(counts.get(TEAM_ENEMY, 0))
	var allies_alive: int = int(counts.get(TEAM_PLAYER, 0))

	var enemies_defeated: int = maxi(0, _initial_enemy_count - enemies_alive)
	var allies_surviving: int = maxi(0, allies_alive)

	var decision_elapsed: float = clampf(_decision_elapsed_seconds(), 0.0, MAX_DECISION_SECONDS)
	var speed_bonus: int = maxi(0, int(round((MAX_DECISION_SECONDS - decision_elapsed) * 3.0)))
	var action_bonus: int = 35 if player_acted else 0

	return enemies_defeated * 140 + allies_surviving * 45 + speed_bonus + action_bonus


func _count_alive_puffs_by_team() -> Dictionary:
	var counts: Dictionary = {
		TEAM_PLAYER: 0,
		TEAM_ENEMY: 0
	}

	var stale_ids: Array[int] = []
	for puff_id_variant in _puff_team_by_id.keys():
		var puff_id: int = int(puff_id_variant)
		var puff_variant: Variant = instance_from_id(puff_id)
		if not (puff_variant is Puff):
			stale_ids.append(puff_id)
			continue

		var puff: Puff = puff_variant
		if not is_instance_valid(puff):
			stale_ids.append(puff_id)
			continue

		var team: StringName = _normalize_team(_puff_team_by_id.get(puff_id, TEAM_ENEMY))
		counts[team] = int(counts.get(team, 0)) + 1

	for stale_id in stale_ids:
		_puff_team_by_id.erase(stale_id)

	return counts


func _clear_existing_battle_snapshot() -> void:
	if _battle_root != null and is_instance_valid(_battle_root):
		_battle_root.queue_free()

	_battle_root = null
	_battle_map = null
	_turn_manager = null
	_enemy_intent = null
	_puff_team_by_id.clear()
	_initial_enemy_count = 0
	_initial_player_count = 0
	_decision_started = false
	_decision_locked = false
	_cycle_done = false

	if _decision_timeout_timer != null and not _decision_timeout_timer.is_stopped():
		_decision_timeout_timer.stop()


func _emit_feed_item_completed(score: int) -> void:
	var signal_bus: Node = get_node_or_null("/root/SignalBus")
	if signal_bus == null:
		return
	if not signal_bus.has_signal(&"feed_item_completed"):
		return
	signal_bus.emit_signal("feed_item_completed", score)


func _set_status(headline: String, detail: String) -> void:
	if _status_label != null:
		_status_label.text = headline
	if _detail_label != null:
		_detail_label.text = detail
	emit_signal("status_changed", headline, can_advance_to_next_item())


func _decision_elapsed_seconds() -> float:
	if not _decision_started:
		return 0.0
	if _decision_lock_time_seconds > 0.0:
		return maxf(0.0, _decision_lock_time_seconds - _decision_start_time_seconds)
	return maxf(0.0, _now_seconds() - _decision_start_time_seconds)


func _cycle_duration_seconds() -> float:
	if not _decision_started:
		return 0.0
	if _cycle_completion_time_seconds > 0.0:
		return maxf(0.0, _cycle_completion_time_seconds - _decision_start_time_seconds)
	return maxf(0.0, _now_seconds() - _decision_start_time_seconds)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _to_cell(cell_variant: Variant) -> Vector2i:
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


func _normalize_team(team_variant: Variant) -> StringName:
	if team_variant is StringName:
		var named_team: StringName = team_variant
		if named_team == TEAM_PLAYER or named_team == TEAM_ENEMY:
			return named_team

	var team_text: String = str(team_variant).strip_edges().to_lower()
	if team_text == String(TEAM_PLAYER):
		return TEAM_PLAYER
	if team_text == String(TEAM_ENEMY):
		return TEAM_ENEMY
	return TEAM_ENEMY


func _build_snapshot_puff_name(puff_config: Dictionary, cell: Vector2i) -> String:
	var team: StringName = _normalize_team(puff_config.get("team", TEAM_ENEMY))
	return "%s_%d_%d" % [String(team), cell.x, cell.y]


func _on_snapshot_puff_exited(puff_id: int) -> void:
	_puff_team_by_id.erase(puff_id)


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)


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


func _apply_snapshot_puff_overrides(base_resource: Resource, puff_config: Dictionary) -> Resource:
	var needs_override: bool = (
		puff_config.has("element")
		or puff_config.has("puff_class")
		or puff_config.has("display_name")
	)
	if not needs_override:
		return base_resource

	var runtime_resource: Resource = null
	if base_resource != null:
		runtime_resource = base_resource.duplicate(true)
	else:
		var fallback_variant: Variant = PUFF_DATA_SCRIPT.new()
		if fallback_variant is Resource:
			runtime_resource = fallback_variant

	if runtime_resource == null:
		return null

	if puff_config.has("element"):
		runtime_resource.set("element", int(puff_config.get("element", Constants.Element.STAR)))
	if puff_config.has("puff_class"):
		runtime_resource.set("puff_class", int(puff_config.get("puff_class", Constants.PuffClass.STAR)))
	if puff_config.has("display_name"):
		runtime_resource.set("display_name", StringName(str(puff_config.get("display_name", ""))))

	return runtime_resource
