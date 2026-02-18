extends Node

const SCREENSHOT_DELAY: float = 4.0
const SCREENSHOT_DIR: String = "ralph/screenshots"
const SCREENSHOT_FILENAME: String = "latest.png"

var _scene_arg: String = ""


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.has("--screenshot"):
		queue_free()
		return

	# Check for optional scene argument: --scene=res://path/to/Scene.tscn
	for arg in user_args:
		if arg.begins_with("--scene="):
			_scene_arg = arg.substr(8)

	print("[ScreenshotTool] Screenshot mode active. Capturing in %.1f seconds..." % SCREENSHOT_DELAY)

	if _scene_arg != "":
		print("[ScreenshotTool] Switching to scene: %s" % _scene_arg)
		get_tree().change_scene_to_file(_scene_arg)
		# Extra delay after scene switch for rendering to settle
		await get_tree().create_timer(1.0).timeout

	await get_tree().create_timer(SCREENSHOT_DELAY).timeout
	_capture_screenshot()
	get_tree().quit()


func _capture_screenshot() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		push_error("[ScreenshotTool] Failed to get viewport image.")
		return

	var dir: DirAccess = DirAccess.open("res://")
	if dir != null and not dir.dir_exists(SCREENSHOT_DIR):
		dir.make_dir_recursive(SCREENSHOT_DIR)

	var save_path: String = "res://%s/%s" % [SCREENSHOT_DIR, SCREENSHOT_FILENAME]
	var error: Error = image.save_png(save_path)
	if error == OK:
		print("[ScreenshotTool] SCREENSHOT_SAVED: %s" % save_path)
	else:
		push_error("[ScreenshotTool] Failed to save screenshot: error %d" % error)
