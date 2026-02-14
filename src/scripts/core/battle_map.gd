extends Node2D
class_name BattleMap

const TERRAIN_SOURCE_ID: int = 0
const TILE_PIXEL_SIZE: Vector2i = Vector2i(128, 64)

const TERRAIN_TYPES: Array[String] = [
	"cloud",
	"high_cloud",
	"cotton_candy",
	"puddle",
	"cliff",
	"mushroom"
]

const TERRAIN_EFFECTS: Dictionary = {
	"cloud": {
		"display_name": "Cloud",
		"attack_bonus": 0,
		"push_resistance": 0,
		"entry_move_penalty": 0,
		"water_attack_bonus": 0,
		"fire_attack_penalty": 0,
		"fall_ko_stun_turns": 0,
		"random_effects": PackedStringArray(),
		"notes": "Base tile with no special effect."
	},
	"high_cloud": {
		"display_name": "High Cloud",
		"attack_bonus": 1,
		"push_resistance": 1,
		"entry_move_penalty": 0,
		"water_attack_bonus": 0,
		"fire_attack_penalty": 0,
		"fall_ko_stun_turns": 0,
		"random_effects": PackedStringArray(),
		"notes": "High ground bonus: +1 attack and improved resistance to being pushed."
	},
	"cotton_candy": {
		"display_name": "Cotton Candy",
		"attack_bonus": 0,
		"push_resistance": 0,
		"entry_move_penalty": 1,
		"entry_buff": true,
		"water_attack_bonus": 0,
		"fire_attack_penalty": 0,
		"fall_ko_stun_turns": 0,
		"random_effects": PackedStringArray(),
		"notes": "Entering costs 1 extra movement and grants a temporary buff."
	},
	"puddle": {
		"display_name": "Puddle",
		"attack_bonus": 0,
		"push_resistance": 0,
		"entry_move_penalty": 0,
		"water_attack_bonus": 1,
		"fire_attack_penalty": 1,
		"fall_ko_stun_turns": 0,
		"random_effects": PackedStringArray(),
		"notes": "Water element attacks are boosted and fire element attacks are weakened."
	},
	"cliff": {
		"display_name": "Cliff",
		"attack_bonus": 0,
		"push_resistance": 0,
		"entry_move_penalty": 0,
		"water_attack_bonus": 0,
		"fire_attack_penalty": 0,
		"fall_ko_stun_turns": 1,
		"random_effects": PackedStringArray(),
		"notes": "Falling from a push applies a 1-turn knockout/stun."
	},
	"mushroom": {
		"display_name": "Mushroom",
		"attack_bonus": 0,
		"push_resistance": 0,
		"entry_move_penalty": 0,
		"water_attack_bonus": 0,
		"fire_attack_penalty": 0,
		"fall_ko_stun_turns": 0,
		"random_effects": PackedStringArray(["heal", "buff", "teleport"]),
		"notes": "On step, triggers a random effect: heal, buff, or teleport."
	}
}

const TERRAIN_COLORS: Dictionary = {
	"cloud": Color(0.92, 0.95, 1.0, 1.0),
	"high_cloud": Color(0.81, 0.89, 1.0, 1.0),
	"cotton_candy": Color(0.98, 0.74, 0.86, 1.0),
	"puddle": Color(0.52, 0.78, 1.0, 1.0),
	"cliff": Color(0.68, 0.68, 0.75, 1.0),
	"mushroom": Color(0.89, 0.75, 0.98, 1.0)
}

@onready var tile_map_layer: TileMapLayer = $TileMapLayer

var map_size: Vector2i = Constants.GRID_SIZE
var terrain_by_cell: Dictionary = {}


func _ready() -> void:
	tile_map_layer.tile_set = _build_tile_set()
	if terrain_by_cell.is_empty():
		load_map_from_config(_default_map_config())
	else:
		_render_map()


func load_map_from_json(map_json: String) -> bool:
	var parsed_config: Variant = JSON.parse_string(map_json)
	if not (parsed_config is Dictionary):
		return false
	return load_map_from_config(parsed_config)


func load_map_from_config(map_config: Dictionary) -> bool:
	var target_size: Vector2i = _resolve_map_size(map_config)
	if target_size.x <= 0 or target_size.y <= 0:
		return false

	var loaded_cells: Dictionary = {}
	if map_config.has("rows"):
		if not _load_rows_into_cells(map_config["rows"], target_size, loaded_cells):
			return false
	elif map_config.has("cells"):
		if not _load_cells_into_storage(map_config["cells"], target_size, loaded_cells):
			return false
	else:
		return false

	_fill_missing_cells_with_default(target_size, loaded_cells)
	map_size = target_size
	terrain_by_cell = loaded_cells

	if is_node_ready():
		_render_map()

	return true


func set_terrain_at(cell: Vector2i, terrain_type: String) -> void:
	if not _is_in_bounds(cell, map_size):
		return

	terrain_by_cell[cell] = _normalize_terrain_type(terrain_type)
	if is_node_ready():
		tile_map_layer.set_cell(cell, TERRAIN_SOURCE_ID, _atlas_coords_for_terrain(get_terrain_at(cell)))


func get_terrain_at(cell: Vector2i) -> String:
	if not terrain_by_cell.has(cell):
		return "cloud"
	return str(terrain_by_cell[cell])


func get_terrain_effect(terrain_type: String) -> Dictionary:
	var normalized_type: String = _normalize_terrain_type(terrain_type)
	return TERRAIN_EFFECTS[normalized_type].duplicate(true)


func get_terrain_effect_at(cell: Vector2i) -> Dictionary:
	return get_terrain_effect(get_terrain_at(cell))


func get_terrain_data() -> Dictionary:
	return terrain_by_cell.duplicate(true)


func _build_tile_set() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_size = TILE_PIXEL_SIZE

	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = _create_terrain_texture()
	atlas_source.texture_region_size = TILE_PIXEL_SIZE

	for terrain_index in TERRAIN_TYPES.size():
		atlas_source.create_tile(Vector2i(terrain_index, 0))

	tile_set.add_source(atlas_source, TERRAIN_SOURCE_ID)
	return tile_set


func _create_terrain_texture() -> Texture2D:
	var texture_width: int = TILE_PIXEL_SIZE.x * TERRAIN_TYPES.size()
	var image: Image = Image.create(texture_width, TILE_PIXEL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for terrain_index in TERRAIN_TYPES.size():
		var terrain_type: String = TERRAIN_TYPES[terrain_index]
		var terrain_color: Color = TERRAIN_COLORS[terrain_type]
		_draw_isometric_diamond(image, terrain_index * TILE_PIXEL_SIZE.x, terrain_color)

	return ImageTexture.create_from_image(image)


func _draw_isometric_diamond(image: Image, offset_x: int, fill_color: Color) -> void:
	var half_width: float = float(TILE_PIXEL_SIZE.x) * 0.5
	var half_height: float = float(TILE_PIXEL_SIZE.y) * 0.5
	var border_color: Color = fill_color.darkened(0.2)

	for y in TILE_PIXEL_SIZE.y:
		for x in TILE_PIXEL_SIZE.x:
			var normalized_x: float = absf((float(x) + 0.5 - half_width) / half_width)
			var normalized_y: float = absf((float(y) + 0.5 - half_height) / half_height)
			var distance_to_center: float = normalized_x + normalized_y
			if distance_to_center <= 1.0:
				var pixel_color: Color = fill_color if distance_to_center <= 0.9 else border_color
				image.set_pixel(offset_x + x, y, pixel_color)


func _render_map() -> void:
	tile_map_layer.clear()
	for y in map_size.y:
		for x in map_size.x:
			var cell: Vector2i = Vector2i(x, y)
			var terrain_type: String = get_terrain_at(cell)
			tile_map_layer.set_cell(cell, TERRAIN_SOURCE_ID, _atlas_coords_for_terrain(terrain_type))


func _resolve_map_size(map_config: Dictionary) -> Vector2i:
	var width: int = int(map_config.get("width", 0))
	var height: int = int(map_config.get("height", 0))

	if map_config.has("rows") and map_config["rows"] is Array:
		var rows: Array = map_config["rows"]
		if height <= 0:
			height = rows.size()
		if width <= 0:
			for row_variant in rows:
				if row_variant is Array:
					var row: Array = row_variant
					width = maxi(width, row.size())

	if width <= 0:
		width = Constants.GRID_WIDTH
	if height <= 0:
		height = Constants.GRID_HEIGHT

	return Vector2i(width, height)


func _load_rows_into_cells(rows_variant: Variant, target_size: Vector2i, out_cells: Dictionary) -> bool:
	if not (rows_variant is Array):
		return false

	var rows: Array = rows_variant
	if rows.is_empty():
		return false

	var max_row_count: int = mini(target_size.y, rows.size())
	for y in max_row_count:
		var row_variant: Variant = rows[y]
		if not (row_variant is Array):
			continue
		var row: Array = row_variant
		var max_column_count: int = mini(target_size.x, row.size())
		for x in max_column_count:
			var terrain_type: String = _normalize_terrain_type(row[x])
			out_cells[Vector2i(x, y)] = terrain_type

	return true


func _load_cells_into_storage(cells_variant: Variant, target_size: Vector2i, out_cells: Dictionary) -> bool:
	if not (cells_variant is Array):
		return false

	var cells: Array = cells_variant
	for cell_variant in cells:
		if not (cell_variant is Dictionary):
			continue
		var cell_data: Dictionary = cell_variant
		if not cell_data.has("x") or not cell_data.has("y"):
			continue

		var cell: Vector2i = Vector2i(int(cell_data["x"]), int(cell_data["y"]))
		if not _is_in_bounds(cell, target_size):
			continue

		var terrain_type: String = _normalize_terrain_type(cell_data.get("terrain", "cloud"))
		out_cells[cell] = terrain_type

	return true


func _fill_missing_cells_with_default(target_size: Vector2i, out_cells: Dictionary) -> void:
	for y in target_size.y:
		for x in target_size.x:
			var cell: Vector2i = Vector2i(x, y)
			if not out_cells.has(cell):
				out_cells[cell] = "cloud"


func _atlas_coords_for_terrain(terrain_type: String) -> Vector2i:
	var terrain_index: int = TERRAIN_TYPES.find(terrain_type)
	if terrain_index == -1:
		terrain_index = 0
	return Vector2i(terrain_index, 0)


func _normalize_terrain_type(raw_terrain: Variant) -> String:
	var terrain_type: String = str(raw_terrain).strip_edges().to_lower()
	if TERRAIN_TYPES.has(terrain_type):
		return terrain_type
	return "cloud"


func _is_in_bounds(cell: Vector2i, target_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < target_size.x and cell.y < target_size.y


func _default_map_config() -> Dictionary:
	return {
		"width": Constants.GRID_WIDTH,
		"height": Constants.GRID_HEIGHT,
		"rows": [
			["cloud", "high_cloud", "cotton_candy", "puddle", "mushroom"],
			["high_cloud", "cloud", "puddle", "mushroom", "cotton_candy"],
			["cotton_candy", "puddle", "cloud", "high_cloud", "cliff"],
			["puddle", "mushroom", "high_cloud", "cloud", "cliff"],
			["mushroom", "cotton_candy", "cliff", "cloud", "high_cloud"]
		]
	}
