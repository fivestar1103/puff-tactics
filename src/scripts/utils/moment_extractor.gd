extends RefCounted
class_name MomentExtractor

const LOG_DIRECTORY: String = "user://battle_logs"
const HP_SWING_THRESHOLD: float = 0.30


func extract_from_log_path(log_path: String) -> Dictionary:
	var log_data_variant: Variant = _read_log_json(log_path)
	if not (log_data_variant is Dictionary):
		return {}
	var log_data: Dictionary = log_data_variant
	return extract_from_log_data(log_data)


func extract_from_log_data(log_data: Dictionary) -> Dictionary:
	var turn_summaries: Array[Dictionary] = _collect_turn_summaries(log_data)
	if turn_summaries.is_empty():
		return {}

	var best_turn_summary: Dictionary = {}
	var best_turn_evaluation: Dictionary = {}
	var best_score: float = -1.0

	for turn_summary in turn_summaries:
		var evaluation: Dictionary = _evaluate_turn_summary(turn_summary)
		if not bool(evaluation.get("eligible", false)):
			continue

		var impact_score: float = float(evaluation.get("impact_score", 0.0))
		if impact_score <= best_score:
			continue

		best_score = impact_score
		best_turn_summary = turn_summary
		best_turn_evaluation = evaluation

	if best_turn_summary.is_empty():
		return {}

	return _build_feed_snapshot(log_data, best_turn_summary, best_turn_evaluation)


func extract_from_latest_log(directory_path: String = LOG_DIRECTORY) -> Dictionary:
	var latest_log_path: String = _find_latest_log_path(directory_path)
	if latest_log_path.is_empty():
		return {}
	return extract_from_log_path(latest_log_path)


func _collect_turn_summaries(log_data: Dictionary) -> Array[Dictionary]:
	if log_data.has("turn_summaries"):
		var summaries_variant: Variant = log_data.get("turn_summaries", [])
		if summaries_variant is Array:
			var normalized_summaries: Array[Dictionary] = _normalize_turn_summaries(summaries_variant)
			if not normalized_summaries.is_empty():
				return normalized_summaries

	return _build_turn_summaries_from_events(log_data.get("events", []))


func _normalize_turn_summaries(raw_summaries: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for summary_variant in raw_summaries:
		if not (summary_variant is Dictionary):
			continue

		var summary: Dictionary = summary_variant
		var turn_number: int = int(summary.get("turn_number", -1))
		if turn_number < 0:
			continue

		var before_snapshot: Dictionary = _dictionary_or_empty(summary.get("before_snapshot", {}))
		var player_action: Dictionary = _dictionary_or_empty(summary.get("player_action", {}))
		var result: Dictionary = _dictionary_or_empty(summary.get("result", {}))
		normalized.append(
			{
				"turn_number": turn_number,
				"before_snapshot": before_snapshot,
				"player_action": player_action,
				"result": result
			}
		)

	return normalized


func _build_turn_summaries_from_events(raw_events_variant: Variant) -> Array[Dictionary]:
	if not (raw_events_variant is Array):
		return []

	var turn_context: Dictionary = {}
	var raw_events: Array = raw_events_variant
	for event_variant in raw_events:
		if not (event_variant is Dictionary):
			continue

		var event_data: Dictionary = event_variant
		var event_type: String = str(event_data.get("event", ""))
		if event_type != "player_turn_snapshot" and event_type != "player_action_result":
			continue

		var payload: Dictionary = _dictionary_or_empty(event_data.get("payload", {}))
		var turn_number: int = int(payload.get("turn_number", event_data.get("turn_number", -1)))
		if turn_number < 0:
			continue

		var context: Dictionary = turn_context.get(turn_number, {
			"turn_number": turn_number,
			"before_snapshot": {},
			"player_action": {},
			"result": {}
		})

		if event_type == "player_turn_snapshot":
			context["before_snapshot"] = payload.duplicate(true)
		else:
			context["player_action"] = _dictionary_or_empty(payload.get("action", {}))
			context["result"] = _dictionary_or_empty(payload.get("result", {}))

		turn_context[turn_number] = context

	var turn_numbers: Array[int] = []
	for turn_variant in turn_context.keys():
		turn_numbers.append(int(turn_variant))
	turn_numbers.sort()

	var summaries: Array[Dictionary] = []
	for turn_number in turn_numbers:
		var summary_variant: Variant = turn_context.get(turn_number, null)
		if not (summary_variant is Dictionary):
			continue
		summaries.append(summary_variant)

	return summaries


func _evaluate_turn_summary(turn_summary: Dictionary) -> Dictionary:
	var player_action: Dictionary = _dictionary_or_empty(turn_summary.get("player_action", {}))
	var result: Dictionary = _dictionary_or_empty(turn_summary.get("result", {}))
	if player_action.is_empty() and result.is_empty():
		return {
			"eligible": false
		}

	var hp_swing_ratio: float = float(result.get("hp_swing_ratio", player_action.get("hp_swing_ratio", 0.0)))
	var knockout_occurred: bool = (
		bool(result.get("knockout_occurred", false))
		or bool(player_action.get("knockout", false))
		or int(player_action.get("knockout_count", 0)) > 0
	)
	var action_type: String = str(player_action.get("action", ""))
	var unique_skill_id: String = str(player_action.get("skill_id", result.get("unique_skill_id", "")))
	var unique_skill_changed_outcome: bool = bool(result.get("unique_skill_changed_outcome", false))
	if not unique_skill_changed_outcome:
		unique_skill_changed_outcome = (
			action_type == "skill"
			and not unique_skill_id.is_empty()
			and (
				bool(player_action.get("changed_outcome", false))
				or knockout_occurred
				or hp_swing_ratio >= HP_SWING_THRESHOLD
			)
		)

	var meets_hp_swing_threshold: bool = hp_swing_ratio >= HP_SWING_THRESHOLD
	var eligible: bool = meets_hp_swing_threshold or knockout_occurred or unique_skill_changed_outcome
	var impact_score: float = hp_swing_ratio * 100.0
	if knockout_occurred:
		impact_score += 35.0
	if unique_skill_changed_outcome:
		impact_score += 40.0

	return {
		"eligible": eligible,
		"impact_score": impact_score,
		"meets_hp_swing_threshold": meets_hp_swing_threshold,
		"knockout_occurred": knockout_occurred,
		"unique_skill_changed_outcome": unique_skill_changed_outcome,
		"hp_swing_ratio": hp_swing_ratio
	}


func _build_feed_snapshot(log_data: Dictionary, turn_summary: Dictionary, evaluation: Dictionary) -> Dictionary:
	var turn_number: int = int(turn_summary.get("turn_number", -1))
	if turn_number < 0:
		return {}

	var before_snapshot: Dictionary = _dictionary_or_empty(turn_summary.get("before_snapshot", {}))
	var map_state_before_turn: Dictionary = _dictionary_or_empty(
		before_snapshot.get("map_state_before_turn", log_data.get("map_config", {}))
	)
	if map_state_before_turn.is_empty():
		return {}

	var puffs: Array[Dictionary] = _normalize_puffs_for_feed(before_snapshot.get("puffs", log_data.get("units", [])))
	if puffs.is_empty():
		return {}

	var enemy_intents: Array[Dictionary] = _normalize_enemy_intents(before_snapshot.get("enemy_intents", []))
	var player_action: Dictionary = _dictionary_or_empty(turn_summary.get("player_action", {}))
	var result: Dictionary = _dictionary_or_empty(turn_summary.get("result", {}))
	var battle_id: String = str(log_data.get("battle_id", "battle"))
	var feed_item_id: String = "moment_%s_turn_%d" % [battle_id, turn_number]

	return _to_json_safe(
		{
			"feed_item_id": feed_item_id,
			"map_config": map_state_before_turn,
			"puffs": puffs,
			"enemy_intents": enemy_intents,
			"target_score": _estimate_target_score(evaluation),
			"moment_meta": {
				"source_battle_id": battle_id,
				"turn_number": turn_number,
				"criteria": {
					"hp_swing_ge_30": bool(evaluation.get("meets_hp_swing_threshold", false)),
					"unit_knockout_occurred": bool(evaluation.get("knockout_occurred", false)),
					"unique_skill_changed_outcome": bool(evaluation.get("unique_skill_changed_outcome", false))
				},
				"impact_score": float(evaluation.get("impact_score", 0.0)),
				"original_player_action": player_action,
				"original_result": result
			}
		}
	)


func _estimate_target_score(evaluation: Dictionary) -> int:
	var base_score: int = 210
	if bool(evaluation.get("meets_hp_swing_threshold", false)):
		base_score += 30
	if bool(evaluation.get("knockout_occurred", false)):
		base_score += 45
	if bool(evaluation.get("unique_skill_changed_outcome", false)):
		base_score += 50
	return base_score


func _normalize_puffs_for_feed(raw_puffs_variant: Variant) -> Array[Dictionary]:
	if not (raw_puffs_variant is Array):
		return []

	var puffs: Array[Dictionary] = []
	var raw_puffs: Array = raw_puffs_variant
	for puff_variant in raw_puffs:
		if not (puff_variant is Dictionary):
			continue
		var puff: Dictionary = puff_variant
		if puff.has("alive") and not bool(puff.get("alive", true)):
			continue

		var name: String = str(puff.get("name", "Puff"))
		var team: String = str(puff.get("team", "enemy")).strip_edges().to_lower()
		if team != "player" and team != "enemy":
			team = "enemy"

		puffs.append(
			{
				"name": name,
				"team": team,
				"data_path": str(puff.get("data_path", "")),
				"cell": _to_cell_dictionary(puff.get("cell", Vector2i.ZERO)),
				"hp": int(puff.get("hp", 0)),
				"max_hp": int(puff.get("max_hp", 0))
			}
		)

	return puffs


func _normalize_enemy_intents(raw_intents_variant: Variant) -> Array[Dictionary]:
	if not (raw_intents_variant is Array):
		return []

	var intents: Array[Dictionary] = []
	var raw_intents: Array = raw_intents_variant
	for intent_variant in raw_intents:
		if not (intent_variant is Dictionary):
			continue
		var intent: Dictionary = intent_variant

		var normalized_skill_cells: Array[Dictionary] = []
		var skill_cells_variant: Variant = intent.get("skill_cells", [])
		if skill_cells_variant is Array:
			var skill_cells: Array = skill_cells_variant
			for skill_cell_variant in skill_cells:
				normalized_skill_cells.append(_to_cell_dictionary(skill_cell_variant))

		intents.append(
			{
				"action": str(intent.get("action", "wait")).to_lower(),
				"actor_cell": _to_cell_dictionary(intent.get("actor_cell", Vector2i.ZERO)),
				"move_cell": _to_cell_dictionary(intent.get("move_cell", intent.get("actor_cell", Vector2i.ZERO))),
				"target_cell": _to_cell_dictionary(intent.get("target_cell", intent.get("actor_cell", Vector2i.ZERO))),
				"skill_cells": normalized_skill_cells,
				"direction": _to_cell_dictionary(intent.get("direction", Vector2i.ZERO))
			}
		)

	return intents


func _to_cell_dictionary(cell_variant: Variant) -> Dictionary:
	var cell: Vector2i = Vector2i.ZERO
	if cell_variant is Vector2i:
		cell = cell_variant
	elif cell_variant is Dictionary:
		var cell_dict: Dictionary = cell_variant
		cell = Vector2i(int(cell_dict.get("x", 0)), int(cell_dict.get("y", 0)))
	elif cell_variant is Array:
		var cell_array: Array = cell_variant
		if cell_array.size() >= 2:
			cell = Vector2i(int(cell_array[0]), int(cell_array[1]))
	return {"x": cell.x, "y": cell.y}


func _find_latest_log_path(directory_path: String) -> String:
	var absolute_directory_path: String = ProjectSettings.globalize_path(directory_path)
	var directory: DirAccess = DirAccess.open(absolute_directory_path)
	if directory == null:
		return ""

	var best_timestamp: int = -1
	var best_path: String = ""
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir():
			entry_name = directory.get_next()
			continue
		if not entry_name.ends_with(".json"):
			entry_name = directory.get_next()
			continue

		var timestamp_digits: String = entry_name.get_basename().trim_prefix("full_battle_")
		var timestamp_value: int = int(timestamp_digits)
		if timestamp_value > best_timestamp:
			best_timestamp = timestamp_value
			best_path = "%s/%s" % [directory_path, entry_name]
		entry_name = directory.get_next()
	directory.list_dir_end()

	return best_path


func _read_log_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var raw_text: String = file.get_as_text()
	file.close()
	if raw_text.is_empty():
		return null

	var parser: JSON = JSON.new()
	var error_code: int = parser.parse(raw_text)
	if error_code != OK:
		return null
	return parser.data


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _to_json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var normalized_dictionary: Dictionary = {}
		for key_variant in dictionary_value.keys():
			normalized_dictionary[str(key_variant)] = _to_json_safe(dictionary_value[key_variant])
		return normalized_dictionary

	if value is Array:
		var array_value: Array = value
		var normalized_array: Array = []
		for item in array_value:
			normalized_array.append(_to_json_safe(item))
		return normalized_array

	if value is Vector2i:
		var cell: Vector2i = value
		return {"x": cell.x, "y": cell.y}

	if value is Vector2:
		var point: Vector2 = value
		return {"x": point.x, "y": point.y}

	if value is StringName:
		return str(value)

	return value
