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
		"random_effects": [],
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
		"random_effects": [],
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
		"random_effects": [],
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
		"random_effects": [],
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
		"random_effects": [],
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
		"random_effects": ["heal", "buff", "teleport"],
		"notes": "On step, triggers a random effect: heal, buff, or teleport."
	}
}

const TERRAIN_COLORS: Dictionary = {
	"cloud": Color(0.89, 0.94, 1.0, 1.0),
	"high_cloud": Color(0.77, 0.86, 0.99, 1.0),
	"cotton_candy": Color(0.98, 0.72, 0.88, 1.0),
	"puddle": Color(0.50, 0.76, 0.98, 1.0),
	"cliff": Color(0.67, 0.68, 0.78, 1.0),
	"mushroom": Color(0.87, 0.73, 0.96, 1.0)
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
		_draw_isometric_diamond(image, terrain_index * TILE_PIXEL_SIZE.x, terrain_color, terrain_type)

	return ImageTexture.create_from_image(image)



func _draw_isometric_diamond(image: Image, offset_x: int, fill_color: Color, terrain_type: String) -> void:
	var light_tint: Color = fill_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.42)
	var dark_tint: Color = fill_color.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.24)
	var half_width: float = float(TILE_PIXEL_SIZE.x) * 0.5
	var half_height: float = float(TILE_PIXEL_SIZE.y) * 0.5
	var border_limit: float = 0.93
	var border_darkness: float = 0.28
	if terrain_type == "cliff":
		border_limit = 0.91
		border_darkness = 0.34

	for y in TILE_PIXEL_SIZE.y:
		for x in TILE_PIXEL_SIZE.x:
			var normalized_x: float = absf((float(x) + 0.5 - half_width) / half_width)
			var normalized_y: float = absf((float(y) + 0.5 - half_height) / half_height)
			var distance_to_center: float = normalized_x + normalized_y
			if distance_to_center <= 1.0:
				var gradient_t: float = float(y) / float(TILE_PIXEL_SIZE.y - 1)
				var tile_color: Color = fill_color
				if gradient_t < 0.5:
					tile_color = fill_color.lerp(light_tint, (0.5 - gradient_t) * 0.35)
				else:
					tile_color = fill_color.lerp(dark_tint, (gradient_t - 0.5) * 0.35)

				if distance_to_center > border_limit:
					tile_color = tile_color.darkened(border_darkness)
				elif distance_to_center > 0.88:
					tile_color = tile_color.darkened(0.16)
				elif y < int(TILE_PIXEL_SIZE.y * 0.30):
					tile_color = tile_color.lightened(0.12)

				image.set_pixel(offset_x + x, y, tile_color)

	_draw_terrain_symbol(image, offset_x, terrain_type, fill_color)


func _draw_terrain_symbol(image: Image, offset_x: int, terrain_type: String, fill_color: Color) -> void:
	var center_x: int = offset_x + int(TILE_PIXEL_SIZE.x / 2)
	var center_y: int = int(TILE_PIXEL_SIZE.y / 2)

	match terrain_type:
		"cloud":
			_draw_cloud_symbol(image, center_x, center_y)
		"high_cloud":
			_draw_high_cloud_symbol(image, center_x, center_y)
		"cotton_candy":
			_draw_cotton_candy_symbol(image, center_x, center_y)
		"puddle":
			_draw_puddle_symbol(image, center_x, center_y)
		"cliff":
			_draw_cliff_symbol(image, center_x, center_y, fill_color)
		"mushroom":
			_draw_mushroom_symbol(image, center_x, center_y)
		_:
			pass


func _set_terrain_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0:
		return
	if x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)


func _draw_disk(image: Image, center_x: int, center_y: int, radius: int, color: Color) -> void:
	var radius_squared: int = radius * radius
	for local_y in range(-radius, radius + 1):
		for local_x in range(-radius, radius + 1):
			if local_x * local_x + local_y * local_y <= radius_squared:
				_set_terrain_pixel(image, center_x + local_x, center_y + local_y, color)


func _draw_cloud_symbol(image: Image, center_x: int, center_y: int) -> void:
	var color: Color = Color(1.0, 1.0, 1.0, 0.94)
	_draw_disk(image, center_x, center_y - 2, 4, color)
	_draw_disk(image, center_x - 6, center_y + 1, 3, color)
	_draw_disk(image, center_x + 6, center_y + 1, 3, color)
	_draw_disk(image, center_x - 1, center_y + 4, 2, color)
	_set_terrain_pixel(image, center_x + 2, center_y - 5, Color(1.0, 1.0, 1.0, 0.85))


func _draw_high_cloud_symbol(image: Image, center_x: int, center_y: int) -> void:
	var color: Color = Color(1.0, 0.95, 0.5, 0.95)
	var base_x: int = center_x - 1
	var base_y: int = center_y + 11
	for local_y in range(14):
		var y: int = base_y - local_y
		_set_terrain_pixel(image, base_x, y, color)
		_set_terrain_pixel(image, base_x + 1, y, color)

	for row in range(0, 5):
		for column in range(-4, 5):
			if abs(column) + row <= 4:
				_set_terrain_pixel(image, center_x + column, center_y - 7 - row, color)


func _draw_cotton_candy_symbol(image: Image, center_x: int, center_y: int) -> void:
	var color: Color = Color(1.0, 0.8, 0.95, 0.95)
	for i in range(48):
		var t: float = float(i) / 47.0
		var angle: float = t * 6.28318 * 2.0
		var radius: float = t * 13.0
		var px: int = center_x + int(radius * cos(angle))
		var py: int = center_y + int(radius * sin(angle) * 0.6)
		_set_terrain_pixel(image, px, py, color)
		_set_terrain_pixel(image, px + 1, py, color)
		if i % 3 == 0:
			_set_terrain_pixel(image, px - 1, py + 1, Color(1.0, 0.73, 0.93, 0.75))


func _draw_puddle_symbol(image: Image, center_x: int, center_y: int) -> void:
	var color: Color = Color(0.95, 1.0, 1.0, 0.95)
	for line in range(3):
		var line_y: int = center_y - 4 + line * 6
		for x in range(-18, 19):
			var wave: int = int(round(sin(float(x) / 3.4 + float(line) * 0.7) * 2.0))
			_set_terrain_pixel(image, center_x + x, line_y + wave, color)
			_set_terrain_pixel(image, center_x + x, line_y + wave + 1, Color(color.r, color.g, color.b, 0.65))


func _draw_cliff_symbol(image: Image, center_x: int, center_y: int, fill_color: Color) -> void:
	var symbol_color: Color = fill_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.3)
	var start_y: int = center_y - 11
	var total_rows: int = 16
	for row in range(total_rows):
		var progress: float = float(row) / float(total_rows - 1)
		var half_width: int = int(lerp(15.0, 2.0, progress))
		var row_y: int = start_y + row
		for dx in range(-half_width, half_width + 1):
			_set_terrain_pixel(image, center_x + dx, row_y, symbol_color)

	_set_terrain_pixel(image, center_x, start_y + total_rows - 1, symbol_color.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.5))


func _draw_mushroom_symbol(image: Image, center_x: int, center_y: int) -> void:
	var cap_color: Color = Color(1.0, 0.78, 0.95, 0.95)
	var stem_color: Color = Color(0.88, 0.72, 0.46, 0.95)
	for local_y in range(-13, 1):
		var half_width: int = 9 - int(abs(float(local_y)) * 0.55)
		for dx in range(-half_width, half_width + 1):
			_set_terrain_pixel(image, center_x + dx, center_y + local_y, cap_color)

	for stem_y in range(1, 12):
		_set_terrain_pixel(image, center_x, center_y + stem_y, stem_color)
		if stem_y % 2 == 0:
			_set_terrain_pixel(image, center_x + 1, center_y + stem_y, Color(stem_color.r, stem_color.g, stem_color.b, 0.74))


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
