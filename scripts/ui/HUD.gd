class_name HUD
extends CanvasLayer
## In-level heads-up display: top bar (pause, level, suns, hint, restart),
## the Water/Ice/Steam state dock, hint card, level banner and tutorial pulse.

signal pause_pressed
signal restart_pressed

const STATE_NAMES := ["WATER", "ICE", "STEAM"]

var _root: Control
var _top: HBoxContainer
var _level_num_label: Label
var _level_title_label: Label
var _restart_btn: Button
var _hint_btn: Button
var _star_nodes: Array[StarIcon] = []
var _chips: Array[StateChip] = []
var _dock: PanelContainer
var _hint_card: PanelContainer
var _hint_label: Label
var _hint_text: String = ""
var _hint_timer: float = 0.0
var _hint_shown_at: float = 0.0
var _banner: Control
var _banner_num: Label
var _banner_title: Label
var _banner_world: Label
var _tutorial: TapTutorial
var _fly_layer: Control
var _time: float = 0.0
var _active_state: int = 0


# ---------------------------------------------------------------- widgets
class StarIcon extends Control:
	var lit: bool = false
	var pop_scale: float = 1.0
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(42, 42)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func trigger_pop() -> void:
		pop_scale = 1.6
		var tw := create_tween()
		tw.tween_property(self, "pop_scale", 1.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		if lit or absf(pop_scale - 1.0) > 0.005:
			queue_redraw()

	func _draw() -> void:
		Art.draw_sun(self, size * 0.5, 17.0 * pop_scale, _t * 0.6 if lit else 0.0, lit)


class StateChip extends Control:
	var kind: int = 0
	var active: bool = false
	var art := DropletArt.new()
	var lift: float = 0.0
	var label_text: String = ""

	func _init(p_kind: int) -> void:
		kind = p_kind
		art.state = p_kind
		art.prev_state = p_kind
		art.size = 0.62
		custom_minimum_size = Vector2(150, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		art.advance(delta)
		lift = lerpf(lift, 1.0 if active else 0.0, clampf(delta * 12.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(4, 6 - lift * 4.0), size - Vector2(8, 12))
		var col := Art.state_color(kind)
		if kind == 2:
			col = Color(0.54, 0.66, 0.74)
		if lift > 0.02:
			Art.draw_rrect(self, Rect2(r.position + Vector2(0, 5), r.size), 20.0, Color(col.darkened(0.35), lift))
			Art.draw_rrect_grad(self, r, 20.0, Color(col.lightened(0.12), lift), Color(col, lift))
		if lift < 0.98:
			Art.draw_rrect(self, r, 20.0, Color(0.90, 0.93, 0.88, 0.85 * (1.0 - lift)))
		art.alpha = 0.55 + 0.45 * lift
		art.mood = "" if active else "sleepy"
		art.draw(self, Vector2(32, r.get_center().y + 1.0))
		var f := UIThemeHelper.get_display_font()
		if f != null:
			var tc := Color.WHITE if active else Color(0.46, 0.56, 0.50)
			var tp := Vector2(58, r.get_center().y + 8.0)
			if active:
				draw_string_outline(f, tp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(col.darkened(0.4), lift))
			draw_string(f, tp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tc)


class TapTutorial extends Control:
	var t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var press := 0.5 + 0.5 * sin(t * 4.0)
		for i in range(2):
			var ph := fmod(t * 0.9 + float(i) * 0.5, 1.0)
			draw_arc(c, 18.0 + ph * 40.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - ph)), 4.0, true)
		draw_circle(c, 14.0 + press * 3.0, Color(1, 1, 1, 0.9))
		draw_circle(c, 9.0 + press * 2.0, Color(0.20, 0.64, 0.90, 0.95))
		var f := UIThemeHelper.get_display_font()
		if f != null:
			var txt := "TAP ANYWHERE TO CHANGE STATE"
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			var p := Vector2(c.x - w * 0.5, c.y + 72.0)
			draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 8, Color(0.10, 0.30, 0.40, 0.9))
			draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


class FlyingStar extends Control:
	var start_pos: Vector2
	var end_pos: Vector2
	var ctrl_pos: Vector2
	var t: float = 0.0
	var duration: float = 0.55
	var on_arrive: Callable
	var trail: Array[Vector2] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta / duration
		if t >= 1.0:
			if on_arrive.is_valid():
				on_arrive.call()
			queue_free()
			return
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p := start_pos.lerp(ctrl_pos, e).lerp(ctrl_pos.lerp(end_pos, e), e)
		trail.push_front(p)
		if trail.size() > 8:
			trail.pop_back()
		queue_redraw()

	func _draw() -> void:
		for i in range(trail.size()):
			var a := 1.0 - float(i) / float(trail.size())
			Art.draw_sparkle(self, trail[i] + Vector2(sin(float(i) * 2.0) * 4.0, 0), 6.0 * a, Color(1.0, 0.95, 0.6, 0.8 * a))
		if not trail.is_empty():
			Art.draw_sun(self, trail[0], lerpf(26.0, 17.0, t), t * 9.0, true)


# ---------------------------------------------------------------- build
func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top_bar()
	_build_dock()
	_build_hint()
	_build_banner()
	_tutorial = TapTutorial.new()
	_tutorial.set_anchors_preset(Control.PRESET_CENTER)
	_tutorial.size = Vector2(500, 200)
	_tutorial.position = Vector2(-250, 0)
	_tutorial.visible = false
	_root.add_child(_tutorial)
	_fly_layer = Control.new()
	_fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fly_layer)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	var vp := get_viewport()
	_top.offset_top = UIThemeHelper.safe_top(vp) + 14.0
	_top.offset_bottom = _top.offset_top + 72.0
	var sb := UIThemeHelper.safe_bottom(vp)
	_dock.offset_bottom = -(sb + 16.0)
	_dock.offset_top = _dock.offset_bottom - 84.0
	_hint_card.offset_bottom = _dock.offset_top - 14.0
	_hint_card.offset_top = _hint_card.offset_bottom - 92.0


func _build_top_bar() -> void:
	_top = HBoxContainer.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = 18
	_top.offset_right = -18
	_top.add_theme_constant_override("separation", 10)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)

	var pause_btn := UIThemeHelper.make_icon_button("pause", UIThemeHelper.C_GREEN, 68)
	pause_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		pause_pressed.emit()
	)
	_top.add_child(pause_btn)

	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := UIThemeHelper.make_panel_style(Color(1.0, 0.985, 0.95, 0.94), Color(0.84, 0.88, 0.80), 22, 0, 5)
	ps.content_margin_top = 4
	ps.content_margin_bottom = 6
	ps.content_margin_left = 16
	pill.add_theme_stylebox_override("panel", ps)
	_top.add_child(pill)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(col)
	_level_num_label = UIThemeHelper.make_label("LEVEL 1", 16, Color(0.42, 0.58, 0.48), true, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(_level_num_label)
	_level_title_label = UIThemeHelper.make_label("Morning Dew", 25, UIThemeHelper.C_INK, true, HORIZONTAL_ALIGNMENT_LEFT)
	_level_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_title_label.clip_text = true
	col.add_child(_level_title_label)

	var stars_panel := PanelContainer.new()
	stars_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := UIThemeHelper.make_panel_style(Color(1.0, 0.985, 0.95, 0.94), Color(0.84, 0.88, 0.80), 22, 0, 5)
	ss.content_margin_left = 6
	ss.content_margin_right = 6
	ss.content_margin_top = 4
	ss.content_margin_bottom = 6
	stars_panel.add_theme_stylebox_override("panel", ss)
	_top.add_child(stars_panel)
	var stars_box := HBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 0)
	stars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_panel.add_child(stars_box)
	for i in range(3):
		var icon := StarIcon.new()
		stars_box.add_child(icon)
		_star_nodes.append(icon)

	_hint_btn = UIThemeHelper.make_icon_button("hint", Color(0.98, 0.76, 0.26), 56)
	_hint_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		if _hint_card.visible and _hint_card.modulate.a > 0.5:
			dismiss_hint(true)
		else:
			_show_hint()
	)
	_top.add_child(_hint_btn)

	_restart_btn = UIThemeHelper.make_icon_button("restart", UIThemeHelper.C_ORANGE, 68)
	_restart_btn.pressed.connect(func():
		restart_pressed.emit()
	)
	_top.add_child(_restart_btn)


func _build_dock() -> void:
	_dock = PanelContainer.new()
	_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dock.offset_left = -270
	_dock.offset_right = 270
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := UIThemeHelper.make_panel_style(Color(1.0, 0.985, 0.95, 0.94), Color(0.84, 0.88, 0.80), 30, 0, 5)
	bs.content_margin_left = 8
	bs.content_margin_right = 8
	bs.content_margin_top = 4
	bs.content_margin_bottom = 6
	_dock.add_theme_stylebox_override("panel", bs)
	_root.add_child(_dock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(row)
	for i in range(3):
		var chip := StateChip.new(i)
		chip.label_text = STATE_NAMES[i]
		row.add_child(chip)
		_chips.append(chip)
		if i < 2:
			var arrow := UIIcon.new()
			arrow.kind = "next"
			arrow.color = Color(0.70, 0.78, 0.72)
			arrow.shadow = false
			arrow.custom_minimum_size = Vector2(16, 70)
			row.add_child(arrow)


func _build_hint() -> void:
	_hint_card = PanelContainer.new()
	_hint_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_card.offset_left = 30
	_hint_card.offset_right = -30
	_hint_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := UIThemeHelper.make_panel_style(Color(0.17, 0.30, 0.24, 0.92), Color(0.10, 0.20, 0.16, 0.9), 24, 0, 5)
	hs.content_margin_left = 16
	hs.content_margin_right = 20
	hs.content_margin_top = 10
	hs.content_margin_bottom = 12
	_hint_card.add_theme_stylebox_override("panel", hs)
	_root.add_child(_hint_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_card.add_child(row)
	var bulb := UIIcon.new()
	bulb.kind = "hint"
	bulb.color = Color(1.0, 0.82, 0.34)
	bulb.custom_minimum_size = Vector2(40, 40)
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bulb)
	_hint_label = UIThemeHelper.make_label("", 20, Color(0.98, 0.99, 0.95), false, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hint_label)
	_hint_card.visible = false


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.size = Vector2(640, 220)
	_banner.position = Vector2(-320, -260)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_banner as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_banner as VBoxContainer).add_theme_constant_override("separation", -4)
	_root.add_child(_banner)
	_banner_world = UIThemeHelper.make_label("", 26, Color(1, 1, 1))
	_banner_world.add_theme_color_override("font_outline_color", Color(0.18, 0.40, 0.30, 0.95))
	_banner_world.add_theme_constant_override("outline_size", 10)
	_banner.add_child(_banner_world)
	_banner_num = UIThemeHelper.make_label("LEVEL 1", 34, Color(1.0, 0.86, 0.36))
	_banner_num.add_theme_color_override("font_outline_color", Color(0.46, 0.28, 0.06, 0.95))
	_banner_num.add_theme_constant_override("outline_size", 12)
	_banner.add_child(_banner_num)
	_banner_title = UIThemeHelper.make_label("Morning Dew", 58, Color.WHITE)
	_banner_title.add_theme_color_override("font_outline_color", Color(0.12, 0.34, 0.46, 0.95))
	_banner_title.add_theme_constant_override("outline_size", 16)
	_banner_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	_banner_title.add_theme_constant_override("shadow_offset_y", 6)
	_banner.add_child(_banner_title)
	_banner.visible = false


# ---------------------------------------------------------------- API
func configure_level(display_number: int, title: String, hint: String, show_hint: bool = true) -> void:
	_level_num_label.text = "LEVEL %d" % display_number
	_level_title_label.text = title
	set_stars(0)
	_hint_text = hint.strip_edges()
	_hint_btn.visible = not _hint_text.is_empty()
	if show_hint and not _hint_text.is_empty():
		_show_hint(1.5)
	else:
		_hint_card.visible = false


func _show_hint(delay: float = 0.0) -> void:
	if _hint_text.is_empty():
		return
	_hint_label.text = _hint_text
	_hint_card.visible = true
	_hint_card.modulate.a = 0.0
	_hint_timer = 8.0 + delay
	_hint_shown_at = _time + delay
	var tw := _hint_card.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_hint_card, "modulate:a", 1.0, 0.3)


## Hides the hint card (taps on the playfield call this; ignored right after it appears).
func dismiss_hint(force: bool = false) -> void:
	if not _hint_card.visible:
		return
	if not force and _time - _hint_shown_at < 1.2:
		return
	_hint_timer = minf(_hint_timer, 0.3)


func show_level_banner(display_number: int, title: String, world_name: String = "") -> void:
	_banner_num.text = "LEVEL %d" % display_number
	_banner_title.text = title
	_banner_world.text = world_name.to_upper()
	_banner_world.visible = world_name != ""
	_banner.visible = true
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.7, 0.7)
	_banner.modulate.a = 0.0
	var tw := _banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func(): _banner.visible = false)


func show_tap_tutorial(on: bool) -> void:
	_tutorial.visible = on
	_tutorial.modulate.a = 0.0
	if on:
		var tw := _tutorial.create_tween()
		tw.tween_interval(1.6)
		tw.tween_property(_tutorial, "modulate:a", 1.0, 0.4)


func get_restart_center() -> Vector2:
	return _restart_btn.get_global_rect().get_center()


func set_stars(count: int) -> void:
	var n := clampi(count, 0, 3)
	for i in range(_star_nodes.size()):
		_star_nodes[i].lit = i < n
		_star_nodes[i].queue_redraw()


func animate_star_collect(screen_pos: Vector2, star_slot_index: int) -> void:
	var idx := clampi(star_slot_index, 0, 2)
	var target_icon := _star_nodes[idx]
	var target_pos := target_icon.get_global_rect().get_center()
	var fly := FlyingStar.new()
	fly.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly.start_pos = screen_pos
	fly.end_pos = target_pos
	fly.ctrl_pos = Vector2(lerpf(screen_pos.x, target_pos.x, 0.3) - 80.0, minf(screen_pos.y, target_pos.y) - 60.0)
	fly.on_arrive = func():
		if is_instance_valid(target_icon):
			target_icon.lit = true
			target_icon.trigger_pop()
			AudioManager.play_sfx("star_whoosh", 1.0 + float(idx) * 0.1, -8.0)
	_fly_layer.add_child(fly)


func set_active_state(state_idx: int) -> void:
	_active_state = state_idx
	for i in range(_chips.size()):
		var was := _chips[i].active
		_chips[i].active = (i == state_idx)
		if _chips[i].active and not was:
			_chips[i].art.pop = 1.35
			var chip := _chips[i]
			var tw := chip.create_tween()
			tw.tween_property(chip.art, "pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _hint_card.visible and _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer < 0.3:
			_hint_card.modulate.a = clampf(_hint_timer / 0.3, 0.0, 1.0)
		if _hint_timer <= 0.0:
			_hint_card.visible = false
