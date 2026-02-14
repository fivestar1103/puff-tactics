extends Node

signal feed_item_completed(score: int)
signal puff_moved(puff_id: StringName, from_cell: Vector2i, to_cell: Vector2i)
signal puff_bumped(puff_id: StringName, direction: Vector2i)
signal turn_ended(turn_number: int)
signal battle_ended(result: StringName)
