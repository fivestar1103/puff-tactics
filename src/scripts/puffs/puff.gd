extends Area2D
class_name Puff

const PLACEHOLDER_TEXTURE_SIZE: int = 72
const PLACEHOLDER_RADIUS: float = 26.0
const PLACEHOLDER_BORDER_WIDTH: float = 2.0

@export var puff_data: Resource
@export var grid_cell: Vector2i = Vector2i.ZERO
@export var battle_map_path: NodePath

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var _battle_map: Node2D


func _ready() -> void:
	_resolve_battle_map_reference()
	_build_placeholder_visual()
	_configure_collision_shape()
	_update_position_from_cell()


func set_puff_data(new_puff_data: Resource) -> void:
	puff_data = new_puff_data
	if is_node_ready():
		_build_placeholder_visual()


func set_grid_cell(cell: Vector2i) -> void:
	grid_cell = cell
	_update_position_from_cell()


func set_battle_map(battle_map: Node2D) -> void:
	_battle_map = battle_map
	_update_position_from_cell()


func _resolve_battle_map_reference() -> void:
	if battle_map_path.is_empty():
		return

	var candidate: Node = get_node_or_null(battle_map_path)
	if candidate is Node2D:
		_battle_map = candidate


func _build_placeholder_visual() -> void:
	var fill_color: Color = _resolve_element_color()
	sprite_2d.texture = _create_placeholder_texture(fill_color)
	sprite_2d.offset = Vector2(0.0, -34.0)


func _configure_collision_shape() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = PLACEHOLDER_RADIUS
	collision_shape_2d.shape = shape
	collision_shape_2d.position = Vector2(0.0, -34.0)


func _update_position_from_cell() -> void:
	if not is_node_ready():
		return
	if _battle_map == null:
		return
	var tile_map_layer: TileMapLayer = _resolve_tile_map_layer()
	if tile_map_layer == null:
		return

	var tile_local_position: Vector2 = tile_map_layer.map_to_local(grid_cell)
	global_position = tile_map_layer.to_global(tile_local_position)


func _resolve_element_color() -> Color:
	if puff_data == null:
		return Constants.COLOR_BG_SOFT

	match _resolve_element():
		Constants.Element.FIRE:
			return Constants.COLOR_FIRE
		Constants.Element.WATER:
			return Constants.COLOR_WATER
		Constants.Element.GRASS:
			return Constants.COLOR_GRASS
		Constants.Element.WIND:
			return Constants.COLOR_WIND
		Constants.Element.STAR:
			return Constants.COLOR_STAR
		_:
			return Constants.COLOR_BG_SOFT


func _resolve_tile_map_layer() -> TileMapLayer:
	if _battle_map is TileMapLayer:
		return _battle_map
	return _battle_map.get_node_or_null("TileMapLayer")


func _resolve_element() -> int:
	if puff_data == null:
		return Constants.Element.STAR

	var element_variant: Variant = puff_data.get("element")
	if element_variant is int:
		return int(element_variant)
	return Constants.Element.STAR


func _create_placeholder_texture(fill_color: Color) -> Texture2D:
	var image: Image = Image.create(
		PLACEHOLDER_TEXTURE_SIZE,
		PLACEHOLDER_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center: Vector2 = Vector2(
		float(PLACEHOLDER_TEXTURE_SIZE) * 0.5,
		float(PLACEHOLDER_TEXTURE_SIZE) * 0.5
	)
	var outline_color: Color = fill_color.darkened(0.25)

	for y in PLACEHOLDER_TEXTURE_SIZE:
		for x in PLACEHOLDER_TEXTURE_SIZE:
			var pixel_center: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance_to_center: float = pixel_center.distance_to(center)
			if distance_to_center <= PLACEHOLDER_RADIUS:
				var pixel_color: Color = fill_color
				if distance_to_center > (PLACEHOLDER_RADIUS - PLACEHOLDER_BORDER_WIDTH):
					pixel_color = outline_color
				image.set_pixel(x, y, pixel_color)

	return ImageTexture.create_from_image(image)
