extends SceneTree
## Visual QA: run with a rendering display; output stays outside normal saves.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output: String = "res://builds/screenshots"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameRoot
	(game.get_node("Audio") as EarthAudio).playback_enabled = false
	root.add_child(game)
	await process_frame
	game.overlay.has_save = false
	game._show(&"title")
	await _save_frame(output.path_join("title.png"))
	game._on_action(&"begin")
	await _save_frame(output.path_join("play.png"))
	game.session.upgrades.spores = 16
	game._on_action(&"evolve")
	await _save_frame(output.path_join("evolution.png"))
	game._on_action(&"close")
	game._on_action(&"atlas")
	await _save_frame(output.path_join("atlas.png"))
	game._on_action(&"guide")
	await _save_frame(output.path_join("guide.png"))
	game._show(&"ending")
	await _save_frame(output.path_join("ending.png"))
	game.queue_free()
	for frame: int in range(4): await process_frame
	print("Captured title, play, evolution, atlas, field guide and ending to " + output)
	quit()


func _save_frame(path: String) -> void:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK: push_error("Screenshot failed: " + error_string(error))
