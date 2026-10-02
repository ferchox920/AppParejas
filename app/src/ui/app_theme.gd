class_name AppTheme
extends RefCounted

const BACKGROUND := Color("faf7f1")
const INK := Color("23352b")
const FOREST := Color("254c3b")
const MUTED := Color("59665c")
const SAGE := Color("e3ebdd")
const ERROR := Color("963a3b")

static func box(color: Color, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func create() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/DMSans.ttf")
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "CheckBox", INK)
	result.set_color("font_hover_color", "CheckBox", INK)
	result.set_color("font_pressed_color", "CheckBox", INK)
	result.set_color("font_hover_pressed_color", "CheckBox", INK)
	result.set_stylebox("normal", "CheckBox", box(Color.TRANSPARENT, 8))
	result.set_stylebox("pressed", "CheckBox", box(Color.TRANSPARENT, 8))
	result.set_stylebox("hover", "CheckBox", box(SAGE, 8))
	result.set_stylebox("hover_pressed", "CheckBox", box(SAGE, 8))
	result.set_font_size("font_size", "Button", 16)
	result.set_color("font_color", "Button", Color.WHITE)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_stylebox("normal", "Button", box(FOREST))
	result.set_stylebox("hover", "Button", box(Color("36664f")))
	result.set_stylebox("pressed", "Button", box(Color("1c3b2c")))
	result.set_stylebox("disabled", "Button", box(Color("d6ddd2")))
	result.set_color("font_disabled_color", "Button", MUTED)
	var focus: StyleBoxFlat = box(Color.TRANSPARENT)
	focus.set_border_width_all(3)
	focus.border_color = Color("7b623c")
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("focus", "CheckBox", focus)
	result.set_stylebox("normal", "LineEdit", box(Color.WHITE, 12))
	var input_style := box(Color.WHITE, 12)
	input_style.set_border_width_all(1)
	input_style.border_color = FOREST
	result.set_stylebox("normal", "LineEdit", input_style)
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	return result
