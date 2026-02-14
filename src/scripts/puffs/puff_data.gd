extends Resource
class_name PuffData

const ACCESSORY_DATA_SCRIPT: GDScript = preload("res://src/scripts/puffs/accessory_data.gd")

const STRONG_DAMAGE_MULTIPLIER: float = 1.25
const WEAK_DAMAGE_MULTIPLIER: float = 0.8
const NEUTRAL_DAMAGE_MULTIPLIER: float = 1.0

const SLOT_HAT: StringName = &"hat"
const SLOT_SCARF: StringName = &"scarf"
const SLOT_RIBBON: StringName = &"ribbon"

const ELEMENT_ADVANTAGE: Dictionary = {
	Constants.Element.FIRE: Constants.Element.GRASS,
	Constants.Element.GRASS: Constants.Element.WIND,
	Constants.Element.WIND: Constants.Element.WATER,
	Constants.Element.WATER: Constants.Element.FIRE
}

@export var display_name: StringName = &""
@export var element: int = Constants.Element.STAR
@export var puff_class: int = Constants.PuffClass.STAR
@export var move_range: int = 2
@export var attack_range: int = 1
@export var hp: int = 10
@export var attack: int = 3
@export var defense: int = 2
@export var unique_skill_id: StringName = &""

@export_range(1, 99, 1) var level: int = 1
@export var xp: int = 0
@export_range(10, 500, 1) var xp_to_next_level_base: int = 90
@export_range(0, 10, 1) var hp_growth_per_level: int = 2
@export_range(0, 5, 1) var attack_growth_per_level: int = 1
@export_range(0, 5, 1) var defense_growth_per_level: int = 1
@export_range(0, 10, 1) var move_range_growth_interval: int = 4
@export_range(0, 10, 1) var attack_range_growth_interval: int = 5

@export var equipped_hat: Resource
@export var equipped_scarf: Resource
@export var equipped_ribbon: Resource
@export var owned_accessory_paths: PackedStringArray = []


func get_damage_multiplier_against(defending_element: int) -> float:
	return get_damage_multiplier(element, defending_element)


static func get_damage_multiplier(attacking_element: int, defending_element: int) -> float:
	if attacking_element == Constants.Element.STAR or defending_element == Constants.Element.STAR:
		return NEUTRAL_DAMAGE_MULTIPLIER
	if attacking_element == defending_element:
		return NEUTRAL_DAMAGE_MULTIPLIER
	if ELEMENT_ADVANTAGE.get(attacking_element, -1) == defending_element:
		return STRONG_DAMAGE_MULTIPLIER
	if ELEMENT_ADVANTAGE.get(defending_element, -1) == attacking_element:
		return WEAK_DAMAGE_MULTIPLIER
	return NEUTRAL_DAMAGE_MULTIPLIER


func get_level() -> int:
	return maxi(1, level)


func get_xp_to_next_level() -> int:
	return maxi(10, xp_to_next_level_base + (get_level() - 1) * 35)


func add_xp(amount: int) -> Dictionary:
	if amount <= 0:
		return {
			"xp_added": 0,
			"gained_levels": 0,
			"new_level": get_level(),
			"xp": maxi(0, xp),
			"xp_to_next": get_xp_to_next_level(),
			"leveled_up": false
		}

	level = get_level()
	xp = maxi(0, xp) + amount

	var gained_levels: int = 0
	var xp_to_next: int = get_xp_to_next_level()
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		gained_levels += 1
		xp_to_next = get_xp_to_next_level()

	return {
		"xp_added": amount,
		"gained_levels": gained_levels,
		"new_level": get_level(),
		"xp": xp,
		"xp_to_next": xp_to_next,
		"leveled_up": gained_levels > 0
	}


func get_effective_hp() -> int:
	var level_growth: int = hp_growth_per_level * (get_level() - 1)
	return maxi(1, hp + level_growth + _sum_accessory_bonus(&"hp"))


func get_effective_attack() -> int:
	var level_growth: int = attack_growth_per_level * (get_level() - 1)
	return maxi(1, attack + level_growth + _sum_accessory_bonus(&"attack"))


func get_effective_defense() -> int:
	var level_growth: int = defense_growth_per_level * (get_level() - 1)
	return maxi(0, defense + level_growth + _sum_accessory_bonus(&"defense"))


func get_effective_move_range() -> int:
	var level_growth: int = _interval_growth(move_range_growth_interval)
	return maxi(1, move_range + level_growth + _sum_accessory_bonus(&"move_range"))


func get_effective_attack_range() -> int:
	var level_growth: int = _interval_growth(attack_range_growth_interval)
	return maxi(1, attack_range + level_growth + _sum_accessory_bonus(&"attack_range"))


func get_equipped_accessories() -> Dictionary:
	return {
		SLOT_HAT: equipped_hat,
		SLOT_SCARF: equipped_scarf,
		SLOT_RIBBON: equipped_ribbon
	}


func equip_accessory(accessory: Resource) -> bool:
	if not _is_accessory_resource(accessory):
		return false

	var slot_key: StringName = _get_accessory_slot_key(accessory)
	if slot_key == &"":
		return false

	_set_equipped_accessory(slot_key, accessory)
	return true


func unequip_slot(slot_key: StringName) -> void:
	_set_equipped_accessory(slot_key, null)


func add_owned_accessory_path(accessory_path: String) -> void:
	if accessory_path.is_empty():
		return
	if owned_accessory_paths.has(accessory_path):
		return
	owned_accessory_paths.append(accessory_path)


func get_owned_accessory_paths() -> PackedStringArray:
	return owned_accessory_paths.duplicate()


func _interval_growth(interval: int) -> int:
	if interval <= 0:
		return 0
	return int((get_level() - 1) / interval)


func _sum_accessory_bonus(stat_key: StringName) -> int:
	var total_bonus: int = 0
	for slot_variant in get_equipped_accessories().values():
		if not (slot_variant is Resource):
			continue
		var accessory: Resource = slot_variant
		if accessory.has_method("get_bonus_for_stat"):
			total_bonus += int(accessory.call("get_bonus_for_stat", stat_key))
	return total_bonus


func _is_accessory_resource(accessory: Resource) -> bool:
	if accessory == null:
		return false
	if accessory.get_script() == ACCESSORY_DATA_SCRIPT:
		return true
	return accessory.has_method("get_slot_key") and accessory.has_method("get_bonus_for_stat")


func _get_accessory_slot_key(accessory: Resource) -> StringName:
	if accessory == null:
		return &""
	if not accessory.has_method("get_slot_key"):
		return &""

	var slot_variant: Variant = accessory.call("get_slot_key")
	var slot_key: StringName = StringName(str(slot_variant))
	if slot_key != SLOT_HAT and slot_key != SLOT_SCARF and slot_key != SLOT_RIBBON:
		return &""
	return slot_key


func _set_equipped_accessory(slot_key: StringName, accessory: Resource) -> void:
	if slot_key == SLOT_HAT:
		equipped_hat = accessory
		return
	if slot_key == SLOT_SCARF:
		equipped_scarf = accessory
		return
	if slot_key == SLOT_RIBBON:
		equipped_ribbon = accessory
