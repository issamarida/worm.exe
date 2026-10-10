class_name TerminalOverlay
extends Control

signal action_requested(action: StringName)
signal upgrade_requested(id: StringName)

var session: GameSession
var mode: StringName = &""
var has_save: bool = false
var sound_enabled: bool = true
var film_enabled: bool = true
var reduced_motion: bool = false
var _cards: Array[SkillCard] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(kind: StringName) -> void:
	mode = kind
	visible = not String(kind).is_empty()
	_clear_controls()
	match mode:
		&"title": _build_title()
		&"pause": _build_pause()
		&"evolve": _build_tree()
		&"atlas": _build_atlas()
		&"guide": _build_guide()
		&"ending": _build_ending()
		&"new_confirmation": _build_confirmation()
	queue_redraw()


func refresh_tree() -> void:
	if mode == &"evolve": open(&"evolve")


func _draw() -> void:
	if mode == &"": return
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.018, 0.028, 0.021, 0.88))
	match mode:
		&"title": _draw_title()
		&"evolve": _draw_tree()
		&"atlas":
			_panel(Rect2(202, 133, 1036, 658))
			_header("THE BURROW ATLAS", "A map of the places you have touched.", Vector2(231, 175))
		&"pause": _draw_pause()
		&"guide": _draw_guide()
		&"ending": _draw_ending()
		&"new_confirmation":
			_panel(Rect2(414, 279, 612, 320))
			_header("A NEW LITTLE LIFE", "Begin again in a different patch of earth.", Vector2(444, 328))
			TerminalStyle.wrapped(self, Vector2(444, 405), "This replaces the current burrow, its passages, spores and evolutions. Your old save stays in the backup until the next save.", 528, TerminalStyle.MUTED, 13, 23)


func _clear_controls() -> void:
	_cards.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _button(caption: String, bounds: Rect2, action: StringName) -> TerminalButton:
	var button: TerminalButton = TerminalButton.make(caption, bounds, func() -> void: action_requested.emit(action))
	add_child(button)
	return button


func _panel(bounds: Rect2) -> void:
	draw_rect(bounds, TerminalStyle.PANEL)
	draw_rect(bounds, TerminalStyle.LINE, false, 1.0)
	draw_line(bounds.position + Vector2(24, 0), bounds.position + Vector2(122, 0), TerminalStyle.GREEN, 2.0)


func _header(title: String, subtitle: String, position: Vector2) -> void:
	TerminalStyle.text(self, position, title, TerminalStyle.INK, 22, true)
	TerminalStyle.text(self, position + Vector2(0, 29), subtitle, TerminalStyle.MUTED, 12)


func _build_title() -> void:
	if has_save:
		_button("CONTINUE YOUR BURROW  →", Rect2(425, 526, 590, 49), &"continue")
		_button("BEGIN A NEW LITTLE LIFE", Rect2(425, 587, 388, 42), &"confirm_new")
		_button("FIELD GUIDE", Rect2(825, 587, 190, 42), &"guide")
	else:
		_button("ENTER THE EARTH  →", Rect2(425, 526, 590, 49), &"begin")
		_button("READ THE FIELD GUIDE", Rect2(425, 587, 590, 42), &"guide")


func _draw_title() -> void:
	_panel(Rect2(377, 172, 686, 529))
	TerminalStyle.text(self, Vector2(426, 219), "A COZY EXPEDITION INTO THE UNKNOWN", TerminalStyle.MUTED, 10)
	TerminalStyle.text(self, Vector2(420, 308), "worm.exe", TerminalStyle.INK, 68, true)
	TerminalStyle.text(self, Vector2(428, 350), "B E N E A T H   T H E   Q U I E T", TerminalStyle.GREEN, 14)
	draw_line(Vector2(426, 380), Vector2(1014, 380), TerminalStyle.LINE)
	TerminalStyle.wrapped(self, Vector2(427, 417), "Above you, the world is sleeping. Below you, it is alive. Carry a little rain. Follow a little light. Find what the roots have forgotten.", 577, TerminalStyle.MUTED, 14, 26)
	TerminalStyle.text(self, Vector2(426, 672), "NO HURRY. NO ENEMIES. JUST YOU, AND THE EARTH.", TerminalStyle.FAINT, 10)


func _build_pause() -> void:
	_button("RETURN TO THE EARTH  →", Rect2(472, 319, 496, 44), &"close")
	_button("SOUND  /  " + ("ON" if sound_enabled else "OFF") + "    [F10]", Rect2(472, 377, 496, 42), &"audio")
	_button("TERMINAL FILM  /  " + ("ON" if film_enabled else "OFF"), Rect2(472, 431, 496, 42), &"film")
	_button("REDUCED MOTION  /  " + ("ON" if reduced_motion else "OFF"), Rect2(472, 485, 496, 42), &"motion")
	_button("FIELD GUIDE", Rect2(472, 539, 241, 42), &"guide")
	_button("SAVE & TITLE", Rect2(726, 539, 242, 42), &"title")
	_button("SAVE & QUIT", Rect2(472, 593, 496, 42), &"quit")


func _draw_pause() -> void:
	_panel(Rect2(433, 199, 574, 486))
	_header("THE EARTH WILL WAIT", "Your journey is paused. Breathe a little.", Vector2(473, 253))


func _build_tree() -> void:
	for skill: SkillDefinition in session.upgrades.catalog:
		var card: SkillCard = SkillCard.new()
		card.definition = skill
		card.upgrades = session.upgrades
		card.position = Vector2(202 + int(skill.branch) * 345, 266 + skill.tier * 112)
		card.size = Vector2(318, 101)
		card.pressed.connect(func() -> void: upgrade_requested.emit(skill.id))
		add_child(card)
		_cards.append(card)
	_button("BACK TO THE EARTH  [ E / ESC ]", Rect2(885, 737, 353, 40), &"close")


func _draw_tree() -> void:
	_panel(Rect2(176, 124, 1088, 676))
	_header("BECOME A LITTLE MORE", "The earth changes you. Choose what you carry into it.", Vector2(204, 176))
	TerminalStyle.text(self, Vector2(1074, 176), "%02d SPORES *" % session.upgrades.spores, TerminalStyle.GREEN, 17)
	var names: PackedStringArray = ["THE PRISM-TUNNELER", "THE EARTH-SHAPER", "THE RESILIENT CORE"]
	var subs: PackedStringArray = ["See what the dark keeps.", "Make the earth a little softer.", "Keep a little more of yourself."]
	var colors: Array[Color] = [TerminalStyle.BLUE, TerminalStyle.GREEN, TerminalStyle.GOLD]
	for branch: int in range(3):
		var x: float = 203 + branch * 345
		TerminalStyle.text(self, Vector2(x, 231), names[branch], colors[branch], 14, true)
		TerminalStyle.text(self, Vector2(x, 253), subs[branch], TerminalStyle.MUTED, 10)
		for tier: int in range(3):
			draw_line(Vector2(x + 156, 367 + tier * 112), Vector2(x + 156, 378 + tier * 112), TerminalStyle.FAINT)
	TerminalStyle.text(self, Vector2(204, 754), "Each lower evolution needs the one above it.", TerminalStyle.MUTED, 11)
	TerminalStyle.text(self, Vector2(204, 776), "Passages, root echoes and evolutions survive a tired return.", TerminalStyle.FAINT, 9)


func _build_atlas() -> void:
	var atlas: BurrowAtlas = BurrowAtlas.new()
	atlas.session = session
	atlas.position = Vector2(230, 233)
	atlas.size = Vector2(980, 481)
	add_child(atlas)
	_button("CLOSE ATLAS  [ M / ESC ]", Rect2(846, 735, 364, 37), &"close")


func _build_guide() -> void:
	_button("I'M READY  →", Rect2(913, 739, 292, 41), &"guide_back")


func _draw_guide() -> void:
	_panel(Rect2(229, 133, 982, 660))
	_header("A FIELD GUIDE TO BEING SMALL", "Everything you need for a quiet expedition.", Vector2(268, 182))
	var left: float = 269
	var right: float = 757
	TerminalStyle.text(self, Vector2(left, 270), "01  FIND YOUR WAY", TerminalStyle.GREEN, 15, true)
	TerminalStyle.wrapped(self, Vector2(left, 302), "Use WASD or the arrow keys. Your body follows; crossing your own path is safe. Hold Shift to hurry, at the cost of more energy and moisture.", 394, TerminalStyle.MUTED, 13, 24)
	TerminalStyle.text(self, Vector2(left, 440), "02  CARRY A LITTLE RAIN", TerminalStyle.BLUE, 15, true)
	TerminalStyle.wrapped(self, Vector2(left, 472), "Dig through % for food, ~ for dew and * for spores. Dense, dry soil costs more. Rest in the root cradle to refill. R takes you home safely, carrying everything you found.", 394, TerminalStyle.MUTED, 13, 24)
	TerminalStyle.text(self, Vector2(right, 270), "03  LISTEN, THEN GROW", TerminalStyle.GOLD, 15, true)
	TerminalStyle.wrapped(self, Vector2(right, 302), "Space sends a sensing pulse, revealing nearby resources for five seconds. E opens three evolution branches. M shows your passages and the root-song landmarks.", 397, TerminalStyle.MUTED, 13, 24)
	TerminalStyle.text(self, Vector2(right, 440), "04  REMEMBER THE ROOT-SONG", TerminalStyle.GREEN, 15, true)
	TerminalStyle.wrapped(self, Vector2(right, 472), "Find the three & echoes, then Ω at 103m. Bring the quiet heart home. If you grow too tired or dry, the roots rescue you; 30% of unspent spores return to the earth.", 397, TerminalStyle.MUTED, 13, 24)
	draw_line(Vector2(270, 659), Vector2(1172, 659), TerminalStyle.LINE)
	TerminalStyle.wrapped(self, Vector2(270, 694), "Menus pause time. Your burrow saves automatically, on discoveries, evolutions and exit. Esc opens sound, film and motion settings.", 898, TerminalStyle.FAINT, 11, 20)


func _build_ending() -> void:
	_button("KEEP WANDERING  →", Rect2(444, 600, 551, 46), &"close")


func _draw_ending() -> void:
	_panel(Rect2(404, 170, 632, 526))
	TerminalStyle.text(self, Vector2(677, 242), "Ω", Color("c9a7c4"), 49)
	_header("A LIGHT BENEATH THE QUIET", "The root-song is whole again.", Vector2(444, 319))
	TerminalStyle.wrapped(self, Vector2(444, 391), "You were never looking for a way out. You were finding a way to belong. The roots take the quiet heart gently. Far above, a flower opens.", 542, TerminalStyle.MUTED, 14, 28)
	TerminalStyle.text(self, Vector2(444, 535), "%.1fm remembered  /  %d passages made" % [session.deepest * 0.5, session.distance_dug], TerminalStyle.GREEN, 12)
	TerminalStyle.text(self, Vector2(444, 566), "There is still more earth. There is always more earth.", TerminalStyle.FAINT, 10)


func _build_confirmation() -> void:
	_button("BEGIN AGAIN", Rect2(444, 515, 247, 43), &"new")
	_button("KEEP MY BURROW", Rect2(706, 515, 287, 43), &"title_back")
