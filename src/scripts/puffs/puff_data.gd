extends Resource
class_name PuffData

const STRONG_DAMAGE_MULTIPLIER: float = 1.25
const WEAK_DAMAGE_MULTIPLIER: float = 0.8
const NEUTRAL_DAMAGE_MULTIPLIER: float = 1.0

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
