class_name UITheme
extends RefCounted
## Shared styling helpers for the 2D UI (code-built).

static func panel_style(bg: Color = Color(0.08, 0.09, 0.14, 0.92), border: Color = Color(0.85, 0.85, 0.9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb

static func make_panel(bg: Color = Color(0.08, 0.09, 0.14, 0.92)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg))
	return p

static func make_label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func make_button(text: String, size: int = 16, min_size: Vector2 = Vector2(120, 36)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = min_size
	return b

static func type_badge(t: String) -> Label:
	var l := make_label(GameData.name_of("types", t), 12, Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpriteLoader.type_color(t)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(3)
	l.add_theme_stylebox_override("normal", sb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(64, 20)
	return l
