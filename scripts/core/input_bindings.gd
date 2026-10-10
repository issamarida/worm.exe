class_name InputBindings
extends RefCounted

static var _last_action: StringName = &""


static func install() -> void:
	_add(&"move_up", [KEY_W, KEY_UP])
	_add(&"move_down", [KEY_S, KEY_DOWN])
	_add(&"move_left", [KEY_A, KEY_LEFT])
	_add(&"move_right", [KEY_D, KEY_RIGHT])
	_add(&"pulse", [KEY_SPACE])
	_add(&"evolve", [KEY_E, KEY_TAB])
	_add(&"atlas", [KEY_M])
	_add(&"recall", [KEY_R])
	_add(&"pause_game", [KEY_ESCAPE])
	_add(&"sprint", [KEY_SHIFT])
	_add(&"audio_toggle", [KEY_F10])
	_add(&"fullscreen_toggle", [KEY_F11])


static func direction() -> Vector2i:
	# Prioritize the last new press so corners respond immediately while a key is held.
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		if Input.is_action_just_pressed(action): _last_action = action
	if _last_action != &"" and Input.is_action_pressed(_last_action):
		return _direction_for(_last_action)
	for action: StringName in [&"move_down", &"move_up", &"move_right", &"move_left"]:
		if Input.is_action_pressed(action): return _direction_for(action)
	return Vector2i.ZERO


static func _direction_for(action: StringName) -> Vector2i:
	match action:
		&"move_up": return Vector2i.UP
		&"move_down": return Vector2i.DOWN
		&"move_left": return Vector2i.LEFT
		&"move_right": return Vector2i.RIGHT
	return Vector2i.ZERO


static func _add(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action)
	for key: Key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
