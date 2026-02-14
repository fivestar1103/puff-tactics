extends Node


func create_panel_stylebox(bg_color: Color, corner_radius: int, border_color: Color) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	stylebox.corner_radius_top_left = corner_radius
	stylebox.corner_radius_top_right = corner_radius
	stylebox.corner_radius_bottom_left = corner_radius
	stylebox.corner_radius_bottom_right = corner_radius
	stylebox.border_color = border_color
	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_width_bottom = 1
	return stylebox


func create_button_styleboxes(base_color: Color, font_color: Color, corner_radius: int) -> Dictionary:
	var normal := create_panel_stylebox(base_color, corner_radius, Color(1.0, 1.0, 1.0, 0.0))
	var hover := create_panel_stylebox(base_color.lightened(0.08), corner_radius, font_color)
	var pressed := create_panel_stylebox(base_color.darkened(0.12), corner_radius, font_color)
	var disabled := create_panel_stylebox(base_color.darkened(0.2), corner_radius, Color(1.0, 1.0, 1.0, 0.15))

	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"disabled": disabled
	}


func apply_button_theme(button: Button, base_color: Color, font_color: Color, min_size: Vector2, font_size: int) -> void:
	var styleboxes := create_button_styleboxes(base_color, font_color, 16)
	button.add_theme_stylebox_override("normal", styleboxes["normal"])
	button.add_theme_stylebox_override("hover", styleboxes["hover"])
	button.add_theme_stylebox_override("pressed", styleboxes["pressed"])
	button.add_theme_stylebox_override("disabled", styleboxes["disabled"])
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.05))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.1))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.45))
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = min_size


func apply_label_theme(label: Label, font_size: int, font_color: Color) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", font_size)


func create_separator_stylebox(color: Color, thickness: float) -> StyleBoxLine:
	var separator := StyleBoxLine.new()
	separator.color = color
	separator.thickness = thickness
	separator.vertical = false
	separator.grow_begin = 0
	separator.grow_end = 0
	return separator
