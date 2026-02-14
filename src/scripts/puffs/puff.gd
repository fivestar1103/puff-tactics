extends Area2D
class_name Puff

const PLACEHOLDER_TEXTURE_SIZE: int = 72
const PLACEHOLDER_RADIUS: float = 26.0
const PLACEHOLDER_BORDER_WIDTH: float = 2.0

const ACCESSORY_SLOT_HAT: StringName = &"hat"
const ACCESSORY_SLOT_SCARF: StringName = &"scarf"
const ACCESSORY_SLOT_RIBBON: StringName = &"ribbon"

@export var puff_data: Resource
@export var grid_cell: Vector2i = Vector2i.ZERO
@export var battle_map_path: NodePath

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var hat_sprite: Sprite2D = $HatSprite
@onready var scarf_sprite: Sprite2D = $ScarfSprite
@onready var ribbon_sprite: Sprite2D = $RibbonSprite
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
	_apply_accessory_visuals(fill_color)


func _apply_accessory_visuals(base_color: Color) -> void:
	var slot_config: Array[Dictionary] = [
		{"slot": ACCESSORY_SLOT_HAT, "sprite": hat_sprite, "fallback": base_color.lightened(0.18)},
		{"slot": ACCESSORY_SLOT_SCARF, "sprite": scarf_sprite, "fallback": base_color.darkened(0.08)},
		{"slot": ACCESSORY_SLOT_RIBBON, "sprite": ribbon_sprite, "fallback": base_color.lightened(0.3)}
	]

	for slot_variant in slot_config:
		var slot_entry: Dictionary = slot_variant
		var slot_key: StringName = slot_entry.get("slot", ACCESSORY_SLOT_HAT)
		var sprite_variant: Variant = slot_entry.get("sprite")
		if not (sprite_variant is Sprite2D):
			continue
		var accessory_sprite: Sprite2D = sprite_variant
		accessory_sprite.offset = Vector2(0.0, -34.0)

		var accessory: Resource = _resolve_equipped_accessory(slot_key)
		if accessory == null:
			accessory_sprite.texture = null
			continue

		var fallback_color: Color = slot_entry.get("fallback", base_color)
		var tint_color: Color = _resolve_accessory_color(accessory, fallback_color)
		accessory_sprite.texture = _create_accessory_texture(slot_key, tint_color)


func _resolve_equipped_accessory(slot_key: StringName) -> Resource:
	if puff_data == null:
		return null

	if puff_data.has_method("get_equipped_accessories"):
		var equipped_variant: Variant = puff_data.call("get_equipped_accessories")
		if equipped_variant is Dictionary:
			var equipped: Dictionary = equipped_variant
			var slot_resource: Variant = equipped.get(slot_key, null)
			if slot_resource is Resource:
				return slot_resource

	match slot_key:
		ACCESSORY_SLOT_HAT:
			if puff_data.get("equipped_hat") is Resource:
				return puff_data.get("equipped_hat")
		ACCESSORY_SLOT_SCARF:
			if puff_data.get("equipped_scarf") is Resource:
				return puff_data.get("equipped_scarf")
		ACCESSORY_SLOT_RIBBON:
			if puff_data.get("equipped_ribbon") is Resource:
				return puff_data.get("equipped_ribbon")

	return null


func _resolve_accessory_color(accessory: Resource, fallback_color: Color) -> Color:
	if accessory == null:
		return fallback_color
	var tint_variant: Variant = accessory.get("tint_color")
	if tint_variant is Color:
		return tint_variant
	return fallback_color


func _create_accessory_texture(slot_key: StringName, tint_color: Color) -> Texture2D:
	match slot_key:
		ACCESSORY_SLOT_HAT:
			return _create_hat_texture(tint_color)
		ACCESSORY_SLOT_SCARF:
			return _create_scarf_texture(tint_color)
		ACCESSORY_SLOT_RIBBON:
			return _create_ribbon_texture(tint_color)
		_:
			return null


func _create_hat_texture(tint_color: Color) -> Texture2D:
	var image: Image = _create_empty_accessory_image()
	var brim_color: Color = tint_color.darkened(0.18)
	_paint_rect(image, 18, 14, 54, 21, brim_color)
	_paint_rect(image, 24, 6, 48, 16, tint_color)
	return ImageTexture.create_from_image(image)


func _create_scarf_texture(tint_color: Color) -> Texture2D:
	var image: Image = _create_empty_accessory_image()
	var fold_color: Color = tint_color.darkened(0.2)
	_paint_rect(image, 15, 39, 57, 48, tint_color)
	_paint_rect(image, 36, 47, 45, 60, fold_color)
	return ImageTexture.create_from_image(image)


func _create_ribbon_texture(tint_color: Color) -> Texture2D:
	var image: Image = _create_empty_accessory_image()
	var knot_color: Color = tint_color.darkened(0.22)
	_paint_rect(image, 14, 18, 25, 29, tint_color)
	_paint_rect(image, 29, 18, 40, 29, tint_color)
	_paint_rect(image, 24, 21, 30, 27, knot_color)
	return ImageTexture.create_from_image(image)


func _create_empty_accessory_image() -> Image:
	var image: Image = Image.create(
		PLACEHOLDER_TEXTURE_SIZE,
		PLACEHOLDER_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _paint_rect(image: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	if image == null:
		return
	var clamped_left: int = clampi(left, 0, PLACEHOLDER_TEXTURE_SIZE)
	var clamped_top: int = clampi(top, 0, PLACEHOLDER_TEXTURE_SIZE)
	var clamped_right: int = clampi(right, 0, PLACEHOLDER_TEXTURE_SIZE)
	var clamped_bottom: int = clampi(bottom, 0, PLACEHOLDER_TEXTURE_SIZE)

	for y in range(clamped_top, clamped_bottom):
		for x in range(clamped_left, clamped_right):
			image.set_pixel(x, y, color)


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
