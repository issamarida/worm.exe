class_name TerminalHud
extends Control

signal action_requested(action: StringName)

var session: GameSession
var status: String = "ALL IS QUIET"
var _clock: float = 0.0
var _notice_seconds: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_button("[ E ]  EVOLVE", Rect2(1187, 578, 219, 43), &"evolve")
	_make_button("[ M ]  BURROW ATLAS", Rect2(1187, 631, 219, 43), &"atlas")
	_make_button("[ R ]  RETURN HOME", Rect2(1187, 684, 219, 43), &"recall")
	_make_button("FIELD GUIDE  [?]", Rect2(1194, 31, 211, 36), &"guide")


func _make_button(caption: String, bounds: Rect2, action: StringName) -> void:
	var button: TerminalButton = TerminalButton.make(caption, bounds, func() -> void: action_requested.emit(action))
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)


func bind(game: GameSession) -> void:
	session = game
	game.save_completed.connect(func(success: bool) -> void:
		status = "BURROW SAVED" if success else "SAVE UNAVAILABLE"
		_notice_seconds = 3.0
	)


func _process(delta: float) -> void:
	_clock += delta
	_notice_seconds = maxf(0.0, _notice_seconds - delta)
	if _notice_seconds == 0.0: status = "ALL IS QUIET"
	queue_redraw()


func _draw() -> void:
	_draw_shell()
	if session == null: return
	_draw_vitals()
	_draw_quest()
	_draw_field_header()
	_draw_journal()


func _draw_shell() -> void:
	TerminalStyle.text(self, Vector2(33, 51), "worm.exe", TerminalStyle.INK, 27, true)
	TerminalStyle.text(self, Vector2(34, 74), "B E N E A T H   T H E   Q U I E T", TerminalStyle.MUTED, 9)
	TerminalStyle.text(self, Vector2(582, 52), "A SMALL LIFE. A DEEP WORLD.", TerminalStyle.MUTED, 11)
	draw_line(Vector2(33, 97), Vector2(1406, 97), TerminalStyle.LINE, 1.0)
	TerminalStyle.text(self, Vector2(35, 116), "01 / THE DESCENT", TerminalStyle.FAINT, 9)
	TerminalStyle.text(self, Vector2(1204, 116), "LOCAL EXPEDITION  /  v1.0", TerminalStyle.FAINT, 9)
	draw_rect(Rect2(282, 132, 876, 601), Color("0c130f"))
	draw_rect(Rect2(282, 132, 876, 601), TerminalStyle.LINE, false, 1.0)
	draw_line(Vector2(283, 173), Vector2(1157, 173), TerminalStyle.LINE, 1.0)
	draw_line(Vector2(283, 700), Vector2(1157, 700), TerminalStyle.LINE, 1.0)
	draw_line(Vector2(33, 816), Vector2(1406, 816), TerminalStyle.LINE, 1.0)
	TerminalStyle.text(self, Vector2(34, 853), "WASD / ↑↓←→  move", TerminalStyle.MUTED, 12)
	TerminalStyle.text(self, Vector2(301, 853), "SHIFT  hurry", TerminalStyle.MUTED, 12)
	TerminalStyle.text(self, Vector2(507, 853), "SPACE  listen", TerminalStyle.GREEN, 12)
	TerminalStyle.text(self, Vector2(755, 853), "E  evolve", TerminalStyle.MUTED, 12)
	TerminalStyle.text(self, Vector2(935, 853), "M  atlas", TerminalStyle.MUTED, 12)
	TerminalStyle.text(self, Vector2(1177, 853), "ESC  pause", TerminalStyle.MUTED, 12)
	TerminalStyle.text(self, Vector2(34, 882), "TAKE YOUR TIME. THE EARTH WILL WAIT.", TerminalStyle.FAINT, 9)
	TerminalStyle.text(self, Vector2(1186, 882), "F10 sound  ·  F11 full screen", TerminalStyle.FAINT, 9)


func _draw_vitals() -> void:
	TerminalStyle.text(self, Vector2(34, 150), "T H E   W A N D E R E R", TerminalStyle.MUTED, 10)
	TerminalStyle.text(self, Vector2(38, 201), "   .  o o o @", TerminalStyle.GREEN, 20)
	TerminalStyle.text(self, Vector2(35, 235), "little earthling", TerminalStyle.INK, 17)
	TerminalStyle.text(self, Vector2(35, 259), "soft body. stubborn heart.", TerminalStyle.MUTED, 10)
	draw_line(Vector2(34, 284), Vector2(247, 284), TerminalStyle.LINE)
	_draw_meter(Vector2(35, 313), "ENERGY", session.survival.energy, session.upgrades.stats.max_energy, TerminalStyle.GREEN, "the strength to keep going")
	_draw_meter(Vector2(35, 410), "MOISTURE", session.survival.moisture, session.upgrades.stats.max_moisture, TerminalStyle.BLUE, "a little rain, carried within")
	draw_line(Vector2(34, 492), Vector2(247, 492), TerminalStyle.LINE)
	TerminalStyle.text(self, Vector2(35, 525), "SPORES COLLECTED", TerminalStyle.MUTED, 10)
	TerminalStyle.text(self, Vector2(35, 570), "%02d" % session.upgrades.spores, TerminalStyle.GREEN, 38)
	TerminalStyle.text(self, Vector2(99, 565), "* room to grow", TerminalStyle.MUTED, 11)
	draw_line(Vector2(34, 597), Vector2(247, 597), TerminalStyle.LINE)
	TerminalStyle.text(self, Vector2(35, 633), "DEEPEST MEMORY", TerminalStyle.MUTED, 10)
	TerminalStyle.text(self, Vector2(35, 662), "%.1f m" % (session.deepest * 0.5), TerminalStyle.INK, 20)
	TerminalStyle.text(self, Vector2(35, 699), "%d passages made" % session.distance_dug, TerminalStyle.MUTED, 11)
	var at_home: bool = session.world.is_home(session.worm.cells[0])
	TerminalStyle.text(self, Vector2(35, 765), "⌂ SAFE IN THE ROOTS" if at_home else "↓ BENEATH THE SURFACE", TerminalStyle.GREEN if at_home else TerminalStyle.FAINT, 10)


func _draw_meter(position: Vector2, label: String, value: float, maximum: float, color: Color, subtitle: String) -> void:
	TerminalStyle.text(self, position, label, TerminalStyle.MUTED, 10)
	var value_text: String = "%03d / %d" % [ceili(value), int(maximum)]
	TerminalStyle.text(self, position + Vector2(126, 0), value_text, color, 11)
	var ratio: float = value / maximum
	var meter_color: Color = TerminalStyle.GOLD if ratio < 0.25 else color
	for index: int in range(21):
		var active: bool = float(index) / 21.0 < ratio
		draw_rect(Rect2(position + Vector2(index * 10.0, 15), Vector2(7, 15)), meter_color if active else Color("1b261f"))
	TerminalStyle.text(self, position + Vector2(0, 54), subtitle, TerminalStyle.FAINT, 9)


func _draw_quest() -> void:
	TerminalStyle.text(self, Vector2(1187, 150), "T H E   R O O T - S O N G", TerminalStyle.MUTED, 10)
	for index: int in range(3):
		var found: bool = session.relics.has(session.balance.relic_positions[index])
		TerminalStyle.text(self, Vector2(1192 + index * 64, 191), "[ & ]" if found else "[ · ]", TerminalStyle.GOLD if found else TerminalStyle.FAINT, 19)
	TerminalStyle.text(self, Vector2(1187, 218), "%d OF 3 ECHOES REMEMBERED" % session.relics.size(), TerminalStyle.MUTED, 10)
	var instruction: String = "Find the three root echoes. Wake the quiet heart. Bring its light home."
	if session.has_heart: instruction = "The quiet heart is with you. Return to the root cradle with R."
	if session.completed: instruction = "The root-song is whole. Wander on; there is always more earth."
	TerminalStyle.wrapped(self, Vector2(1187, 249), instruction, 216, TerminalStyle.INK, 12, 20)
	var destination: Vector2i = session.next_destination()
	var delta: Vector2i = destination - session.worm.cells[0]
	var direction: String = "↓" if delta.y >= 0 else "↑"
	if absi(delta.x) > 3: direction += "  ←" if delta.x < 0 else "  →"
	TerminalStyle.text(self, Vector2(1187, 343), direction, TerminalStyle.GOLD, 21)
	TerminalStyle.text(self, Vector2(1251, 337), "%.1f m" % (destination.y * 0.5), TerminalStyle.INK, 18)
	TerminalStyle.text(self, Vector2(1251, 356), "next root memory" if session.relics.size() < 3 else ("the quiet heart" if not session.has_heart else "the root cradle"), TerminalStyle.MUTED, 9)
	draw_line(Vector2(1187, 383), Vector2(1405, 383), TerminalStyle.LINE)
	TerminalStyle.text(self, Vector2(1187, 413), "THE EARTH OFFERS", TerminalStyle.MUTED, 10)
	var glyphs: PackedStringArray = ["%", "~", "*", "&"]
	var names: PackedStringArray = ["Nourishment", "Dew pocket", "Spore cluster", "Root echo"]
	var colors: Array[Color] = [TerminalStyle.GOLD, TerminalStyle.BLUE, TerminalStyle.GREEN, TerminalStyle.GOLD]
	for index: int in range(4):
		TerminalStyle.text(self, Vector2(1192, 447 + index * 28), glyphs[index], colors[index], 17, true)
		TerminalStyle.text(self, Vector2(1226, 446 + index * 28), names[index], TerminalStyle.MUTED, 11)


func _draw_field_header() -> void:
	var position: Vector2i = session.worm.cells[0]
	var biome: BiomeDefinition = session.world.biome_at(position.y)
	draw_circle(Vector2(301, 153), 3, biome.accent_color)
	TerminalStyle.text(self, Vector2(317, 158), biome.title, TerminalStyle.MUTED, 11)
	TerminalStyle.text(self, Vector2(981, 158), "DEPTH %05.1f m" % (position.y * 0.5), TerminalStyle.INK, 12)
	TerminalStyle.text(self, Vector2(299, 720), "x %s  /  y %s" % [str(position.x).pad_zeros(4), str(position.y).pad_zeros(4)], TerminalStyle.FAINT, 9)
	var pulse_text: String = "LISTENING…" if session.pulse_remaining > 0.0 else ("SENSE READY  [SPACE]" if session.pulse_cooldown <= 0.0 else "SENSE IN %.1fs" % session.pulse_cooldown)
	TerminalStyle.text(self, Vector2(601, 720), pulse_text, TerminalStyle.GREEN if session.pulse_cooldown <= 0.0 else TerminalStyle.FAINT, 9)
	TerminalStyle.text(self, Vector2(989, 720), "PRESSURE %.2f" % session.survival.pressure_at(position.y), TerminalStyle.MUTED, 9)


func _draw_journal() -> void:
	TerminalStyle.text(self, Vector2(284, 757), "FIELD NOTES", TerminalStyle.FAINT, 9)
	var start: int = maxi(0, session.journal.size() - 2)
	for index: int in range(start, session.journal.size()):
		var entry: Dictionary = session.journal[index]
		TerminalStyle.text(self, Vector2(283, 780 + (index - start) * 19), "› " + String(entry["text"]), Color(String(entry["color"])), 11)
	TerminalStyle.text(self, Vector2(1211, 773), "● " + status, TerminalStyle.FAINT, 10)
