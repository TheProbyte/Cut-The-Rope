class_name UIThemeHelper
extends RefCounted
## Fonts, button styles, vector icons and layout helpers shared by every screen.

const FREDOKA_PATH := "res://assets/fonts/Fredoka-SemiBold.ttf"
const NUNITO_PATH := "res://assets/fonts/Nunito-Bold.ttf"

const DESIGN_SIZE := Vector2(720, 1280)

const C_GREEN := Color(0.30, 0.74, 0.44)
const C_BLUE := Color(0.20, 0.64, 0.90)
const C_ORANGE := Color(0.95, 0.60, 0.26)
const C_SAGE := Color(0.46, 0.64, 0.54)
const C_CREAM := Color(1.0, 0.985, 0.95)
const C_INK := Color(0.18, 0.30, 0.22)
const C_MUTED := Color(0.62, 0.68, 0.64)

static var _display_font: Font = null
static var _body_font: Font = null


# ---------------------------------------------------------------- fonts
static func get_display_font() -> Font:
	if _display_font == null and ResourceLoader.exists(FREDOKA_PATH):
		var fv := FontVariation.new()
		fv.base_font = load(FREDOKA_PATH)
		fv.variation_opentype = {2003265652: 650}
		_display_font = fv
	return _display_font


static func get_body_font() -> Font:
	if _body_font == null and ResourceLoader.exists(NUNITO_PATH):
		var fv := FontVariation.new()
		fv.base_font = load(NUNITO_PATH)
		fv.variation_opentype = {2003265652: 750}
		_body_font = fv
	return _body_font


static func apply_display_font(ctrl: Control, font_size: int, color: Color = C_INK) -> void:
	var f := get_display_font()
	if f != null:
		ctrl.add_theme_font_override("font", f)
	ctrl.add_theme_font_size_override("font_size", font_size)
	ctrl.add_theme_color_override("font_color", color)


static func apply_body_font(ctrl: Control, font_size: int, color: Color = Color(0.26, 0.38, 0.30)) -> void:
	var f := get_body_font()
	if f != null:
		ctrl.add_theme_font_override("font", f)
	ctrl.add_theme_font_size_override("font_size", font_size)
	ctrl.add_theme_color_override("font_color", color)


static func make_label(text: String, size: int, color: Color = C_INK, display: bool = true, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display:
		apply_display_font(l, size, color)
	else:
		apply_body_font(l, size, color)
	return l


# ---------------------------------------------------------------- styles
static func make_panel_style(bg: Color, border: Color, radius: int = 22, border_w: int = 3, bottom_lip: int = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_right = border_w
	s.border_width_top = border_w
	s.border_width_bottom = border_w + bottom_lip
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.shadow_color = Color(0.10, 0.18, 0.14, 0.16)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s


static func make_card_style(radius: int = 34) -> StyleBoxFlat:
	var s := make_panel_style(C_CREAM, Color(0.80, 0.86, 0.78), radius, 0, 0)
	s.border_width_bottom = 8
	s.border_color = Color(0.86, 0.88, 0.80)
	s.shadow_color = Color(0.06, 0.14, 0.10, 0.30)
	s.shadow_size = 28
	s.shadow_offset = Vector2(0, 14)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 26
	s.content_margin_bottom = 30
	return s


static func style_button(btn: Button, bg: Color, hover: Color, pressed: Color, text_col: Color = Color.WHITE, font_size: int = 26, radius: int = 20) -> void:
	var f := get_display_font()
	if f != null:
		btn.add_theme_font_override("font", f)
	btn.add_theme_font_size_override("font_size", font_size)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(k, text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.58, 0.64, 0.60))
	btn.add_theme_color_override("font_outline_color", bg.darkened(0.42))
	btn.add_theme_constant_override("outline_size", 3 if text_col == Color.WHITE else 0)
	btn.focus_mode = Control.FOCUS_NONE

	var lip := bg.darkened(0.28)
	var normal := make_panel_style(bg, lip, radius, 0, 6)
	normal.border_width_left = 0
	normal.border_width_right = 0
	normal.border_width_top = 0
	btn.add_theme_stylebox_override("normal", normal)
	var hov := normal.duplicate() as StyleBoxFlat
	hov.bg_color = hover
	btn.add_theme_stylebox_override("hover", hov)
	var prs := normal.duplicate() as StyleBoxFlat
	prs.bg_color = pressed
	prs.border_width_bottom = 2
	prs.content_margin_top += 4
	prs.shadow_size = 4
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_stylebox_override("hover_pressed", prs)
	var dis := normal.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.86, 0.89, 0.86)
	dis.border_color = Color(0.74, 0.78, 0.75)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_press_bounce(btn)


static func style_primary(btn: Button, color: Color, font_size: int = 30, radius: int = 26) -> void:
	style_button(btn, color, color.lightened(0.08), color.darkened(0.06), Color.WHITE, font_size, radius)


## Springy squish on press, used by every tappable control.
static func add_press_bounce(btn: BaseButton) -> void:
	if btn.has_meta("_squish_bound"):
		return
	btn.set_meta("_squish_bound", true)
	btn.button_down.connect(func():
		if btn.disabled:
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(0.93, 0.91), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_haptic(8)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


static func _haptic(ms: int) -> void:
	SaveManager.haptic(ms)


## Round chunky button with a vector icon.
static func make_icon_button(kind: String, color: Color, diameter: float = 64.0, icon_color: Color = Color.WHITE) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.focus_mode = Control.FOCUS_NONE
	style_button(btn, color, color.lightened(0.08), color.darkened(0.06), Color.WHITE, 20, int(diameter * 0.5))
	var icon := UIIcon.new()
	icon.kind = kind
	icon.color = icon_color
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -4.0
	btn.add_child(icon)
	btn.set_meta("icon", icon)
	return btn


static func set_icon(btn: Button, kind: String) -> void:
	var icon: UIIcon = btn.get_meta("icon", null)
	if icon != null:
		icon.kind = kind
		icon.queue_redraw()


# ---------------------------------------------------------------- layout
## Top inset (in viewport units) to keep UI clear of notches/cutouts.
static func safe_top(vp: Viewport) -> float:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var inset := float(safe.position.y)
	if inset <= 0.0 or inset > float(win.y) * 0.2:
		return 0.0
	return inset * (vp.get_visible_rect().size.y / float(win.y))


static func safe_bottom(vp: Viewport) -> float:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var inset := float(win.y - safe.end.y)
	if inset <= 0.0 or inset > float(win.y) * 0.2:
		return 0.0
	return inset * (vp.get_visible_rect().size.y / float(win.y))


## Offset that vertically centers the 720x1280 design area in the viewport.
static func design_offset(vp: Viewport) -> float:
	return (vp.get_visible_rect().size.y - DESIGN_SIZE.y) * 0.5


static func pop_in(ctrl: CanvasItem, delay: float = 0.0, from_scale: float = 0.6, dur: float = 0.38) -> void:
	ctrl.scale = Vector2(from_scale, from_scale)
	ctrl.modulate.a = 0.0
	var tw := ctrl.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(maxf(delay, 0.02))
	if ctrl is Control:
		var c := ctrl as Control
		tw.tween_callback(func(): c.pivot_offset = c.size * 0.5)
	tw.set_parallel(true)
	tw.tween_property(ctrl, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "modulate:a", 1.0, dur * 0.5)


static func slide_in(ctrl: Control, from_offset: Vector2, delay: float = 0.0, dur: float = 0.45) -> void:
	var target := ctrl.position
	ctrl.position = target + from_offset
	ctrl.modulate.a = 0.0
	var tw := ctrl.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(ctrl, "position", target, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "modulate:a", 1.0, dur * 0.6)
