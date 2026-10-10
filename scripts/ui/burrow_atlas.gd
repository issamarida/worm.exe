class_name BurrowAtlas
extends Control

var session: GameSession
var zoom: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.2 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 1.0, 4.0)
			queue_redraw()
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080e0b"))
	if session == null: return
	for y: int in range(0, int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("142017"))
	for x: int in range(0, int(size.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("142017"))
	for cell: Vector2i in session.world.explored:
		var point: Vector2 = _map_point(cell)
		if not Rect2(Vector2.ZERO, size).has_point(point): continue
		var color: Color = session.world.biome_at(cell.y).soil_color * 0.46
		color.a = 1.0
		if session.world.modified.has(cell): color = Color("8a9d70")
		draw_rect(Rect2(point, Vector2(2.6, 1.6) * zoom), color)
	_draw_marker(session.balance.starting_position, "⌂", "ROOT CRADLE", TerminalStyle.GREEN)
	for index: int in range(3):
		var cell: Vector2i = session.balance.relic_positions[index]
		_draw_marker(cell, "&", "ECHO %d%s" % [index + 1, " / FOUND" if session.relics.has(cell) else ""], TerminalStyle.GOLD)
	_draw_marker(session.balance.goal_position, "Ω", "THE QUIET HEART", Color("c9a7c4"))
	var player: Vector2 = _map_point(session.worm.cells[0])
	draw_circle(player + Vector2(2, 2), 10.0, Color(TerminalStyle.GREEN, 0.15))
	TerminalStyle.text(self, player + Vector2(-5, 6), "@", TerminalStyle.INK, 18, true)
	TerminalStyle.text(self, Vector2(18, 27), "YOUR PASSAGES ARE A KIND OF HANDWRITING.", TerminalStyle.FAINT, 10)
	TerminalStyle.text(self, Vector2(18, size.y - 17), "SCROLL TO ZOOM  /  %.1fx" % zoom, TerminalStyle.MUTED, 10)


func _map_point(cell: Vector2i) -> Vector2:
	var head: Vector2i = session.worm.cells[0]
	var center: Vector2 = Vector2(head) if zoom > 1.0 or head.y > 225 or absi(head.x) > 100 else Vector2(0, 106)
	return (Vector2(cell) - center) * Vector2(3.8, 2.05) * zoom + size * 0.5


func _draw_marker(cell: Vector2i, glyph: String, caption: String, color: Color) -> void:
	var point: Vector2 = _map_point(cell)
	if not Rect2(Vector2(0, 35), size - Vector2(0, 70)).has_point(point): return
	draw_circle(point, 11.0, Color(color, 0.1))
	TerminalStyle.text(self, point + Vector2(-5, 6), glyph, color, 17)
	TerminalStyle.text(self, point + Vector2(22, 4), caption, color, 10)
