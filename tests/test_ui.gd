extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameRoot
	root.add_child(game)
	await process_frame
	_check(game.overlay.mode == &"title" and not game.session.active, "Title starts with simulation paused")
	game._on_action(&"begin")
	_check(game.session.active and not game.overlay.visible, "Beginning a journey reveals and starts gameplay")
	game._on_action(&"evolve")
	_check(game.overlay.mode == &"evolve" and not game.session.active, "Evolution menu pauses the survival clock")
	var cards: Array[SkillCard] = []
	for child: Node in game.overlay.get_children():
		if child is SkillCard: cards.append(child as SkillCard)
	_check(cards.size() == 12, "All three branches and twelve skills are interactive controls")
	game.session.upgrades.spores = 3
	game.overlay.refresh_tree()
	await process_frame
	var first_card: SkillCard = game.overlay.get_child(0) as SkillCard
	_check(first_card != null and not first_card.disabled, "Affordable prerequisite-free skill is enabled")
	first_card.pressed.emit()
	await process_frame
	_check(game.session.upgrades.rank_of(&"phosphor") == 1 and game.session.upgrades.spores == 0, "Clicking a skill purchases it and refreshes the tree")
	game._on_action(&"close")
	_check(game.session.active, "Closing a modal resumes gameplay")
	game._on_action(&"atlas")
	_check(game.overlay.mode == &"atlas" and game.overlay.get_child(0) is BurrowAtlas, "Atlas displays a dedicated map control")
	var atlas: BurrowAtlas = game.overlay.get_child(0) as BurrowAtlas
	var scroll: InputEventMouseButton = InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll.pressed = true
	atlas._gui_input(scroll)
	_check(atlas.zoom > 1.0, "Atlas responds to wheel zoom")
	game._show(&"pause")
	var sound_before: bool = game.audio.enabled
	game._on_action(&"audio")
	_check(game.audio.enabled != sound_before and game.overlay.mode == &"pause", "Sound toggle works while paused")
	var film_before: bool = game.film.visible
	game._on_action(&"film")
	_check(game.film.visible != film_before, "Terminal film can be disabled")
	game._on_action(&"motion")
	_check(game.renderer.reduced_motion, "Reduced motion reaches the renderer")
	game._on_action(&"guide")
	_check(game.overlay.mode == &"guide", "Field guide opens from pause")
	game._on_action(&"guide_back")
	_check(game.overlay.mode == &"pause", "Field guide returns to the originating menu")
	game._on_action(&"close")
	await process_frame
	var head_before: Vector2i = game.session.worm.cells[0]
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_D
	press.pressed = true
	Input.parse_input_event(press)
	for frame: int in range(14): await physics_frame
	press.pressed = false
	Input.parse_input_event(press)
	_check(game.session.worm.cells[0].x > head_before.x, "Keyboard movement traverses the actual input map and physics loop")
	var pulse: InputEventKey = InputEventKey.new()
	pulse.physical_keycode = KEY_SPACE
	pulse.pressed = true
	game._unhandled_input(pulse)
	_check(game.session.pulse_remaining > 0.0, "Space triggers sensing through root input routing")
	game._on_action(&"title")
	_check(game.overlay.has_save and game.overlay.mode == &"title" and not game.session.active, "Save and title creates a resumable paused journey")
	game._on_action(&"continue")
	_check(game.session.active and game.session.upgrades.rank_of(&"phosphor") == 1, "Continue restores the evolved journey")
	game._on_action(&"confirm_new")
	_check(game.overlay.mode == &"new_confirmation", "Replacing a burrow has an explicit in-game confirmation")
	game._on_action(&"title_back")
	_check(game.session.upgrades.rank_of(&"phosphor") == 1, "Canceling a new life preserves progression")
	game.queue_free()
	await process_frame
	print("WORM UI TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
