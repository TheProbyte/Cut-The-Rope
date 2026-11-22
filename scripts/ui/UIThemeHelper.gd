class_name UIThemeHelper
extends RefCounted

const FREDOKA_PATH := "res://assets/fonts/Fredoka-SemiBold.ttf"
const NUNITO_PATH := "res://assets/fonts/Nunito-Bold.ttf"

static var _display_font: Font = null
static var _body_font: Font = null


static func get_display_font() -> Font:
	if _display_font == null and ResourceLoader.exists(FREDOKA_PATH):
		var base: FontFile = load(FREDOKA_PATH)
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = { 2003265652: 650 } # 'wght' = 650 SemiBold/Bold
		_display_font = fv
	return _display_font


static func get_body_font() -> Font:
	if _body_font == null and ResourceLoader.exists(NUNITO_PATH):
		var base: FontFile = load(NUNITO_PATH)
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = { 2003265652: 700 } # 'wght' = 700 Bold
		_body_font = fv
	return _body_font


static func apply_display_font(ctrl: Control, font_size: int, color: Color = Color(0.18, 0.34, 0.24)) -> void:
	var f := get_display_font()
	if f != null:
		ctrl.add_theme_font_override("font", f)
	ctrl.add_theme_font_size_override("font_size", font_size)
	ctrl.add_theme_color_override("font_color", color)


static func apply_body_font(ctrl: Control, font_size: int, color: Color = Color(0.24, 0.38, 0.28)) -> void:
	var f := get_body_font()
	if f != null:
		ctrl.add_theme_font_override("font", f)
	ctrl.add_theme_font_size_override("font_size", font_size)
	ctrl.add_theme_color_override("font_color", color)


static func make_panel_style(bg: Color, border: Color, radius: int = 22, border_w: int = 3, bottom_lip: int = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_right = border_w
	s.border_width_top = border_w
	s.border_width_bottom = border_w + bottom_lip
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.10, 0.18, 0.14, 0.18)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s


static func style_button(btn: Button, bg: Color, hover: Color, pressed: Color, text_col: Color = Color.WHITE, font_size: int = 26, radius: int = 20) -> void:
	var f := get_display_font()
	if f != null:
		btn.add_theme_font_override("font", f)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.56, 0.62, 0.58))
	btn.add_theme_color_override("font_outline_color", bg.darkened(0.45))
	btn.add_theme_constant_override("outline_size", 2 if text_col == Color.WHITE else 0)
	btn.focus_mode = Control.FOCUS_NONE

	var border := bg.darkened(0.24)
	btn.add_theme_stylebox_override("normal", make_panel_style(bg, border, radius, 2, 5))
	btn.add_theme_stylebox_override("hover", make_panel_style(hover, border, radius, 2, 5))
	btn.add_theme_stylebox_override("pressed", make_panel_style(pressed, border.darkened(0.12), radius, 2, 2))
	btn.add_theme_stylebox_override("disabled", make_panel_style(Color(0.84, 0.88, 0.84), Color(0.70, 0.76, 0.72), radius, 2, 3))

	# Subtle tactile press squish
	if not btn.has_meta("_squish_bound"):
		btn.set_meta("_squish_bound", true)
		btn.button_down.connect(func():
			if btn.disabled:
				return
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(0.95, 0.93), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
		btn.button_up.connect(func():
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
