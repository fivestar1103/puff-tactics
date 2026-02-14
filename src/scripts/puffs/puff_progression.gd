extends Node

signal progression_updated(reason: StringName, payload: Dictionary)

const PUFF_DATA_SCRIPT: GDScript = preload("res://src/scripts/puffs/puff_data.gd")
const SLOT_HAT: StringName = &"hat"
const SLOT_SCARF: StringName = &"scarf"
const SLOT_RIBBON: StringName = &"ribbon"

const PLAYER_BASE_PUFF_PATHS: Array[String] = [
	"res://src/resources/puffs/base/cloud_tank.tres",
	"res://src/resources/puffs/base/flame_melee.tres",
	"res://src/resources/puffs/base/droplet_ranged.tres",
	"res://src/resources/puffs/base/leaf_healer.tres",
	"res://src/resources/puffs/base/whirl_mobility.tres",
	"res://src/resources/puffs/base/star_wildcard.tres"
]

const INITIAL_STORY_UNLOCKED_PUFF_PATHS: Array[String] = [
	"res://src/resources/puffs/base/cloud_tank.tres",
	"res://src/resources/puffs/base/flame_melee.tres"
]

const STARTING_ACCESSORY_PATHS: Array[String] = [
	"res://src/resources/accessories/hats/candy_cap.tres",
	"res://src/resources/accessories/hats/moss_hood.tres",
	"res://src/resources/accessories/scarves/flare_scarf.tres",
	"res://src/resources/accessories/scarves/mist_wrap.tres",
	"res://src/resources/accessories/ribbons/breeze_ribbon.tres",
	"res://src/resources/accessories/ribbons/comet_bow.tres"
]

const STARTING_LOADOUT_BY_PUFF_PATH: Dictionary = {
	"res://src/resources/puffs/base/cloud_tank.tres": {
		SLOT_HAT: "res://src/resources/accessories/hats/candy_cap.tres",
		SLOT_SCARF: "res://src/resources/accessories/scarves/mist_wrap.tres",
		SLOT_RIBBON: "res://src/resources/accessories/ribbons/breeze_ribbon.tres"
	},
	"res://src/resources/puffs/base/flame_melee.tres": {
		SLOT_HAT: "res://src/resources/accessories/hats/moss_hood.tres",
		SLOT_SCARF: "res://src/resources/accessories/scarves/flare_scarf.tres",
		SLOT_RIBBON: "res://src/resources/accessories/ribbons/comet_bow.tres"
	},
	"res://src/resources/puffs/base/droplet_ranged.tres": {
		SLOT_HAT: "res://src/resources/accessories/hats/candy_cap.tres",
		SLOT_SCARF: "res://src/resources/accessories/scarves/mist_wrap.tres",
		SLOT_RIBBON: "res://src/resources/accessories/ribbons/comet_bow.tres"
	},
	"res://src/resources/puffs/base/leaf_healer.tres": {
		SLOT_HAT: "res://src/resources/accessories/hats/moss_hood.tres",
		SLOT_SCARF: "res://src/resources/accessories/scarves/mist_wrap.tres",
		SLOT_RIBBON: "res://src/resources/accessories/ribbons/breeze_ribbon.tres"
	},
	"res://src/resources/puffs/base/whirl_mobility.tres": {
		SLOT_HAT: "res://src/resources/accessories/hats/candy_cap.tres",
		SLOT_SCARF: "res://src/resources/accessories/scarves/flare_scarf.tres",
		SLOT_RIBBON: "res://src/resources/accessories/ribbons/breeze_ribbon.tres"
	},
	"res://src/resources/puffs/base/star_wildcard.tres": {
		SLOT_HAT: "res://src/resources/accessories/hats/moss_hood.tres",
		SLOT_SCARF: "res://src/resources/accessories/scarves/flare_scarf.tres",
		SLOT_RIBBON: "res://src/resources/accessories/ribbons/comet_bow.tres"
	}
}

const FEED_SCORE_XP_DIVISOR: float = 11.0
const FEED_MIN_XP: int = 10
const BATTLE_WIN_XP: int = 55
const BATTLE_LOSS_XP: int = 24

var _signal_bus: Node
var _roster_by_path: Dictionary = {}
var _owned_accessory_paths: PackedStringArray = []
var _accessory_cache: Dictionary = {}
var _story_reward_claims: Dictionary = {}
var _story_unlocked_puff_paths: PackedStringArray = []


func _ready() -> void:
	_initialize_roster()
	_connect_signal_bus()


func build_runtime_puff_data(data_path: String) -> Resource:
	var source_variant: Variant = _roster_by_path.get(data_path, null)
	if source_variant is Resource:
		return source_variant.duplicate(true)

	var loaded_resource: Resource = load(data_path)
	if loaded_resource != null:
		return loaded_resource.duplicate(true)
	return null


func get_collection_snapshot() -> Dictionary:
	var puff_entries: Array[Dictionary] = []
	for data_path in PLAYER_BASE_PUFF_PATHS:
		var puff_data_variant: Variant = _roster_by_path.get(data_path, null)
		if not (puff_data_variant is Resource):
			continue
		var puff_data: Resource = puff_data_variant
		puff_entries.append(_build_puff_entry(data_path, puff_data))

	var accessory_entries: Array[Dictionary] = []
	for accessory_path in _owned_accessory_paths:
		accessory_entries.append(_build_accessory_entry(accessory_path))

	accessory_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("slot", "")) == str(b.get("slot", "")):
			return str(a.get("display_name", "")) < str(b.get("display_name", ""))
		return str(a.get("slot", "")) < str(b.get("slot", ""))
	)

	return {
		"puffs": puff_entries,
		"owned_accessories": accessory_entries
	}


func equip_accessory_for_puff(puff_data_path: String, accessory_path: String) -> bool:
	var puff_data_variant: Variant = _roster_by_path.get(puff_data_path, null)
	if not (puff_data_variant is Resource):
		return false

	var accessory: Resource = _load_accessory(accessory_path)
	if accessory == null:
		return false

	var puff_data: Resource = puff_data_variant
	if not puff_data.has_method("equip_accessory"):
		return false
	if not bool(puff_data.call("equip_accessory", accessory)):
		return false

	_add_owned_accessory_path(accessory_path)
	emit_signal("progression_updated", &"equipped_accessory", {
		"puff_path": puff_data_path,
		"accessory_path": accessory_path
	})
	return true


func is_story_chapter_reward_claimed(chapter_id: StringName) -> bool:
	if chapter_id == &"":
		return false
	return bool(_story_reward_claims.get(str(chapter_id), false))


func grant_story_chapter_rewards(chapter_id: StringName, reward_payload: Dictionary) -> Dictionary:
	var chapter_key: String = str(chapter_id)
	if chapter_key.is_empty():
		return {
			"granted": false,
			"already_claimed": false,
			"unlocked_puffs": [],
			"unlocked_accessories": []
		}
	if bool(_story_reward_claims.get(chapter_key, false)):
		return {
			"granted": false,
			"already_claimed": true,
			"unlocked_puffs": [],
			"unlocked_accessories": []
		}

	var unlocked_puffs: Array[String] = []
	var puff_paths_variant: Variant = reward_payload.get("puffs", [])
	if puff_paths_variant is Array:
		var puff_paths: Array = puff_paths_variant
		for puff_path_variant in puff_paths:
			var puff_path: String = str(puff_path_variant).strip_edges()
			if _unlock_story_puff_path(puff_path):
				unlocked_puffs.append(puff_path)

	var unlocked_accessories: Array[String] = []
	var accessory_paths_variant: Variant = reward_payload.get("accessories", [])
	if accessory_paths_variant is Array:
		var accessory_paths: Array = accessory_paths_variant
		for accessory_path_variant in accessory_paths:
			var accessory_path: String = str(accessory_path_variant).strip_edges()
			if _unlock_story_accessory_path(accessory_path):
				unlocked_accessories.append(accessory_path)

	_story_reward_claims[chapter_key] = true
	var result_payload: Dictionary = {
		"chapter_id": chapter_key,
		"unlocked_puffs": unlocked_puffs.duplicate(),
		"unlocked_accessories": unlocked_accessories.duplicate(),
		"already_claimed": false
	}
	emit_signal("progression_updated", &"story_rewards_unlocked", result_payload)

	return {
		"granted": true,
		"already_claimed": false,
		"unlocked_puffs": unlocked_puffs,
		"unlocked_accessories": unlocked_accessories
	}


func _initialize_roster() -> void:
	_roster_by_path.clear()
	_accessory_cache.clear()
	_owned_accessory_paths = []
	_story_reward_claims.clear()
	_story_unlocked_puff_paths = []
	for unlocked_path in INITIAL_STORY_UNLOCKED_PUFF_PATHS:
		if _story_unlocked_puff_paths.has(unlocked_path):
			continue
		_story_unlocked_puff_paths.append(unlocked_path)

	for accessory_path in STARTING_ACCESSORY_PATHS:
		_add_owned_accessory_path(accessory_path)

	for data_path in PLAYER_BASE_PUFF_PATHS:
		var base_data: Resource = load(data_path)
		if base_data == null:
			continue
		var runtime_data: Resource = base_data.duplicate(true)
		if runtime_data == null:
			continue

		if runtime_data.get_script() != PUFF_DATA_SCRIPT and not runtime_data.has_method("add_xp"):
			continue

		runtime_data.set("level", maxi(1, int(runtime_data.get("level"))))
		runtime_data.set("xp", maxi(0, int(runtime_data.get("xp"))))

		for accessory_path in _owned_accessory_paths:
			if runtime_data.has_method("add_owned_accessory_path"):
				runtime_data.call("add_owned_accessory_path", accessory_path)

		_apply_starting_loadout(data_path, runtime_data)
		_roster_by_path[data_path] = runtime_data

	emit_signal("progression_updated", &"initialized", {
		"puff_count": _roster_by_path.size(),
		"owned_accessory_count": _owned_accessory_paths.size(),
		"story_unlocked_puff_count": _story_unlocked_puff_paths.size()
	})


func _apply_starting_loadout(data_path: String, puff_data: Resource) -> void:
	if puff_data == null:
		return
	if not puff_data.has_method("equip_accessory"):
		return

	var loadout_variant: Variant = STARTING_LOADOUT_BY_PUFF_PATH.get(data_path, {})
	if not (loadout_variant is Dictionary):
		return
	var loadout: Dictionary = loadout_variant

	for accessory_path_variant in loadout.values():
		var accessory_path: String = str(accessory_path_variant)
		var accessory: Resource = _load_accessory(accessory_path)
		if accessory == null:
			continue
		puff_data.call("equip_accessory", accessory)


func _connect_signal_bus() -> void:
	_signal_bus = get_node_or_null("/root/SignalBus")
	if _signal_bus == null:
		return
	_connect_if_needed(_signal_bus, &"feed_item_completed", Callable(self, "_on_feed_item_completed"))
	_connect_if_needed(_signal_bus, &"battle_ended", Callable(self, "_on_battle_ended"))


func _on_feed_item_completed(score: int) -> void:
	var feed_xp: int = maxi(FEED_MIN_XP, int(round(float(score) / FEED_SCORE_XP_DIVISOR)))
	_grant_roster_xp(feed_xp, &"feed", {"score": score})


func _on_battle_ended(result: StringName) -> void:
	var xp_gain: int = BATTLE_WIN_XP if result == &"player" else BATTLE_LOSS_XP
	_grant_roster_xp(xp_gain, &"battle", {"result": str(result)})


func _grant_roster_xp(xp_gain: int, source: StringName, context: Dictionary = {}) -> void:
	if xp_gain <= 0:
		return
	if _roster_by_path.is_empty():
		return

	var level_ups: Array[Dictionary] = []
	for data_path_variant in _roster_by_path.keys():
		var data_path: String = str(data_path_variant)
		var puff_data_variant: Variant = _roster_by_path[data_path]
		if not (puff_data_variant is Resource):
			continue
		var puff_data: Resource = puff_data_variant
		if not puff_data.has_method("add_xp"):
			continue
		var result_variant: Variant = puff_data.call("add_xp", xp_gain)
		if not (result_variant is Dictionary):
			continue
		var level_result: Dictionary = result_variant
		if bool(level_result.get("leveled_up", false)):
			level_ups.append(
				{
					"puff_path": data_path,
					"new_level": int(level_result.get("new_level", 1)),
					"gained_levels": int(level_result.get("gained_levels", 0))
				}
			)

	var payload: Dictionary = {
		"source": str(source),
		"xp_gain_per_puff": xp_gain,
		"level_ups": level_ups,
		"context": context
	}
	emit_signal("progression_updated", &"xp_awarded", payload)


func _unlock_story_puff_path(puff_path: String) -> bool:
	if puff_path.is_empty():
		return false

	var unlocked_now: bool = false
	if not _story_unlocked_puff_paths.has(puff_path):
		_story_unlocked_puff_paths.append(puff_path)
		unlocked_now = true

	if _roster_by_path.has(puff_path):
		return unlocked_now

	var base_data: Resource = load(puff_path)
	if base_data == null:
		return unlocked_now

	var runtime_data: Resource = base_data.duplicate(true)
	if runtime_data == null:
		return unlocked_now
	if runtime_data.get_script() != PUFF_DATA_SCRIPT and not runtime_data.has_method("add_xp"):
		return unlocked_now

	runtime_data.set("level", maxi(1, int(runtime_data.get("level"))))
	runtime_data.set("xp", maxi(0, int(runtime_data.get("xp"))))
	for accessory_path in _owned_accessory_paths:
		if runtime_data.has_method("add_owned_accessory_path"):
			runtime_data.call("add_owned_accessory_path", accessory_path)

	_roster_by_path[puff_path] = runtime_data
	return true


func _unlock_story_accessory_path(accessory_path: String) -> bool:
	if accessory_path.is_empty():
		return false
	var accessory: Resource = _load_accessory(accessory_path)
	if accessory == null:
		return false

	var unlocked_now: bool = not _owned_accessory_paths.has(accessory_path)
	_add_owned_accessory_path(accessory_path)
	if not unlocked_now:
		return false

	for puff_data_variant in _roster_by_path.values():
		if not (puff_data_variant is Resource):
			continue
		var puff_data: Resource = puff_data_variant
		if puff_data.has_method("add_owned_accessory_path"):
			puff_data.call("add_owned_accessory_path", accessory_path)
	return true


func _build_puff_entry(data_path: String, puff_data: Resource) -> Dictionary:
	var equipped_names: Dictionary = {
		SLOT_HAT: "None",
		SLOT_SCARF: "None",
		SLOT_RIBBON: "None"
	}

	if puff_data.has_method("get_equipped_accessories"):
		var equipped_variant: Variant = puff_data.call("get_equipped_accessories")
		if equipped_variant is Dictionary:
			var equipped: Dictionary = equipped_variant
			for slot_key in [SLOT_HAT, SLOT_SCARF, SLOT_RIBBON]:
				var accessory_variant: Variant = equipped.get(slot_key, null)
				if accessory_variant is Resource:
					var accessory: Resource = accessory_variant
					equipped_names[slot_key] = str(accessory.get("display_name"))

	var level_value: int = int(puff_data.get("level"))
	var xp_value: int = int(puff_data.get("xp"))
	var xp_to_next: int = 0
	if puff_data.has_method("get_xp_to_next_level"):
		xp_to_next = int(puff_data.call("get_xp_to_next_level"))

	var effective_stats: Dictionary = {
		"hp": _call_stat_or_fallback(puff_data, "get_effective_hp", "hp"),
		"attack": _call_stat_or_fallback(puff_data, "get_effective_attack", "attack"),
		"defense": _call_stat_or_fallback(puff_data, "get_effective_defense", "defense"),
		"move_range": _call_stat_or_fallback(puff_data, "get_effective_move_range", "move_range"),
		"attack_range": _call_stat_or_fallback(puff_data, "get_effective_attack_range", "attack_range")
	}

	return {
		"data_path": data_path,
		"display_name": str(puff_data.get("display_name")),
		"level": maxi(1, level_value),
		"xp": maxi(0, xp_value),
		"xp_to_next": maxi(0, xp_to_next),
		"story_unlocked": _story_unlocked_puff_paths.has(data_path),
		"equipped": equipped_names,
		"effective_stats": effective_stats
	}


func _call_stat_or_fallback(resource: Resource, method_name: String, property_name: String) -> int:
	if resource.has_method(method_name):
		return int(resource.call(method_name))
	return int(resource.get(property_name))


func _build_accessory_entry(accessory_path: String) -> Dictionary:
	var accessory: Resource = _load_accessory(accessory_path)
	if accessory == null:
		return {
			"path": accessory_path,
			"display_name": accessory_path.get_file().trim_suffix(".tres"),
			"slot": "unknown",
			"bonuses": ""
		}

	var bonuses: Array[String] = []
	for stat_key in [&"hp", &"attack", &"defense", &"move_range", &"attack_range"]:
		if accessory.has_method("get_bonus_for_stat"):
			var bonus: int = int(accessory.call("get_bonus_for_stat", stat_key))
			if bonus != 0:
				bonuses.append("%s %+d" % [str(stat_key), bonus])

	var slot_key: String = "unknown"
	if accessory.has_method("get_slot_key"):
		slot_key = str(accessory.call("get_slot_key"))

	return {
		"path": accessory_path,
		"display_name": str(accessory.get("display_name")),
		"slot": slot_key,
		"bonuses": ", ".join(bonuses)
	}


func _add_owned_accessory_path(accessory_path: String) -> void:
	if accessory_path.is_empty():
		return
	if _owned_accessory_paths.has(accessory_path):
		return
	_owned_accessory_paths.append(accessory_path)


func _load_accessory(accessory_path: String) -> Resource:
	if _accessory_cache.has(accessory_path):
		var cached_variant: Variant = _accessory_cache[accessory_path]
		if cached_variant is Resource:
			return cached_variant

	var loaded_resource: Resource = load(accessory_path)
	if loaded_resource == null:
		return null
	_accessory_cache[accessory_path] = loaded_resource
	return loaded_resource


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
