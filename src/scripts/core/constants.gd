extends Node
class_name Constants

enum Element {
	FIRE,
	WATER,
	GRASS,
	WIND,
	STAR
}

enum PuffClass {
	CLOUD,
	FLAME,
	DROPLET,
	LEAF,
	WHIRL,
	STAR
}

const GRID_WIDTH: int = 5
const GRID_HEIGHT: int = 5
const GRID_SIZE: Vector2i = Vector2i(GRID_WIDTH, GRID_HEIGHT)

const COLOR_BG_SOFT: Color = Color(0.96, 0.93, 0.98, 1.0)
const COLOR_FIRE: Color = Color(0.97, 0.45, 0.38, 1.0)
const COLOR_WATER: Color = Color(0.35, 0.67, 0.97, 1.0)
const COLOR_GRASS: Color = Color(0.45, 0.8, 0.47, 1.0)
const COLOR_WIND: Color = Color(0.73, 0.72, 0.95, 1.0)
const COLOR_STAR: Color = Color(0.98, 0.85, 0.38, 1.0)
