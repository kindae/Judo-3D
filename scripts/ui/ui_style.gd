class_name UIStyle
extends RefCounted
## Styles communs de l'interface (panneaux arrondis, boutons, couleurs).

const ACCENT := Color(0.96, 0.78, 0.25)
const BG := Color(0.06, 0.07, 0.09, 0.82)
const BLUE := Color(0.12, 0.32, 0.85)
const WHITE := Color(0.96, 0.96, 0.94)
const TEXT := Color(0.95, 0.95, 0.95)
const MUTED := Color(0.7, 0.72, 0.76)


static func panel(bg := BG, radius := 14, border := Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


static func label(text: String, size := 20, color := TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


static func button(text: String, primary := false, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(280, 60)
	b.focus_mode = Control.FOCUS_NONE
	var n := panel(Color(0.96, 0.78, 0.25, 0.95) if primary else Color(0.14, 0.16, 0.2, 0.92), 12)
	var h := panel(Color(1.0, 0.86, 0.4, 1.0) if primary else Color(0.22, 0.25, 0.31, 0.95), 12)
	var p := panel(Color(0.8, 0.62, 0.15, 1.0) if primary else Color(0.1, 0.11, 0.14, 0.95), 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fc := Color(0.08, 0.08, 0.1) if primary else TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	return b


static func bar(fill: Color, bg := Color(0, 0, 0, 0.5)) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(4)
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", b)
	pb.custom_minimum_size = Vector2(160, 10)
	return pb
