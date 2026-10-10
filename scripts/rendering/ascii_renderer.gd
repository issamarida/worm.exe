class_name AsciiRenderer
extends Control
## Only the visible grid is rendered. No scene-per-cell or per-character Label nodes.

const CELL_SIZE: Vector2 = Vector2(14.0, 18.0)

var session: GameSession
var camera: Vector2 = Vector2.ZERO
var reduced_motion: bool = false
var _clock: float = 0.0
var _glow: GradientTexture2D
var _light: PointLight2D
var _effects: Array[Dictionary] = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.width = 512
	_glow.height = 512
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(0.5, 0.0)
	_light = PointLight2D.new()
	_light.texture = _glow
	_light.color = Color("b8c898")
	_light.energy = 0.35
	add_child(_light)


func bind(game: GameSession) -> void:
	session = game
	camera = game.worm.head_position() + Vector2(3.0, 1.0)
	game.pickup_collected.connect(_on_pickup)
	game.returned_home.connect(_on_home)


func _process(delta: float) -> void:
	if session == null: return
	if session.active and not reduced_motion: _clock += delta
	var target: Vector2 = session.worm.head_position() + Vector2(session.worm.facing) * 2.5
	camera = target if reduced_motion else camera.lerp(target, 1.0 - exp(-delta * 5.0))
	_light.position = to_screen(session.worm.head_position())
	_light.texture_scale = session.upgrades.stats.light_radius / 17.0
	_light.color = session.world.biome_at(session.worm.cells[0].y).accent_color
	for index: int in range(_effects.size() - 1, -1, -1):
		_effects[index]["life"] = float(_effects[index]["life"]) - delta
		if float(_effects[index]["life"]) <= 0.0: _effects.remove_at(index)
	queue_redraw()


func to_screen(world_position: Vector2) -> Vector2:
	return (world_position - camera) * CELL_SIZE + size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("070d0a"))
	if session == null: return
	var head: Vector2 = session.worm.head_position()
	var biome: BiomeDefinition = session.world.biome_at(session.worm.cells[0].y)
	var glow_rect: Rect2 = Rect2(to_screen(head) - Vector2(235.0, 235.0), Vector2(470.0, 470.0))
	draw_texture_rect(_glow, glow_rect, false, Color(biome.accent_color, 0.11))
	var origin: Vector2i = Vector2i(floori(camera.x - size.x / CELL_SIZE.x * 0.5) - 1, floori(camera.y - size.y / CELL_SIZE.y * 0.5) - 1)
	var columns: int = ceili(size.x / CELL_SIZE.x) + 3
	var rows: int = ceili(size.y / CELL_SIZE.y) + 3
	var pulse: bool = session.pulse_remaining > 0.0
	var radius: float = session.upgrades.stats.scan_radius if pulse else session.upgrades.stats.light_radius
	for y: int in range(rows):
		for x: int in range(columns):
			var cell_position: Vector2i = origin + Vector2i(x, y)
			var screen: Vector2 = to_screen(Vector2(cell_position))
			var distance: float = Vector2(cell_position).distance_to(head)
			var cell: SoilCell = session.world.get_cell(cell_position)
			var known: bool = session.world.explored.has(cell_position)
			var illumination: float = 1.0 - smoothstep(radius * 0.28, radius + 1.0, distance)
			var ambient: float = 0.22 if known else 0.105
			var color: Color = cell.color * (ambient + illumination * 0.95)
			color.a = 1.0
			if cell.sanctuary:
				color = Color("88916b") * (0.32 + illumination * 0.4)
				color.a = 1.0
			if session.world.modified.has(cell_position):
				color = Color("647451") * (0.23 + illumination * 0.6)
				color.a = 1.0
			if cell.glyph != " ":
				TerminalStyle.text(self, screen + Vector2(-4.0, 5.0), cell.glyph, color, 15)
			if cell.item != SoilCell.Item.NONE:
				var reveal: bool = distance < radius - 1.0 or (session.upgrades.stats.reveal_items > 0.0 and distance < session.upgrades.stats.scan_radius)
				if reveal:
					var brightness: float = 0.65 + 0.25 * sin(_clock * 1.8 + x * 0.7 + y)
					var item_color: Color = cell.item_color() * brightness
					item_color.a = 1.0
					if cell.item >= SoilCell.Item.RELIC:
						draw_texture_rect(_glow, Rect2(screen - Vector2(55.0, 55.0), Vector2(110.0, 110.0)), false, Color(cell.item_color(), 0.18))
					TerminalStyle.text(self, screen + Vector2(-5.0, 6.0), cell.item_glyph(), item_color, 17, true)
			elif cell.cave and not cell.sanctuary and illumination > 0.2 and session.world.coordinate_hash(cell_position, 2) % 107 == 0:
				TerminalStyle.text(self, screen + Vector2(-5, 5), "┬", Color(biome.accent_color, 0.65), 16)
	_draw_sanctuary()
	_draw_worm()
	if pulse and not reduced_motion:
		var phase: float = 1.0 - session.pulse_remaining / session.balance.pulse_seconds
		draw_arc(to_screen(head), phase * radius * CELL_SIZE.x, 0.0, TAU, 96, Color(biome.accent_color, (1.0 - phase) * 0.35), 1.0, true)
	for effect: Dictionary in _effects:
		var life: float = float(effect["life"])
		var effect_pos: Vector2 = to_screen(effect["position"] as Vector2) + Vector2(0, -26.0 * (1.0 - life))
		TerminalStyle.text(self, effect_pos, String(effect["text"]), Color(effect["color"] as Color, life), 13, true)
	# Fine corner marks emphasize the field's instrument-like framing.
	for corner: Vector2 in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), size - Vector2(12, 12)]:
		draw_line(corner - Vector2(3, 0), corner + Vector2(3, 0), Color("334130"), 1.0)
		draw_line(corner - Vector2(0, 3), corner + Vector2(0, 3), Color("334130"), 1.0)


func _draw_sanctuary() -> void:
	var home: Vector2 = to_screen(Vector2(session.balance.starting_position))
	if home.x < -130 or home.x > size.x + 130 or home.y < -100 or home.y > size.y + 100: return
	var root_color: Color = Color("607354")
	TerminalStyle.text(self, home + Vector2(-73, -67), "╲   │   ╱", root_color, 15)
	TerminalStyle.text(self, home + Vector2(-64, -49), "╲  │  ╱", root_color, 15)
	TerminalStyle.text(self, home + Vector2(-56, -31), "╰──┴──╯", Color("95a379"), 15)
	TerminalStyle.text(self, home + Vector2(-84, 62), "⌂ THE ROOT CRADLE", Color("80916b"), 11)
	TerminalStyle.text(self, home + Vector2(-65, 80), "a place to rest", Color("4d6247"), 10)


func _draw_worm() -> void:
	var body: PackedVector2Array = session.worm.interpolated_body()
	for index: int in range(body.size() - 1, -1, -1):
		var location: Vector2 = to_screen(body[index])
		var fraction: float = float(index) / maxf(1.0, body.size() - 1.0)
		var glyph: String = "@" if index == 0 else ("o" if index < body.size() - 3 else "°")
		var color: Color = Color("edf0d5").lerp(Color("708d62"), fraction)
		if not reduced_motion and index > 0:
			location += Vector2(sin(_clock * 3.0 - index * 0.7) * 1.2, cos(_clock * 3.0 - index * 0.7) * 0.8)
		TerminalStyle.text(self, location + Vector2(-5, 6), glyph, color, 19 if index == 0 else 18, true)
	if session.recall_remaining > 0.0:
		TerminalStyle.text(self, to_screen(body[0]) + Vector2(-68, -26), "returning home…", TerminalStyle.GREEN, 11)


func _on_pickup(item: SoilCell.Item, position: Vector2i) -> void:
	var text: String = "+18" if item == SoilCell.Item.FOOD else ("+dew" if item == SoilCell.Item.DEW else "+spores")
	if item >= SoilCell.Item.RELIC: text = "remembered"
	var cell: SoilCell = SoilCell.new()
	cell.item = item
	_effects.append({"position": Vector2(position), "text": text, "color": cell.item_color(), "life": 1.0})


func _on_home() -> void:
	camera = session.worm.head_position() + Vector2(3, 1)
