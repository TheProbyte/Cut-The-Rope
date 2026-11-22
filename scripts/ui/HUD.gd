class_name HUD
extends CanvasLayer

signal pause_pressed
signal restart_pressed

var _level_label: Label
var _hint_panel: PanelContainer
var _hint_label: Label
var _star_nodes: Array[Control] = []
var _state_pills: Array[PanelContainer] = []
var _state_labels: Array[Label] = []
var _stars_collected: int = 0
var _active_state: int = 0
var _hint_timer: float = 0.0
var _fly_layer: Node2D


class StarIcon extends Control:
	var lit: bool = false
	var pop_scale: float = 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)

	func trigger_pop() -> void:
		pop_scale = 1.45
		var tw := create_tween()
		tw.tween_property(self, "pop_scale", 1.0, 0.30).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _process(_delta: float) -> void:
		if absf(pop_scale - 1.0) > 0.005:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var sc := pop_scale
		if lit:
			draw_circle(c, 17.5 * sc, Color(1.0, 0.86, 0.25, 0.34))
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var tip := c + Vector2.from_angle(a) * (15.5 * sc)
				var l := c + Vector2.from_angle(a - 0.28) * (8.5 * sc)
				var r := c + Vector2.from_angle(a + 0.28) * (8.5 * sc)
				draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.14))
			draw_circle(c, 9.2 * sc, Color(1.0, 0.89, 0.28))
			draw_circle(c + Vector2(-2.5, -2.8) * sc, 3.0 * sc, Color(1.0, 0.98, 0.82, 0.88))
			draw_arc(c, 9.2 * sc, 0.0, TAU, 18, Color(0.84, 0.52, 0.08), 1.6, true)
		else:
			draw_circle(c, 11.0, Color(0.72, 0.79, 0.73, 0.55))
			draw_arc(c, 11.0, 0.0, TAU, 18, Color(0.48, 0.58, 0.50, 0.75), 2.0, true)


class StateGlyph extends Control:
	var kind: int = 0
	var active: bool = false

	func _init(p_kind: int) -> void:
		kind = p_kind
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var alpha := 1.0 if active else 0.55
		match kind:
			0: # Water
				draw_circle(c + Vector2(0, 3), 8.2, Color(1, 1, 1, alpha) if active else Color(0.20, 0.64, 0.86, alpha))
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -10), c + Vector2(7.5, 2), c + Vector2(-7.5, 2),
				]), Color(1, 1, 1, alpha) if active else Color(0.20, 0.64, 0.86, alpha))
			1: # Ice
				var s := 8.5
				var col := Color(1, 1, 1, alpha) if active else Color(0.35, 0.72, 0.90, alpha)
				draw_rect(Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), col)
				draw_line(c + Vector2(-5, -4), c + Vector2(-1, -7), Color(0.70, 0.94, 1.0, alpha), 1.8)
			2: # Steam
				var col := Color(1, 1, 1, alpha) if active else Color(0.46, 0.58, 0.60, alpha)
				draw_circle(c + Vector2(-5.5, 2.5), 5.5, col)
				draw_circle(c + Vector2(5.5, 2.5), 5.5, col)
				draw_circle(c + Vector2(0.0, -3.0), 6.5, col)


class FlyingStar extends Node2D:
	var start_pos: Vector2
	var end_pos: Vector2
	var ctrl_pos: Vector2
	var t: float = 0.0
	var duration: float = 0.46
	var on_arrive: Callable

	func _process(delta: float) -> void:
		t += delta / duration
		if t >= 1.0:
			if on_arrive.is_valid():
				on_arrive.call()
			queue_free()
			return
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p1 := start_pos.lerp(ctrl_pos, e)
		var p2 := ctrl_pos.lerp(end_pos, e)
		position = p1.lerp(p2, e)
		rotation += delta * 9.0
		queue_redraw()

	func _draw() -> void:
		var sc := lerpf(1.25, 0.78, t)
		draw_circle(Vector2.ZERO, 18.0 * sc, Color(1.0, 0.88, 0.30, 0.35))
		for i in range(8):
			var a := TAU * float(i) / 8.0
			var tip := Vector2.from_angle(a) * (15.0 * sc)
			var l := Vector2.from_angle(a - 0.28) * (8.0 * sc)
			var r := Vector2.from_angle(a + 0.28) * (8.0 * sc)
			draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.78, 0.16))
		draw_circle(Vector2.ZERO, 9.0 * sc, Color(1.0, 0.90, 0.30))


var _state_glyphs: Array[StateGlyph] = []


func _ready() -> void:
	layer = 10
	_build_ui()
	_fly_layer = Node2D.new()
	add_child(_fly_layer)


func _build_ui() -> void:
	# Cozy rounded cream top HUD bar
	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(18, 12)
	top_bar.size = Vector2(684, 74)
	top_bar.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.99, 0.98, 0.94, 0.95),
		Color(0.56, 0.72, 0.58),
		24,
		2,
		4
	))
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(hbox)

	var pause_btn := Button.new()
	pause_btn.text = "||"
	pause_btn.custom_minimum_size = Vector2(54, 48)
	UIThemeHelper.style_button(
		pause_btn,
		Color(0.40, 0.68, 0.50),
		Color(0.46, 0.74, 0.56),
		Color(0.32, 0.58, 0.42),
		Color.WHITE,
		22,
		15
	)
	pause_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		pause_pressed.emit()
	)
	hbox.add_child(pause_btn)

	_level_label = Label.new()
	_level_label.text = "1. Morning Dew"
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(_level_label, 25, Color(0.18, 0.34, 0.24))
	hbox.add_child(_level_label)

	var stars_box := HBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 2)
	stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(stars_box)
	for i in range(3):
		var icon := StarIcon.new()
		stars_box.add_child(icon)
		_star_nodes.append(icon)

	var restart_btn := Button.new()
	restart_btn.text = "↻"
	restart_btn.custom_minimum_size = Vector2(54, 48)
	UIThemeHelper.style_button(
		restart_btn,
		Color(0.88, 0.56, 0.28),
		Color(0.94, 0.64, 0.34),
		Color(0.76, 0.46, 0.20),
		Color.WHITE,
		28,
		15
	)
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		restart_pressed.emit()
	)
	hbox.add_child(restart_btn)

	# Hint toast
	_hint_panel = PanelContainer.new()
	_hint_panel.position = Vector2(40, 1106)
	_hint_panel.size = Vector2(640, 58)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.16, 0.28, 0.21, 0.88),
		Color(0.56, 0.78, 0.62, 0.80),
		18,
		2,
		3
	))
	add_child(_hint_panel)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIThemeHelper.apply_body_font(_hint_label, 19, Color(0.98, 0.99, 0.95))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(_hint_label)

	# Bottom illustrated 3-state dock
	var state_bar := PanelContainer.new()
	state_bar.position = Vector2(74, 1184)
	state_bar.size = Vector2(572, 78)
	state_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_bar.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.99, 0.98, 0.94, 0.95),
		Color(0.56, 0.72, 0.58),
		26,
		2,
		4
	))
	add_child(state_bar)

	var state_row := HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 8)
	state_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_bar.add_child(state_row)

	var names := ["WATER", "ICE", "STEAM"]
	for i in range(3):
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_row.add_child(pill)

		var inner := HBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 6)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(inner)

		var glyph := StateGlyph.new(i)
		inner.add_child(glyph)
		_state_glyphs.append(glyph)

		var lbl := Label.new()
		lbl.text = names[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIThemeHelper.apply_display_font(lbl, 19, Color(0.32, 0.44, 0.36))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(lbl)

		_state_pills.append(pill)
		_state_labels.append(lbl)

		if i < 2:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UIThemeHelper.apply_display_font(arrow, 24, Color(0.56, 0.68, 0.58))
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			state_row.add_child(arrow)

	set_active_state(0)


func configure_level(display_number: int, title: String, hint: String) -> void:
	_level_label.text = "%d. %s" % [display_number, title]
	set_stars(0)
	if hint.strip_edges().is_empty():
		_hint_panel.visible = false
	else:
		_hint_label.text = hint
		_hint_panel.visible = true
		_hint_panel.modulate.a = 1.0
		_hint_timer = 7.5


func set_stars(count: int) -> void:
	_stars_collected = clampi(count, 0, 3)
	for i in range(_star_nodes.size()):
		var star := _star_nodes[i] as StarIcon
		star.lit = i < _stars_collected
		star.queue_redraw()


func animate_star_collect(world_pos: Vector2, star_slot_index: int) -> void:
	var idx := clampi(star_slot_index, 0, 2)
	var target_icon := _star_nodes[idx] as StarIcon
	var target_pos := target_icon.global_position + target_icon.size * 0.5

	var fly := FlyingStar.new()
	fly.start_pos = world_pos
	fly.end_pos = target_pos
	fly.ctrl_pos = Vector2((world_pos.x + target_pos.x) * 0.5 - 70.0, minf(world_pos.y, target_pos.y) - 90.0)
	fly.position = world_pos
	fly.on_arrive = func():
		if is_instance_valid(target_icon):
			target_icon.lit = true
			target_icon.trigger_pop()
			target_icon.queue_redraw()
	_fly_layer.add_child(fly)


func set_active_state(state_idx: int) -> void:
	_active_state = state_idx
	var active_colors := [
		Color(0.16, 0.66, 0.92),
		Color(0.36, 0.76, 0.96),
		Color(0.56, 0.70, 0.74),
	]
	for i in range(3):
		var is_active := (i == _active_state)
		var bg: Color = active_colors[i] if is_active else Color(0.90, 0.94, 0.89, 0.65)
		var border: Color = bg.darkened(0.24) if is_active else Color(0.74, 0.82, 0.74, 0.6)
		_state_pills[i].add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(bg, border, 16, 2, 3 if is_active else 1))
		_state_labels[i].add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.38, 0.50, 0.42))
		_state_glyphs[i].active = is_active
		_state_glyphs[i].queue_redraw()
		if is_active:
			var pill := _state_pills[i]
			pill.pivot_offset = pill.size * 0.5
			pill.scale = Vector2(1.08, 1.08)
			var tw := pill.create_tween()
			tw.tween_property(pill, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _hint_panel.visible and _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer < 1.2:
			_hint_panel.modulate.a = clampf(_hint_timer / 1.2, 0.0, 1.0)
		if _hint_timer <= 0.0:
			_hint_panel.visible = false
