extends Area2D
class_name Puff

const PLACEHOLDER_TEXTURE_SIZE: int = 128
const PLACEHOLDER_RADIUS: float = 48.0
const PLACEHOLDER_BORDER_WIDTH: float = 3.0
const ACCESSORY_REFERENCE_TEXTURE_SIZE: float = 72.0

const ACCESSORY_SLOT_HAT: StringName = &"hat"
const ACCESSORY_SLOT_SCARF: StringName = &"scarf"
const ACCESSORY_SLOT_RIBBON: StringName = &"ribbon"

@export var puff_data: Resource
@export var grid_cell: Vector2i = Vector2i.ZERO
@export var battle_map_path: NodePath
@export var team: StringName = &""

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


func set_team(side: StringName) -> void:
	team = side
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
	var ring_color: Color = _resolve_team_color()
	sprite_2d.texture = _create_placeholder_texture(fill_color, ring_color)
	sprite_2d.offset = Vector2(0.0, _placeholder_offset_y())
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
		accessory_sprite.offset = Vector2(0.0, _placeholder_offset_y())

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


func _accessory_scale() -> float:
	return float(PLACEHOLDER_TEXTURE_SIZE) / ACCESSORY_REFERENCE_TEXTURE_SIZE


func _paint_scaled_rect(image: Image, left: float, top: float, right: float, bottom: float, color: Color) -> void:
	var scale: float = _accessory_scale()
	var scaled_left: int = int(round(left * scale))
	var scaled_top: int = int(round(top * scale))
	var scaled_right: int = int(round(right * scale))
	var scaled_bottom: int = int(round(bottom * scale))
	_paint_rect(image, scaled_left, scaled_top, scaled_right, scaled_bottom, color)


func _create_hat_texture(tint_color: Color) -> Texture2D:
	var image: Image = _create_empty_accessory_image()
	var brim_color: Color = tint_color.darkened(0.18)
	_paint_scaled_rect(image, 18.0, 14.0, 54.0, 21.0, brim_color)
	_paint_scaled_rect(image, 24.0, 6.0, 48.0, 16.0, tint_color)
	return ImageTexture.create_from_image(image)


func _create_scarf_texture(tint_color: Color) -> Texture2D:
	var image: Image = _create_empty_accessory_image()
	var fold_color: Color = tint_color.darkened(0.2)
	_paint_scaled_rect(image, 15.0, 39.0, 57.0, 48.0, tint_color)
	_paint_scaled_rect(image, 36.0, 47.0, 45.0, 60.0, fold_color)
	return ImageTexture.create_from_image(image)


func _create_ribbon_texture(tint_color: Color) -> Texture2D:
	var image: Image = _create_empty_accessory_image()
	var knot_color: Color = tint_color.darkened(0.22)
	_paint_scaled_rect(image, 14.0, 18.0, 25.0, 29.0, tint_color)
	_paint_scaled_rect(image, 29.0, 18.0, 40.0, 29.0, tint_color)
	_paint_scaled_rect(image, 24.0, 21.0, 30.0, 27.0, knot_color)
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


func _configure_collision_shape() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = PLACEHOLDER_RADIUS
	collision_shape_2d.shape = shape
	collision_shape_2d.position = Vector2(0.0, _placeholder_offset_y())


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


func _resolve_team_color() -> Color:
	var team_name: String = String(team).to_lower()
	if team_name.is_empty():
		var node_name: String = name.to_lower()
		if node_name.find("enemy") >= 0:
			return Constants.COLOR_TEAM_ENEMY
		if node_name.find("player") >= 0:
			return Constants.COLOR_TEAM_PLAYER
		return Constants.COLOR_TEAM_PLAYER

	if team_name == "player" or team_name == "friendly":
		return Constants.COLOR_TEAM_PLAYER
	if team_name == "enemy":
		return Constants.COLOR_TEAM_ENEMY
	return Constants.COLOR_TEAM_PLAYER


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


func _placeholder_offset_y() -> float:
	return -float(PLACEHOLDER_TEXTURE_SIZE) * 0.5 + 2.0


func _create_placeholder_texture(fill_color: Color, ring_color: Color) -> Texture2D:
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

	for y in PLACEHOLDER_TEXTURE_SIZE:
		for x in PLACEHOLDER_TEXTURE_SIZE:
			var pixel_center: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance_to_center: float = pixel_center.distance_to(center)
			if distance_to_center <= PLACEHOLDER_RADIUS:
				if distance_to_center > (PLACEHOLDER_RADIUS - PLACEHOLDER_BORDER_WIDTH):
					image.set_pixel(x, y, ring_color)
				else:
					image.set_pixel(x, y, fill_color)

	var face_dark: Color = fill_color.darkened(0.15)
	var blush_color: Color = Color8(251, 168, 198, 200)
	_paint_kawaii_face(image, face_dark, blush_color)
	_paint_element_badge(image, _resolve_element_color())

	return ImageTexture.create_from_image(image)


func _paint_kawaii_face(image: Image, face_color: Color, blush_color: Color) -> void:
	var center_x: int = PLACEHOLDER_TEXTURE_SIZE / 2
	var eye_y: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.35))
	var eye_spacing: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.18))
	var eye_radius_x: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.055))
	var eye_radius_y: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.048))
	var eye_color: Color = Color(0.12, 0.12, 0.12, 1.0)

	_paint_ellipse(image, center_x - eye_spacing, eye_y, max(1, eye_radius_x), max(1, eye_radius_y), eye_color)
	_paint_ellipse(image, center_x + eye_spacing, eye_y, max(1, eye_radius_x), max(1, eye_radius_y), eye_color)

	var smile_center_y: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.58))
	var smile_half_width: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.17))
	var smile_curve: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.055))
	var smile_color: Color = face_color.darkened(0.24)
	for offset_x in range(-smile_half_width, smile_half_width + 1):
		var normalized: float = float(abs(offset_x)) / float(max(smile_half_width, 1))
		var y_offset: int = int(round(smile_curve * pow(1.0 - normalized, 1.4)))
		_set_pixel_safe(image, center_x + offset_x, smile_center_y + y_offset, smile_color)
		_set_pixel_safe(image, center_x + offset_x, smile_center_y + y_offset + 1, smile_color)

	var cheek_y: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.64))
	var cheek_radius_x: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.048))
	var cheek_radius_y: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.038))
	var cheek_dx: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.245))
	_paint_ellipse(image, center_x - cheek_dx, cheek_y, max(1, cheek_radius_x), max(1, cheek_radius_y), blush_color)
	_paint_ellipse(image, center_x + cheek_dx, cheek_y, max(1, cheek_radius_x), max(1, cheek_radius_y), blush_color)


func _paint_element_badge(image: Image, badge_color: Color) -> void:
	var badge_radius: int = int(max(10, round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.08)))
	var badge_x: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.75))
	var badge_y: int = int(round(float(PLACEHOLDER_TEXTURE_SIZE) * 0.77))
	var badge_outline: int = max(2, badge_radius - 1)
	_paint_diamond(image, badge_x, badge_y, badge_outline, Color8(255, 255, 255, 160))
	_paint_diamond(image, badge_x, badge_y, badge_radius, badge_color)


func _paint_diamond(image: Image, center_x: int, center_y: int, radius: int, color: Color) -> void:
	var clamped_radius: int = max(1, radius)
	for y in range(-clamped_radius, clamped_radius + 1):
		for x in range(-clamped_radius, clamped_radius + 1):
			if abs(x) + abs(y) <= clamped_radius:
				_set_pixel_safe(image, center_x + x, center_y + y, color)


func _paint_ellipse(image: Image, center_x: int, center_y: int, radius_x: int, radius_y: int, color: Color) -> void:
	if radius_x <= 0 or radius_y <= 0:
		return

	var radius_x_float: float = max(1.0, float(radius_x))
	var radius_y_float: float = max(1.0, float(radius_y))
	var radius_x_sq: float = radius_x_float * radius_x_float
	var radius_y_sq: float = radius_y_float * radius_y_float

	for y_offset in range(-radius_y, radius_y + 1):
		for x_offset in range(-radius_x, radius_x + 1):
			var normalized: float = (float(x_offset * x_offset) / radius_x_sq) + (float(y_offset * y_offset) / radius_y_sq)
			if normalized <= 1.0:
				_set_pixel_safe(image, center_x + x_offset, center_y + y_offset, color)


func _paint_rect(image: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	if image == null:
		return
	var clamped_left: int = clampi(left, 0, PLACEHOLDER_TEXTURE_SIZE)
	var clamped_top: int = clampi(top, 0, PLACEHOLDER_TEXTURE_SIZE)
	var clamped_right: int = clampi(right, 0, PLACEHOLDER_TEXTURE_SIZE)
	var clamped_bottom: int = clampi(bottom, 0, PLACEHOLDER_TEXTURE_SIZE)

	for y in range(clamped_top, clamped_bottom):
		for x in range(clamped_left, clamped_right):
			_set_pixel_safe(image, x, y, color)


func _set_pixel_safe(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0:
		return
	if x >= PLACEHOLDER_TEXTURE_SIZE or y >= PLACEHOLDER_TEXTURE_SIZE:
		return
	image.set_pixel(x, y, color)
