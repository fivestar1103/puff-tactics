extends Node2D
class_name StoryChapter1

const FULL_BATTLE_SCENE: PackedScene = preload("res://src/scenes/battle/FullBattle.tscn")
const FULL_BATTLE_SCRIPT: GDScript = preload("res://src/scripts/battle/full_battle.gd")

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"
const CHAPTER_ID: StringName = &"chapter_1"

const PUFF_PATH_CLOUD: String = "res://src/resources/puffs/base/cloud_tank.tres"
const PUFF_PATH_FLAME: String = "res://src/resources/puffs/base/flame_melee.tres"
const PUFF_PATH_DROPLET: String = "res://src/resources/puffs/base/droplet_ranged.tres"
const PUFF_PATH_LEAF: String = "res://src/resources/puffs/base/leaf_healer.tres"
const PUFF_PATH_WHIRL: String = "res://src/resources/puffs/base/whirl_mobility.tres"
const PUFF_PATH_STAR: String = "res://src/resources/puffs/base/star_wildcard.tres"

const REWARD_ACCESSORY_PATHS: Array[String] = [
	"res://src/resources/accessories/hats/chapter_crown.tres",
	"res://src/resources/accessories/scarves/story_sash.tres"
]

const REWARD_PUFF_PATHS: Array[String] = [
	PUFF_PATH_DROPLET,
	PUFF_PATH_LEAF,
	PUFF_PATH_WHIRL,
	PUFF_PATH_STAR
]

const TUTORIAL_TEXT_BY_FOCUS: Dictionary = {
	"move": "Tutorial: Move a puff to any highlighted tile.",
	"attack": "Tutorial: Use attack on an enemy in range.",
	"bump": "Tutorial: Use bump (skill) to push an adjacent enemy.",
	"terrain": "Tutorial: Move onto non-cloud terrain to learn terrain effects."
}

const STORY_BATTLES: Array[Dictionary] = [
	{
		"battle_id": "chapter1_battle_1",
		"title": "Battle 1: Cloud Vanguard",
		"introduced_class": "Cloud (Tank)",
		"tutorial_focus": "move",
		"max_turns": 5,
		"player_roster": [PUFF_PATH_CLOUD, PUFF_PATH_CLOUD, PUFF_PATH_CLOUD],
		"enemy_roster": [PUFF_PATH_FLAME, PUFF_PATH_FLAME, PUFF_PATH_DROPLET],
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"]
			]
		},
		"pre_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Chapter 1 begins. Cloud puffs hold the front line and survive pressure."
			},
			{
				"speaker": "Guide Luma",
				"portrait": "cloud",
				"line": "Use movement first. Positioning decides every turn."
			}
		],
		"victory_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Good. You controlled space without overcommitting."
			}
		],
		"defeat_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Retry this drill. Keep your tank between enemies and allies."
			}
		]
	},
	{
		"battle_id": "chapter1_battle_2",
		"title": "Battle 2: Flame Pressure",
		"introduced_class": "Flame (Melee)",
		"tutorial_focus": "attack",
		"max_turns": 6,
		"player_roster": [PUFF_PATH_CLOUD, PUFF_PATH_FLAME, PUFF_PATH_CLOUD],
		"enemy_roster": [PUFF_PATH_CLOUD, PUFF_PATH_DROPLET, PUFF_PATH_FLAME],
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "cloud", "high_cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"]
			]
		},
		"pre_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "flame",
				"line": "Flame joins the squad. Melee damage closes battles quickly."
			},
			{
				"speaker": "Rival Brisk",
				"portrait": "rival",
				"line": "If your attacks whiff, I win on attrition."
			}
		],
		"victory_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Direct attacks finish what movement setup started."
			}
		],
		"defeat_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Retry and focus one target at a time."
			}
		]
	},
	{
		"battle_id": "chapter1_battle_3",
		"title": "Battle 3: Droplet Edge",
		"introduced_class": "Droplet (Ranged)",
		"tutorial_focus": "bump",
		"max_turns": 6,
		"player_roster": [PUFF_PATH_CLOUD, PUFF_PATH_FLAME, PUFF_PATH_DROPLET],
		"enemy_roster": [PUFF_PATH_CLOUD, PUFF_PATH_FLAME, PUFF_PATH_CLOUD],
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "cloud", "cliff", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"]
			]
		},
		"pre_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "droplet",
				"line": "Droplet controls lanes from range."
			},
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Now learn bump timing. Pushes can swing entire turns."
			}
		],
		"victory_dialogue": [
			{
				"speaker": "Rival Brisk",
				"portrait": "rival",
				"line": "You used bump windows better than expected."
			}
		],
		"defeat_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Retry and line up bump angles before attacking."
			}
		]
	},
	{
		"battle_id": "chapter1_battle_4",
		"title": "Battle 4: Leaf Study",
		"introduced_class": "Leaf (Healer)",
		"tutorial_focus": "terrain",
		"max_turns": 6,
		"player_roster": [PUFF_PATH_CLOUD, PUFF_PATH_LEAF, PUFF_PATH_FLAME],
		"enemy_roster": [PUFF_PATH_FLAME, PUFF_PATH_DROPLET, PUFF_PATH_CLOUD],
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "high_cloud", "cloud", "puddle", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "mushroom", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "cloud", "cloud", "high_cloud", "cloud"]
			]
		},
		"pre_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "leaf",
				"line": "Leaf keeps teams alive and buys extra turns."
			},
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Terrain matters now: high cloud, puddle, mushroom, and cliffs change outcomes."
			}
		],
		"victory_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Good read. Terrain and healing gave you control."
			}
		],
		"defeat_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Retry and step onto favorable terrain before trading damage."
			}
		]
	},
	{
		"battle_id": "chapter1_battle_5",
		"title": "Battle 5: Whirl Tempo",
		"introduced_class": "Whirl (Mobility)",
		"tutorial_focus": "",
		"max_turns": 7,
		"player_roster": [PUFF_PATH_CLOUD, PUFF_PATH_WHIRL, PUFF_PATH_DROPLET],
		"enemy_roster": [PUFF_PATH_FLAME, PUFF_PATH_LEAF, PUFF_PATH_CLOUD],
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "cloud", "high_cloud", "cloud", "cloud"],
				["cloud", "puddle", "cloud", "mushroom", "cloud"],
				["cloud", "cloud", "cloud", "cloud", "cloud"],
				["cloud", "mushroom", "cloud", "puddle", "cloud"],
				["cloud", "cloud", "high_cloud", "cloud", "cloud"]
			]
		},
		"pre_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "whirl",
				"line": "Whirl adds tempo. Reposition, then punish weak tiles."
			}
		],
		"victory_dialogue": [
			{
				"speaker": "Rival Brisk",
				"portrait": "rival",
				"line": "Your tempo control is getting dangerous."
			}
		],
		"defeat_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Retry and use Whirl to create favorable engagements."
			}
		]
	},
	{
		"battle_id": "chapter1_battle_6",
		"title": "Battle 6: Star Finale",
		"introduced_class": "Star (Wildcard)",
		"tutorial_focus": "",
		"max_turns": 8,
		"player_roster": [PUFF_PATH_CLOUD, PUFF_PATH_STAR, PUFF_PATH_FLAME, PUFF_PATH_DROPLET],
		"enemy_roster": [PUFF_PATH_CLOUD, PUFF_PATH_FLAME, PUFF_PATH_LEAF, PUFF_PATH_WHIRL],
		"map_config": {
			"width": 5,
			"height": 5,
			"rows": [
				["cloud", "high_cloud", "cloud", "cliff", "cloud"],
				["cloud", "puddle", "cloud", "mushroom", "cloud"],
				["cotton_candy", "cloud", "high_cloud", "cloud", "cotton_candy"],
				["cloud", "mushroom", "cloud", "puddle", "cloud"],
				["cloud", "cliff", "cloud", "high_cloud", "cloud"]
			]
		},
		"pre_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "star",
				"line": "Final lesson: Star adapts to any board state."
			},
			{
				"speaker": "Rival Brisk",
				"portrait": "rival",
				"line": "Beat this squad and Chapter 1 is yours."
			}
		],
		"victory_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "Chapter 1 complete. Your roster has grown."
			}
		],
		"defeat_dialogue": [
			{
				"speaker": "Guide Luma",
				"portrait": "guide",
				"line": "One more try. Use Star to answer whatever the enemy shows."
			}
		]
	}
]

@onready var battle_host: Node2D = $BattleHost
@onready var dialogue_overlay: ColorRect = $UiLayer/DialogueOverlay
@onready var dialogue_panel: PanelContainer = $UiLayer/DialogueOverlay/DialoguePanel
@onready var dialogue_portrait: TextureRect = $UiLayer/DialogueOverlay/DialoguePanel/DialogueRow/Portrait
@onready var dialogue_speaker_label: Label = $UiLayer/DialogueOverlay/DialoguePanel/DialogueRow/DialogueColumn/SpeakerLabel
@onready var dialogue_line_label: Label = $UiLayer/DialogueOverlay/DialoguePanel/DialogueRow/DialogueColumn/LineLabel
@onready var dialogue_next_button: Button = $UiLayer/DialogueOverlay/DialoguePanel/DialogueRow/DialogueColumn/NextButton
@onready var tutorial_panel: PanelContainer = $UiLayer/TutorialPanel
@onready var tutorial_label: Label = $UiLayer/TutorialPanel/TutorialLabel
@onready var chapter_complete_overlay: ColorRect = $UiLayer/ChapterCompleteOverlay
@onready var chapter_complete_panel: PanelContainer = $UiLayer/ChapterCompleteOverlay/ChapterPanel
@onready var chapter_complete_title: Label = $UiLayer/ChapterCompleteOverlay/ChapterPanel/ChapterLayout/TitleLabel
@onready var chapter_complete_summary: Label = $UiLayer/ChapterCompleteOverlay/ChapterPanel/ChapterLayout/SummaryLabel
@onready var chapter_complete_button: Button = $UiLayer/ChapterCompleteOverlay/ChapterPanel/ChapterLayout/CompleteButton

var _active_battle: Node
var _battle_index: int = 0
var _dialogue_entries: Array[Dictionary] = []
var _dialogue_index: int = 0
var _dialogue_done_callback: Callable = Callable()
var _portrait_textures_by_key: Dictionary = {}
var _tutorial_focus: String = ""
var _tutorial_completed: bool = false
var _chapter_completed: bool = false
var _last_battle_summary: Dictionary = {}


func _ready() -> void:
	_apply_story_ui_theme()
	_connect_if_needed(dialogue_next_button, &"pressed", Callable(self, "_on_dialogue_next_pressed"))
	_connect_if_needed(chapter_complete_button, &"pressed", Callable(self, "_on_chapter_complete_button_pressed"))
	_build_portraits()
	chapter_complete_overlay.visible = false
	dialogue_overlay.visible = false
	tutorial_panel.visible = false
	_start_current_battle_arc()


func _apply_story_ui_theme() -> void:
	if dialogue_panel != null:
		dialogue_panel.add_theme_stylebox_override("panel", VisualTheme.create_panel_stylebox(Constants.COLOR_BG_CREAM, 18, Constants.COLOR_TEXT_DARK))

	if dialogue_speaker_label != null:
		VisualTheme.apply_label_theme(dialogue_speaker_label, Constants.FONT_SIZE_SUBTITLE, Constants.PALETTE_LAVENDER)

	if dialogue_line_label != null:
		VisualTheme.apply_label_theme(dialogue_line_label, Constants.FONT_SIZE_BODY, Constants.COLOR_TEXT_DARK)

	if dialogue_next_button != null:
		VisualTheme.apply_button_theme(dialogue_next_button, Constants.PALETTE_MINT, Color.WHITE, Vector2(220.0, 68.0), Constants.FONT_SIZE_BUTTON)
		var next_button_radius: int = 999
		var next_button_hover := VisualTheme.create_panel_stylebox(Constants.PALETTE_MINT.lightened(0.08), next_button_radius, Constants.PALETTE_MINT.darkened(0.18))
		var next_button_normal := VisualTheme.create_panel_stylebox(Constants.PALETTE_MINT, next_button_radius, Constants.PALETTE_MINT.darkened(0.18))
		var next_button_pressed := VisualTheme.create_panel_stylebox(Constants.PALETTE_MINT.darkened(0.12), next_button_radius, Constants.PALETTE_MINT.darkened(0.28))
		var next_button_disabled := VisualTheme.create_panel_stylebox(Constants.PALETTE_MINT.darkened(0.28), next_button_radius, Constants.PALETTE_MINT.darkened(0.45))
		dialogue_next_button.add_theme_stylebox_override("normal", next_button_normal)
		dialogue_next_button.add_theme_stylebox_override("hover", next_button_hover)
		dialogue_next_button.add_theme_stylebox_override("pressed", next_button_pressed)
		dialogue_next_button.add_theme_stylebox_override("disabled", next_button_disabled)

	if tutorial_panel != null:
		tutorial_panel.add_theme_stylebox_override("panel", VisualTheme.create_panel_stylebox(Constants.PALETTE_SKY, 16, Constants.COLOR_TEXT_DARK))
	if tutorial_label != null:
		VisualTheme.apply_label_theme(tutorial_label, Constants.FONT_SIZE_BODY, Constants.COLOR_TEXT_DARK)

	if chapter_complete_panel != null:
		chapter_complete_panel.add_theme_stylebox_override("panel", VisualTheme.create_panel_stylebox(Constants.PALETTE_PEACH, 20, Constants.COLOR_TEXT_DARK))
	if chapter_complete_title != null:
		VisualTheme.apply_label_theme(chapter_complete_title, Constants.FONT_SIZE_TITLE, Constants.COLOR_TEXT_DARK)
	if chapter_complete_summary != null:
		VisualTheme.apply_label_theme(chapter_complete_summary, Constants.FONT_SIZE_BODY, Constants.COLOR_TEXT_DARK)

	if chapter_complete_button != null:
		VisualTheme.apply_button_theme(chapter_complete_button, Constants.PALETTE_LAVENDER, Color.WHITE, Vector2(240.0, 72.0), Constants.FONT_SIZE_BUTTON)
		var complete_button_radius: int = 999
		var complete_button_hover := VisualTheme.create_panel_stylebox(Constants.PALETTE_LAVENDER.lightened(0.08), complete_button_radius, Constants.PALETTE_LAVENDER.darkened(0.18))
		var complete_button_normal := VisualTheme.create_panel_stylebox(Constants.PALETTE_LAVENDER, complete_button_radius, Constants.PALETTE_LAVENDER.darkened(0.18))
		var complete_button_pressed := VisualTheme.create_panel_stylebox(Constants.PALETTE_LAVENDER.darkened(0.12), complete_button_radius, Constants.PALETTE_LAVENDER.darkened(0.28))
		var complete_button_disabled := VisualTheme.create_panel_stylebox(Constants.PALETTE_LAVENDER.darkened(0.28), complete_button_radius, Constants.PALETTE_LAVENDER.darkened(0.45))
		chapter_complete_button.add_theme_stylebox_override("normal", complete_button_normal)
		chapter_complete_button.add_theme_stylebox_override("hover", complete_button_hover)
		chapter_complete_button.add_theme_stylebox_override("pressed", complete_button_pressed)
		chapter_complete_button.add_theme_stylebox_override("disabled", complete_button_disabled)


func _start_current_battle_arc() -> void:
	if _battle_index >= STORY_BATTLES.size():
		_complete_chapter()
		return

	var battle_data: Dictionary = STORY_BATTLES[_battle_index]
	var pre_dialogue: Array[Dictionary] = _normalize_dialogue_entries(battle_data.get("pre_dialogue", []))
	_show_dialogue(pre_dialogue, Callable(self, "_launch_battle").bind(_battle_index))


func _launch_battle(requested_index: int) -> void:
	if requested_index < 0 or requested_index >= STORY_BATTLES.size():
		return
	if requested_index != _battle_index:
		return

	_free_active_battle()

	var battle_variant: Node = FULL_BATTLE_SCENE.instantiate()
	if battle_variant == null:
		return
	if battle_variant.get_script() != FULL_BATTLE_SCRIPT and not battle_variant.has_method("start_scripted_battle"):
		if battle_variant != null:
			battle_variant.queue_free()
		return

	_active_battle = battle_variant
	battle_host.add_child(_active_battle)
	_connect_if_needed(_active_battle, &"battle_completed", Callable(self, "_on_active_battle_completed"))
	_connect_if_needed(_active_battle, &"player_action_resolved", Callable(self, "_on_active_battle_player_action"))

	var battle_data: Dictionary = STORY_BATTLES[_battle_index]
	_set_tutorial_state(
		str(battle_data.get("tutorial_focus", "")),
		str(battle_data.get("title", "Battle")),
		str(battle_data.get("introduced_class", ""))
	)

	var scripted_config: Dictionary = {
		"player_roster": battle_data.get("player_roster", []),
		"enemy_roster": battle_data.get("enemy_roster", []),
		"map_config": battle_data.get("map_config", {}),
		"max_turns": int(battle_data.get("max_turns", 8)),
		"suppress_internal_result_overlay": true,
		"disable_async_pvp_sync": true
	}
	if not _active_battle.has_method("start_scripted_battle"):
		return
	if not bool(_active_battle.call("start_scripted_battle", scripted_config)):
		_show_dialogue(
			[
				{
					"speaker": "Guide Luma",
					"portrait": "guide",
					"line": "Battle setup failed. Returning to feed."
				}
			],
			Callable(self, "_on_chapter_complete_button_pressed")
		)


func _on_active_battle_player_action(action_payload: Dictionary) -> void:
	if _tutorial_focus.is_empty() or _tutorial_completed:
		return

	var action_type: String = str(action_payload.get("action", ""))
	var tutorial_completed: bool = false

	match _tutorial_focus:
		"move":
			tutorial_completed = action_type == "move"
		"attack":
			tutorial_completed = action_type == "attack"
		"bump":
			tutorial_completed = action_type == "skill"
		"terrain":
			if action_type == "move" and _active_battle != null:
				var moved_cell_variant: Variant = action_payload.get("actor_cell_after", Vector2i.ZERO)
				if moved_cell_variant is Vector2i:
					var moved_cell: Vector2i = moved_cell_variant
					if _active_battle.has_method("get_terrain_at_cell"):
						var terrain_type: String = str(_active_battle.call("get_terrain_at_cell", moved_cell))
						tutorial_completed = not terrain_type.is_empty() and terrain_type != "cloud"

	if not tutorial_completed:
		return

	_tutorial_completed = true
	tutorial_label.text += "\nTutorial complete."


func _on_active_battle_completed(result: StringName, summary: Dictionary) -> void:
	if _chapter_completed:
		return
	_last_battle_summary = summary.duplicate(true)

	var battle_data: Dictionary = STORY_BATTLES[_battle_index]
	if result == TEAM_PLAYER:
		var victory_dialogue: Array[Dictionary] = _normalize_dialogue_entries(battle_data.get("victory_dialogue", []))
		_show_dialogue(victory_dialogue, Callable(self, "_advance_to_next_battle"))
		return

	var defeat_dialogue: Array[Dictionary] = _normalize_dialogue_entries(battle_data.get("defeat_dialogue", []))
	_show_dialogue(defeat_dialogue, Callable(self, "_retry_current_battle"))


func _advance_to_next_battle() -> void:
	_battle_index += 1
	_start_current_battle_arc()


func _retry_current_battle() -> void:
	_launch_battle(_battle_index)


func _set_tutorial_state(focus_key: String, battle_title: String, introduced_class: String) -> void:
	_tutorial_focus = focus_key
	_tutorial_completed = false

	var objective_text: String = "Objective: Win this scripted battle."
	if TUTORIAL_TEXT_BY_FOCUS.has(focus_key):
		objective_text = str(TUTORIAL_TEXT_BY_FOCUS[focus_key])

	tutorial_label.text = "%s\nClass intro: %s\n%s" % [battle_title, introduced_class, objective_text]
	tutorial_panel.visible = true


func _show_dialogue(entries: Array[Dictionary], done_callback: Callable = Callable()) -> void:
	_dialogue_entries = entries
	_dialogue_index = 0
	_dialogue_done_callback = done_callback

	if _dialogue_entries.is_empty():
		dialogue_overlay.visible = false
		if _dialogue_done_callback.is_valid():
			_dialogue_done_callback.call_deferred()
		return

	dialogue_overlay.visible = true
	_render_dialogue_entry()


func _on_dialogue_next_pressed() -> void:
	if _dialogue_entries.is_empty():
		dialogue_overlay.visible = false
		if _dialogue_done_callback.is_valid():
			_dialogue_done_callback.call_deferred()
		return

	if _dialogue_index < _dialogue_entries.size() - 1:
		_dialogue_index += 1
		_render_dialogue_entry()
		return

	dialogue_overlay.visible = false
	var done_callback: Callable = _dialogue_done_callback
	_dialogue_entries.clear()
	_dialogue_index = 0
	_dialogue_done_callback = Callable()
	if done_callback.is_valid():
		done_callback.call_deferred()


func _render_dialogue_entry() -> void:
	if _dialogue_entries.is_empty() or _dialogue_index < 0 or _dialogue_index >= _dialogue_entries.size():
		return

	var entry: Dictionary = _dialogue_entries[_dialogue_index]
	var speaker_name: String = str(entry.get("speaker", "Guide Luma"))
	var portrait_key: String = str(entry.get("portrait", "guide"))
	var line_text: String = str(entry.get("line", ""))

	dialogue_speaker_label.text = speaker_name
	dialogue_line_label.text = line_text
	dialogue_portrait.texture = _portrait_textures_by_key.get(portrait_key, _portrait_textures_by_key.get("guide", null))
	dialogue_next_button.text = "Continue" if _dialogue_index < _dialogue_entries.size() - 1 else "Proceed"


func _normalize_dialogue_entries(raw_entries_variant: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not (raw_entries_variant is Array):
		return entries

	var raw_entries: Array = raw_entries_variant
	for entry_variant in raw_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		entries.append(
			{
				"speaker": str(entry.get("speaker", "Guide Luma")),
				"portrait": str(entry.get("portrait", "guide")),
				"line": str(entry.get("line", ""))
			}
		)
	return entries


func _complete_chapter() -> void:
	if _chapter_completed:
		return
	_chapter_completed = true
	tutorial_panel.visible = false

	var reward_result: Dictionary = _grant_chapter_rewards()
	var unlocked_puffs: Array = reward_result.get("unlocked_puffs", [])
	var unlocked_accessories: Array = reward_result.get("unlocked_accessories", [])
	var already_claimed: bool = bool(reward_result.get("already_claimed", false))

	var completion_lines: Array[String] = [
		"6 scripted battles cleared.",
		"All six puff classes were introduced one battle at a time.",
		"Tutorial flow completed: move, attack, bump, terrain."
	]

	if already_claimed:
		completion_lines.append("Rewards were already claimed on this profile.")
	else:
		completion_lines.append("Unlocked puffs: %s" % _format_resource_list(unlocked_puffs))
		completion_lines.append("Unlocked accessories: %s" % _format_resource_list(unlocked_accessories))

	chapter_complete_title.text = "Chapter 1 Complete"
	chapter_complete_summary.text = "\n".join(completion_lines)
	chapter_complete_overlay.visible = true


func _grant_chapter_rewards() -> Dictionary:
	var progression: Node = get_node_or_null("/root/PuffProgression")
	if progression == null:
		return {
			"granted": false,
			"already_claimed": true,
			"unlocked_puffs": [],
			"unlocked_accessories": []
		}

	if not progression.has_method("grant_story_chapter_rewards"):
		return {
			"granted": false,
			"already_claimed": true,
			"unlocked_puffs": [],
			"unlocked_accessories": []
		}

	var result_variant: Variant = progression.call(
		"grant_story_chapter_rewards",
		CHAPTER_ID,
		{
			"puffs": REWARD_PUFF_PATHS,
			"accessories": REWARD_ACCESSORY_PATHS
		}
	)
	if result_variant is Dictionary:
		return result_variant

	return {
		"granted": false,
		"already_claimed": true,
		"unlocked_puffs": [],
		"unlocked_accessories": []
	}


func _format_resource_list(resource_paths_variant: Variant) -> String:
	if not (resource_paths_variant is Array):
		return "none"

	var resource_paths: Array = resource_paths_variant
	if resource_paths.is_empty():
		return "none"

	var labels: Array[String] = []
	for path_variant in resource_paths:
		var path: String = str(path_variant)
		if path.is_empty():
			continue
		var label: String = path.get_file().trim_suffix(".tres").replace("_", " ")
		labels.append(label.capitalize())

	if labels.is_empty():
		return "none"
	return ", ".join(labels)


func _on_chapter_complete_button_pressed() -> void:
	var scene_error: Error = get_tree().change_scene_to_file("res://src/scenes/feed/FeedMain.tscn")
	if scene_error != OK:
		queue_free()


func _free_active_battle() -> void:
	if _active_battle == null:
		return
	if is_instance_valid(_active_battle):
		_active_battle.queue_free()
	_active_battle = null


func _build_portraits() -> void:
	_portrait_textures_by_key = {
		"guide": _create_portrait_texture(Color(0.45, 0.72, 0.98, 1.0), Color(0.97, 0.99, 1.0, 1.0)),
		"rival": _create_portrait_texture(Color(0.88, 0.43, 0.45, 1.0), Color(1.0, 0.92, 0.92, 1.0)),
		"cloud": _create_portrait_texture(Color(0.84, 0.9, 0.98, 1.0), Color(0.96, 0.98, 1.0, 1.0)),
		"flame": _create_portrait_texture(Color(0.98, 0.58, 0.42, 1.0), Color(1.0, 0.92, 0.78, 1.0)),
		"droplet": _create_portrait_texture(Color(0.48, 0.77, 0.99, 1.0), Color(0.9, 0.97, 1.0, 1.0)),
		"leaf": _create_portrait_texture(Color(0.52, 0.84, 0.54, 1.0), Color(0.92, 1.0, 0.92, 1.0)),
		"whirl": _create_portrait_texture(Color(0.73, 0.66, 0.94, 1.0), Color(0.95, 0.93, 1.0, 1.0)),
		"star": _create_portrait_texture(Color(0.98, 0.82, 0.45, 1.0), Color(1.0, 0.98, 0.86, 1.0))
	}


func _create_portrait_texture(base_color: Color, accent_color: Color) -> Texture2D:
	var size: int = 128
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius: float = float(size) * 0.45
	for y in size:
		for x in size:
			var point: Vector2 = Vector2(float(x), float(y))
			var distance: float = point.distance_to(center)
			if distance > radius:
				continue
			var mix_ratio: float = clampf(distance / radius, 0.0, 1.0)
			var pixel_color: Color = accent_color.lerp(base_color, mix_ratio)
			image.set_pixel(x, y, pixel_color)

	for ring_y in size:
		for ring_x in size:
			var ring_point: Vector2 = Vector2(float(ring_x), float(ring_y))
			var ring_distance: float = ring_point.distance_to(center)
			if ring_distance <= radius and ring_distance >= radius - 3.0:
				image.set_pixel(ring_x, ring_y, base_color.darkened(0.28))

	return ImageTexture.create_from_image(image)


func _connect_if_needed(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
