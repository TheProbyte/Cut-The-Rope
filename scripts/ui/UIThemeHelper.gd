class_name UIThemeHelper
extends RefCounted


static func make_panel_style(bg: Color, border: Color, radius: int = 20, border_w: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.10, 0.18, 0.12, 0.18)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func style_button(btn: Button, bg: Color, hover: Color, pressed: Color, text_col: Color = Color.WHITE, font_size: int = 26, radius: int = 18) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.68, 0.64))
	btn.focus_mode = Control.FOCUS_NONE

	var border := bg.darkened(0.22)
	btn.add_theme_stylebox_override("normal", make_panel_style(bg, border, radius, 3))
	btn.add_theme_stylebox_override("hover", make_panel_style(hover, border, radius, 3))
	btn.add_theme_stylebox_override("pressed", make_panel_style(pressed, border.darkened(0.1), radius, 3))
	btn.add_theme_stylebox_override("disabled", make_panel_style(Color(0.82, 0.86, 0.82), Color(0.68, 0.74, 0.70), radius, 2))
