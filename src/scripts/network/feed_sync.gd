extends Node

const CACHE_DIRECTORY_PATH: String = "user://feed_cache"
const FEED_CACHE_FILE_PATH: String = "user://feed_cache/feed_items_cache.json"
const PENDING_RESULTS_FILE_PATH: String = "user://feed_cache/pending_results.json"

const FEED_BATCH_SIZE: int = 50
const FEED_ITEMS_TABLE: String = "feed_items"
const FEED_RESULTS_TABLE: String = "feed_results"

const DEFAULT_TARGET_SCORE: int = 220
const FALLBACK_PUFF_DATA_PATH: String = "res://src/resources/puffs/base/flame_melee.tres"

var _cached_feed_items: Array[Dictionary] = []
var _pending_results: Array[Dictionary] = []
var _is_flushing_results: bool = false


func _ready() -> void:
	_cached_feed_items = load_cached_feed_items()
	_pending_results = _load_pending_results()
	if not _pending_results.is_empty():
		call_deferred("_flush_pending_results_deferred")


func load_cached_feed_items() -> Array[Dictionary]:
	var payload_variant: Variant = _read_json_file(FEED_CACHE_FILE_PATH)
	if payload_variant == null:
		_cached_feed_items = []
		return []

	var raw_items: Array = []
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		var items_variant: Variant = payload.get("items", [])
		if items_variant is Array:
			raw_items = items_variant
	elif payload_variant is Array:
		raw_items = payload_variant

	var normalized_items: Array[Dictionary] = _normalize_snapshot_array(raw_items)
	_cached_feed_items = normalized_items.duplicate(true)
	return normalized_items


func get_cached_feed_items() -> Array[Dictionary]:
	return _cached_feed_items.duplicate(true)


func fetch_feed_items_batch(offset: int = 0, limit: int = FEED_BATCH_SIZE) -> Dictionary:
	var clamped_offset: int = maxi(0, offset)
	var clamped_limit: int = maxi(1, limit)

	var response: Dictionary = await _request_feed_batch(clamped_offset, clamped_limit)
	if not bool(response.get("ok", false)):
		return {
			"ok": false,
			"error": str(response.get("error", "Unable to fetch feed items.")),
			"items": [],
			"from_cache": true
		}

	var rows_variant: Variant = response.get("data", [])
	if not (rows_variant is Array):
		return {
			"ok": false,
			"error": "feed_items response payload was not an array.",
			"items": [],
			"from_cache": true
		}

	var normalized_items: Array[Dictionary] = []
	for row_variant in rows_variant:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var snapshot: Dictionary = _extract_snapshot_from_row(row)
		if snapshot.is_empty():
			continue
		normalized_items.append(snapshot)

	_merge_batch_into_cache(clamped_offset, normalized_items)

	return {
		"ok": true,
		"error": "",
		"items": normalized_items,
		"from_cache": false
	}


func submit_feed_result(snapshot: Dictionary, score: int, cycle_duration_seconds: float = 0.0) -> void:
	var payload: Dictionary = _build_result_payload(snapshot, score, cycle_duration_seconds)
	if payload.is_empty():
		return

	_pending_results.append(payload)
	_save_pending_results()
	call_deferred("_flush_pending_results_deferred")


func flush_pending_results() -> Dictionary:
	if _is_flushing_results:
		return {
			"ok": true,
			"posted_count": 0,
			"pending_count": _pending_results.size()
		}

	_is_flushing_results = true
	var posted_count: int = 0

	while not _pending_results.is_empty():
		var payload: Dictionary = _pending_results[0]
		var response: Dictionary = await _post_feed_result(payload)
		if not bool(response.get("ok", false)):
			_is_flushing_results = false
			_save_pending_results()
			return {
				"ok": false,
				"posted_count": posted_count,
				"pending_count": _pending_results.size(),
				"error": str(response.get("error", "Unable to post feed result."))
			}

		_pending_results.remove_at(0)
		posted_count += 1

	_is_flushing_results = false
	_save_pending_results()
	return {
		"ok": true,
		"posted_count": posted_count,
		"pending_count": _pending_results.size()
	}


func _flush_pending_results_deferred() -> void:
	await flush_pending_results()


func _request_feed_batch(offset: int, limit: int) -> Dictionary:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null:
		return {
			"ok": false,
			"error": "SupabaseClient autoload is unavailable."
		}

	if not supabase_client.has_method("request_rest"):
		return {
			"ok": false,
			"error": "SupabaseClient does not implement request_rest()."
		}

	var query_params: Dictionary = {
		"select": "*",
		"limit": limit,
		"offset": offset
	}

	return await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_GET,
		FEED_ITEMS_TABLE,
		query_params
	)


func _post_feed_result(payload: Dictionary) -> Dictionary:
	var supabase_client: Node = _resolve_supabase_client()
	if supabase_client == null:
		return {
			"ok": false,
			"error": "SupabaseClient autoload is unavailable."
		}

	if not supabase_client.has_method("request_rest"):
		return {
			"ok": false,
			"error": "SupabaseClient does not implement request_rest()."
		}

	var headers: Array[String] = ["Prefer: return=minimal"]
	return await supabase_client.call(
		"request_rest",
		HTTPClient.METHOD_POST,
		FEED_RESULTS_TABLE,
		{},
		payload,
		headers
	)


func _merge_batch_into_cache(offset: int, batch: Array[Dictionary]) -> void:
	if batch.is_empty():
		return

	if _cached_feed_items.is_empty() and offset == 0:
		_cached_feed_items = batch.duplicate(true)
		_save_feed_cache()
		return

	var write_index: int = clampi(offset, 0, maxi(offset, _cached_feed_items.size()))
	for item_offset in batch.size():
		var cache_index: int = write_index + item_offset
		if cache_index < _cached_feed_items.size():
			_cached_feed_items[cache_index] = batch[item_offset].duplicate(true)
		else:
			_cached_feed_items.append(batch[item_offset].duplicate(true))

	_save_feed_cache()


func _save_feed_cache() -> void:
	_ensure_cache_directory()

	var payload: Dictionary = {
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"items": _to_json_safe(_cached_feed_items)
	}
	_write_json_file(FEED_CACHE_FILE_PATH, payload)


func _load_pending_results() -> Array[Dictionary]:
	var payload_variant: Variant = _read_json_file(PENDING_RESULTS_FILE_PATH)
	if not (payload_variant is Dictionary):
		return []

	var payload: Dictionary = payload_variant
	var queue_variant: Variant = payload.get("queue", [])
	if not (queue_variant is Array):
		return []

	var results: Array[Dictionary] = []
	var queue: Array = queue_variant
	for result_variant in queue:
		if not (result_variant is Dictionary):
			continue
		results.append(result_variant.duplicate(true))

	return results


func _save_pending_results() -> void:
	_ensure_cache_directory()
	var payload: Dictionary = {
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"queue": _to_json_safe(_pending_results)
	}
	_write_json_file(PENDING_RESULTS_FILE_PATH, payload)


func _extract_snapshot_from_row(row: Dictionary) -> Dictionary:
	var snapshot_variant: Variant = row.get("snapshot", null)
	var snapshot: Dictionary = {}

	if snapshot_variant is Dictionary:
		snapshot = snapshot_variant.duplicate(true)
	else:
		snapshot = row.duplicate(true)

	if snapshot.is_empty():
		return {}

	if not snapshot.has("map_config"):
		var map_config_variant: Variant = row.get("map_config", {})
		if map_config_variant is Dictionary:
			snapshot["map_config"] = map_config_variant

	if not snapshot.has("puffs"):
		var puffs_variant: Variant = row.get("puffs", [])
		if puffs_variant is Array:
			snapshot["puffs"] = puffs_variant

	if not snapshot.has("enemy_intents"):
		var intents_variant: Variant = row.get("enemy_intents", [])
		if intents_variant is Array:
			snapshot["enemy_intents"] = intents_variant

	if not snapshot.has("target_score"):
		snapshot["target_score"] = int(row.get("target_score", DEFAULT_TARGET_SCORE))

	var feed_item_id: String = str(snapshot.get("feed_item_id", row.get("id", ""))).strip_edges()
	if feed_item_id.is_empty():
		feed_item_id = _build_fallback_feed_item_id(snapshot)
	snapshot["feed_item_id"] = feed_item_id

	return _normalize_snapshot_for_runtime(snapshot)


func _normalize_snapshot_array(raw_items: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for item_variant in raw_items:
		if not (item_variant is Dictionary):
			continue
		var snapshot: Dictionary = _normalize_snapshot_for_runtime(item_variant)
		if snapshot.is_empty():
			continue
		normalized.append(snapshot)
	return normalized


func _normalize_snapshot_for_runtime(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot: Dictionary = raw_snapshot.duplicate(true)

	var map_config_variant: Variant = snapshot.get("map_config", {})
	if not (map_config_variant is Dictionary):
		return {}

	var puffs_variant: Variant = snapshot.get("puffs", [])
	if not (puffs_variant is Array):
		return {}

	snapshot["map_config"] = map_config_variant.duplicate(true)
	snapshot["puffs"] = _normalize_puffs(puffs_variant)
	snapshot["enemy_intents"] = _normalize_enemy_intents(snapshot.get("enemy_intents", []))
	snapshot["target_score"] = int(snapshot.get("target_score", DEFAULT_TARGET_SCORE))

	var feed_item_id: String = str(snapshot.get("feed_item_id", "")).strip_edges()
	if feed_item_id.is_empty():
		feed_item_id = _build_fallback_feed_item_id(snapshot)
	snapshot["feed_item_id"] = feed_item_id

	if snapshot["puffs"].is_empty():
		return {}

	return snapshot


func _normalize_puffs(raw_puffs: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for puff_variant in raw_puffs:
		if not (puff_variant is Dictionary):
			continue
		var puff: Dictionary = puff_variant.duplicate(true)
		var team: String = str(puff.get("team", "enemy")).strip_edges().to_lower()
		if team != "player" and team != "enemy":
			team = "enemy"

		normalized.append(
			{
				"name": str(puff.get("name", "Puff")),
				"team": team,
				"data_path": str(puff.get("data_path", FALLBACK_PUFF_DATA_PATH)),
				"cell": _to_cell(puff.get("cell", Vector2i.ZERO)),
				"hp": int(puff.get("hp", 0)),
				"max_hp": int(puff.get("max_hp", 0))
			}
		)

	return normalized


func _normalize_enemy_intents(raw_intents_variant: Variant) -> Array[Dictionary]:
	if not (raw_intents_variant is Array):
		return []

	var normalized: Array[Dictionary] = []
	var raw_intents: Array = raw_intents_variant
	for intent_variant in raw_intents:
		if not (intent_variant is Dictionary):
			continue
		var intent: Dictionary = intent_variant

		var normalized_skill_cells: Array[Vector2i] = []
		var skill_cells_variant: Variant = intent.get("skill_cells", [])
		if skill_cells_variant is Array:
			var skill_cells: Array = skill_cells_variant
			for skill_cell_variant in skill_cells:
				normalized_skill_cells.append(_to_cell(skill_cell_variant))

		normalized.append(
			{
				"action": StringName(str(intent.get("action", "wait")).to_lower()),
				"actor_cell": _to_cell(intent.get("actor_cell", Vector2i.ZERO)),
				"move_cell": _to_cell(intent.get("move_cell", intent.get("actor_cell", Vector2i.ZERO))),
				"target_cell": _to_cell(intent.get("target_cell", intent.get("actor_cell", Vector2i.ZERO))),
				"skill_cells": normalized_skill_cells,
				"direction": _to_cell(intent.get("direction", Vector2i.ZERO))
			}
		)

	return normalized


func _build_result_payload(snapshot: Dictionary, score: int, cycle_duration_seconds: float) -> Dictionary:
	var feed_item_id: String = str(snapshot.get("feed_item_id", "")).strip_edges()
	if feed_item_id.is_empty():
		feed_item_id = _build_fallback_feed_item_id(snapshot)

	var supabase_client: Node = _resolve_supabase_client()
	var authenticated_user_id: String = ""
	var guest_id: String = ""
	if supabase_client != null:
		if supabase_client.has_method("get_authenticated_user_id"):
			authenticated_user_id = str(supabase_client.call("get_authenticated_user_id"))
		if supabase_client.has_method("get_guest_id"):
			guest_id = str(supabase_client.call("get_guest_id"))

	return {
		"feed_item_id": feed_item_id,
		"score": score,
		"cycle_duration_seconds": cycle_duration_seconds,
		"user_id": authenticated_user_id,
		"guest_id": guest_id,
		"completed_at_unix": int(Time.get_unix_time_from_system())
	}


func _build_fallback_feed_item_id(snapshot: Dictionary) -> String:
	var map_hash_source: String = JSON.stringify(_to_json_safe(snapshot.get("map_config", {})))
	var puffs_hash_source: String = JSON.stringify(_to_json_safe(snapshot.get("puffs", [])))
	var summary_hash: int = hash(map_hash_source + puffs_hash_source)
	return "local_%d" % absi(summary_hash)


func _resolve_supabase_client() -> Node:
	return get_node_or_null("/root/SupabaseClient")


func _ensure_cache_directory() -> void:
	var dir_error: int = DirAccess.make_dir_recursive_absolute(CACHE_DIRECTORY_PATH)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_warning("Unable to create feed cache directory: %s" % CACHE_DIRECTORY_PATH)


func _read_json_file(path: String) -> Variant:
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
	var parse_error: int = parser.parse(raw_text)
	if parse_error != OK:
		push_warning("Failed to parse JSON file: %s" % path)
		return null

	return parser.data


func _write_json_file(path: String, payload: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to write JSON file: %s" % path)
		return

	file.store_string(JSON.stringify(payload))
	file.close()


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
