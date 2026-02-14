extends RefCounted
class_name BumpSystem

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT
]


func can_bump(attacker_cell: Vector2i, defender_cell: Vector2i) -> bool:
	return _is_cardinal_offset(defender_cell - attacker_cell)


func resolve_bump(
	attacker: Puff,
	defender: Puff,
	get_puff_at_cell: Callable,
	is_cell_in_bounds: Callable,
	is_cliff_cell: Callable
) -> Dictionary:
	if attacker == null or defender == null:
		return {
			"valid": false,
			"reason": "missing_puffs",
			"direction": Vector2i.ZERO,
			"pushes": []
		}

	var direction: Vector2i = defender.grid_cell - attacker.grid_cell
	if not _is_cardinal_offset(direction):
		return {
			"valid": false,
			"reason": "not_adjacent",
			"direction": direction,
			"pushes": []
		}

	var push_chain: Array[Puff] = _collect_push_chain(defender, direction, get_puff_at_cell)
	if push_chain.is_empty():
		return {
			"valid": false,
			"reason": "empty_chain",
			"direction": direction,
			"pushes": []
		}

	var pushes: Array[Dictionary] = []
	for index in range(push_chain.size() - 1, -1, -1):
		var pushed_puff: Puff = push_chain[index]
		var from_cell: Vector2i = pushed_puff.grid_cell
		var fell_from_cliff: bool = bool(is_cliff_cell.call(from_cell))

		if fell_from_cliff:
			pushes.append({
				"puff": pushed_puff,
				"from_cell": from_cell,
				"to_cell": from_cell,
				"fell_from_cliff": true
			})
			continue

		var to_cell: Vector2i = from_cell + direction
		if not bool(is_cell_in_bounds.call(to_cell)):
			return {
				"valid": false,
				"reason": "blocked_by_bounds",
				"direction": direction,
				"pushes": []
			}

		pushes.append({
			"puff": pushed_puff,
			"from_cell": from_cell,
			"to_cell": to_cell,
			"fell_from_cliff": false
		})

	return {
		"valid": true,
		"reason": "",
		"direction": direction,
		"pushes": pushes
	}


func _collect_push_chain(defender: Puff, direction: Vector2i, get_puff_at_cell: Callable) -> Array[Puff]:
	var push_chain: Array[Puff] = [defender]
	var current_puff: Puff = defender
	var guard: int = 0

	while guard < 64:
		guard += 1
		var next_cell: Vector2i = current_puff.grid_cell + direction
		var next_variant: Variant = get_puff_at_cell.call(next_cell)
		if not (next_variant is Puff):
			break

		var next_puff: Puff = next_variant
		if push_chain.has(next_puff):
			break

		push_chain.append(next_puff)
		current_puff = next_puff

	return push_chain


func _is_cardinal_offset(offset: Vector2i) -> bool:
	return CARDINAL_OFFSETS.has(offset)
