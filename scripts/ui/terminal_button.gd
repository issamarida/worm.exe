class_name TerminalButton
extends Button


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", TerminalStyle.FONT)
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", TerminalStyle.GREEN)
	add_theme_color_override("font_hover_color", TerminalStyle.INK)
	add_theme_color_override("font_pressed_color", TerminalStyle.INK)
	add_theme_color_override("font_disabled_color", TerminalStyle.FAINT)
	add_theme_stylebox_override("normal", TerminalStyle.box(Color("111b14")))
	add_theme_stylebox_override("hover", TerminalStyle.box(Color("1b291d"), Color("647657")))
	add_theme_stylebox_override("pressed", TerminalStyle.box(Color("283722"), TerminalStyle.GREEN))
	add_theme_stylebox_override("disabled", TerminalStyle.box(Color("0d1410"), Color("202b23")))
	add_theme_stylebox_override("focus", TerminalStyle.box(Color(0, 0, 0, 0), TerminalStyle.GREEN))


static func make(caption: String, bounds: Rect2, callback: Callable) -> TerminalButton:
	var button: TerminalButton = TerminalButton.new()
	button.text = caption
	button.position = bounds.position
	button.size = bounds.size
	button.pressed.connect(callback)
	return button
