class_name TerminalStyle
extends RefCounted

const FONT: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const BOLD: Font = preload("res://assets/fonts/JetBrainsMono-Bold.ttf")
const INK: Color = Color("e0e4d3")
const MUTED: Color = Color("828e80")
const FAINT: Color = Color("465447")
const GREEN: Color = Color("b8c898")
const BLUE: Color = Color("8bb7c6")
const GOLD: Color = Color("c4a87c")
const LINE: Color = Color("28352b")
const PANEL: Color = Color("0b120f")


static func text(canvas: CanvasItem, position: Vector2, content: String, color: Color = INK, font_size: int = 13, bold: bool = false) -> void:
	canvas.draw_string(BOLD if bold else FONT, position, content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func wrapped(canvas: CanvasItem, position: Vector2, content: String, width: float, color: Color = MUTED, font_size: int = 12, line_height: float = 20.0) -> float:
	var line: String = ""
	var y: float = position.y
	for word: String in content.split(" "):
		var candidate: String = word if line.is_empty() else line + " " + word
		if FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width and not line.is_empty():
			text(canvas, Vector2(position.x, y), line, color, font_size)
			y += line_height
			line = word
		else:
			line = candidate
	if not line.is_empty(): text(canvas, Vector2(position.x, y), line, color, font_size)
	return y + line_height


static func box(color: Color, border: Color = LINE) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
