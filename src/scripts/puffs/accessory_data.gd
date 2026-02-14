extends Resource
class_name AccessoryData

enum Slot {
	HAT,
	SCARF,
	RIBBON
}

const SLOT_KEY_BY_ENUM: Dictionary = {
	Slot.HAT: &"hat",
	Slot.SCARF: &"scarf",
	Slot.RIBBON: &"ribbon"
}

@export var accessory_id: StringName = &""
@export var display_name: StringName = &""
@export var slot: int = Slot.HAT
@export var bonus_hp: int = 0
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_move_range: int = 0
@export var bonus_attack_range: int = 0
@export var tint_color: Color = Color(0.98, 0.95, 0.84, 1.0)


func get_slot_key() -> StringName:
	return SLOT_KEY_BY_ENUM.get(slot, &"hat")


func get_bonus_for_stat(stat_key: StringName) -> int:
	match stat_key:
		&"hp":
			return bonus_hp
		&"attack":
			return bonus_attack
		&"defense":
			return bonus_defense
		&"move_range":
			return bonus_move_range
		&"attack_range":
			return bonus_attack_range
		_:
			return 0
