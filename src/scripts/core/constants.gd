extends Node

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

const PALETTE_LAVENDER: Color = Color8(149, 125, 173, 255)
const PALETTE_MINT: Color = Color8(168, 216, 185, 255)
const PALETTE_PEACH: Color = Color8(255, 214, 186, 255)
const PALETTE_SKY: Color = Color8(160, 196, 255, 255)
const PALETTE_PINK: Color = Color8(232, 160, 191, 255)

const COLOR_BG_CREAM: Color = Color8(248, 244, 245, 255)
const COLOR_BG_DARK_OVERLAY: Color = Color(0.0, 0.0, 0.0, 0.35)
const COLOR_TEXT_DARK: Color = Color8(72, 52, 75, 255)
const COLOR_TEXT_LIGHT: Color = Color8(252, 248, 255, 255)
const COLOR_TEAM_PLAYER: Color = PALETTE_MINT
const COLOR_TEAM_ENEMY: Color = PALETTE_PINK

const FONT_SIZE_TITLE: int = 38
const FONT_SIZE_SUBTITLE: int = 22
const FONT_SIZE_BODY: int = 18
const FONT_SIZE_BUTTON: int = 26
const FONT_SIZE_HUD: int = 20

const COLOR_BG_SOFT: Color = Color(0.96, 0.93, 0.98, 1.0)
const COLOR_FIRE: Color = Color(0.97, 0.45, 0.38, 1.0)
const COLOR_WATER: Color = Color(0.35, 0.67, 0.97, 1.0)
const COLOR_GRASS: Color = Color(0.45, 0.8, 0.47, 1.0)
const COLOR_WIND: Color = Color(0.73, 0.72, 0.95, 1.0)
const COLOR_STAR: Color = Color(0.98, 0.85, 0.38, 1.0)
