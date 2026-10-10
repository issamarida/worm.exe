class_name GameRoot
extends Control
## Routes input and modal UI. GameSession owns all gameplay state.

@onready var session: GameSession = $Session as GameSession
@onready var renderer: AsciiRenderer = $AsciiField as AsciiRenderer
@onready var hud: TerminalHud = $HUD as TerminalHud
@onready var overlay: TerminalOverlay = $Overlay as TerminalOverlay
@onready var audio: EarthAudio = $Audio as EarthAudio
@onready var film: ColorRect = $Film/Effect as ColorRect

var _guide_previous: StringName = &"title"
var _journey_started: bool = false
var _film_enabled: bool = true
var _reduced_motion: bool = false


func _ready() -> void:
	InputBindings.install()
	get_tree().auto_accept_quit = false
	renderer.bind(session)
	hud.bind(session)
	audio.bind(session)
	overlay.session = session
	overlay.has_save = SaveStore.exists()
	overlay.action_requested.connect(_on_action)
	overlay.upgrade_requested.connect(_on_upgrade)
	hud.action_requested.connect(_on_action)
	session.ending_reached.connect(func() -> void: _show(&"ending"))
	_load_settings()
	_show(&"title")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo: return
	if event.is_action_pressed(&"audio_toggle"):
		_on_action(&"audio")
	elif event.is_action_pressed(&"fullscreen_toggle"):
		var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed(&"pause_game"):
		if overlay.mode == &"title": return
		if overlay.mode == &"guide": _on_action(&"guide_back")
		elif overlay.mode == &"new_confirmation": _on_action(&"title_back")
		else: _show(&"pause" if overlay.mode == &"" else &"")
	elif key.physical_keycode == KEY_ENTER and overlay.mode == &"title":
		_on_action(&"continue" if overlay.has_save else &"begin")
	elif event.is_action_pressed(&"evolve") and _journey_started:
		if overlay.mode in [&"", &"evolve"]: _show(&"" if overlay.mode == &"evolve" else &"evolve")
	elif event.is_action_pressed(&"atlas") and _journey_started:
		if overlay.mode in [&"", &"atlas"]: _show(&"" if overlay.mode == &"atlas" else &"atlas")
	elif session.active and event.is_action_pressed(&"pulse"):
		if session.sense(): audio.play(EarthAudio.PULSE)
	elif session.active and event.is_action_pressed(&"recall"):
		session.recall()
	elif key.physical_keycode == KEY_F1:
		_on_action(&"guide")
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _journey_started: session.save_game()
		_save_settings()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and _journey_started and overlay.mode == &"":
		_show(&"pause")


func _show(kind: StringName) -> void:
	session.active = kind == &"" and _journey_started
	overlay.sound_enabled = audio.enabled
	overlay.film_enabled = _film_enabled
	overlay.reduced_motion = _reduced_motion
	overlay.open(kind)
	# Remove stale GUI focus before returning movement keys to the simulation.
	if kind == &"":
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null: focused.release_focus()


func _on_action(action: StringName) -> void:
	match action:
		&"begin":
			_journey_started = true
			session.save_game()
			_show(&"")
		&"continue":
			if session.load_game():
				_journey_started = true
				renderer.camera = session.worm.head_position()
				_show(&"")
			else:
				overlay.has_save = false
				_show(&"title")
		&"close": _show(&"")
		&"evolve", &"atlas":
			if _journey_started: _show(action)
		&"recall":
			if session.active: session.recall()
		&"guide":
			_guide_previous = overlay.mode
			_show(&"guide")
		&"guide_back": _show(_guide_previous)
		&"confirm_new": _show(&"new_confirmation")
		&"new":
			session.new_journey(int(Time.get_unix_time_from_system()) & 0x7fffffff)
			_journey_started = true
			renderer.camera = session.worm.head_position()
			session.save_game()
			_show(&"")
		&"title", &"title_back":
			if _journey_started: session.save_game()
			overlay.has_save = SaveStore.exists()
			_show(&"title")
		&"quit":
			if _journey_started: session.save_game()
			_save_settings()
			get_tree().quit()
		&"audio":
			audio.set_enabled(not audio.enabled)
			_save_settings()
			if overlay.mode == &"pause": _show(&"pause")
		&"film":
			_film_enabled = not _film_enabled
			film.visible = _film_enabled
			_save_settings()
			_show(&"pause")
		&"motion":
			_reduced_motion = not _reduced_motion
			_apply_motion_setting()
			_save_settings()
			_show(&"pause")


func _on_upgrade(id: StringName) -> void:
	if session.upgrades.purchase(id): overlay.refresh_tree()


func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		audio.set_enabled(bool(settings.get_value("accessibility", "sound", true)))
		_film_enabled = bool(settings.get_value("accessibility", "film", true))
		_reduced_motion = bool(settings.get_value("accessibility", "reduced_motion", false))
	film.visible = _film_enabled
	_apply_motion_setting()


func _save_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("accessibility", "sound", audio.enabled)
	settings.set_value("accessibility", "film", _film_enabled)
	settings.set_value("accessibility", "reduced_motion", _reduced_motion)
	var error: Error = settings.save("user://settings.cfg")
	if error != OK: push_warning("Could not save settings: " + error_string(error))


func _apply_motion_setting() -> void:
	renderer.reduced_motion = _reduced_motion
	(film.material as ShaderMaterial).set_shader_parameter("reduced_motion", _reduced_motion)
