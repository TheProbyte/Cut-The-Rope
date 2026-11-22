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


class StarIcon extends Control:
	var lit: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(36, 36)

	func _draw() -> void:
		var c := size * 0.5
		if lit:
			draw_circle(c, 16.0, Color(1.0, 0.86, 0.25, 0.30))
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var tip := c + Vector2.from_angle(a) * 14.5
				var l := c + Vector2.from_angle(a - 0.28) * 8.0
				var r := c + Vector2.from_angle(a + 0.28) * 8.0
				draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.14))
			draw_circle(c, 8.8, Color(1.0, 0.88, 0.26))
			draw_arc(c, 8.8, 0.0, TAU, 18, Color(0.84, 0.52, 0.08), 1.6, true)
		else:
			draw_circle(c, 10.5, Color(0.70, 0.78, 0.72, 0.55))
			draw_arc(c, 10.5, 0.0, TAU, 18, Color(0.48, 0.58, 0.50, 0.75), 2.0, true)


func _ready() -> void:
	layer = 10
	_build_ui()


func _build_ui() -> void:
	# Top HUD bar
	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(18, 14)
	top_bar.size = Vector2(684, 72)
	top_bar.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.97, 0.99, 0.94, 0.92),
		Color(0.60, 0.76, 0.62),
		22,
		2
	))
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(hbox)

	var pause_btn := Button.new()
	pause_btn.text = "||"
	pause_btn.custom_minimum_size = Vector2(54, 48)
	UIThemeHelper.style_button(
		pause_btn,
		Color(0.46, 0.68, 0.52),
		Color(0.52, 0.74, 0.58),
		Color(0.38, 0.58, 0.44),
		Color.WHITE,
		22,
		14
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
	_level_label.add_theme_font_size_override("font_size", 24)
	_level_label.add_theme_color_override("font_color", Color(0.18, 0.32, 0.22))
	hbox.add_child(_level_label)

	# 3 sun collectible slots
	var stars_box := HBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 4)
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
		Color(0.86, 0.58, 0.30),
		Color(0.92, 0.65, 0.36),
		Color(0.74, 0.46, 0.22),
		Color.WHITE,
		28,
		14
	)
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		restart_pressed.emit()
	)
	hbox.add_child(restart_btn)

	# Hint toast above bottom state bar
	_hint_panel = PanelContainer.new()
	_hint_panel.position = Vector2(46, 1112)
	_hint_panel.size = Vector2(628, 54)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.18, 0.30, 0.22, 0.84),
		Color(0.58, 0.78, 0.62, 0.75),
		16,
		2
	))
	add_child(_hint_panel)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.95))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(_hint_label)

	# Bottom 3-state tactile indicator bar (non-blocking display)
	var state_bar := PanelContainer.new()
	state_bar.position = Vector2(96, 1188)
	state_bar.size = Vector2(528, 74)
	state_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_bar.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.97, 0.99, 0.94, 0.92),
		Color(0.60, 0.76, 0.62),
		24,
		2
	))
	add_child(state_bar)

	var state_row := HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 10)
	state_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_bar.add_child(state_row)

	var names := ["WATER", "ICE", "STEAM"]
	for i in range(3):
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_row.add_child(pill)

		var lbl := Label.new()
		lbl.text = names[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(lbl)

		_state_pills.append(pill)
		_state_labels.append(lbl)

	set_active_state(0)


func configure_level(index: int, title: String, hint: String) -> void:
	_level_label.text = "%d. %s" % [index + 1, title]
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


func set_active_state(state_idx: int) -> void:
	_active_state = state_idx
	var active_colors := [
		Color(0.18, 0.68, 0.92),
		Color(0.42, 0.78, 0.96),
		Color(0.62, 0.74, 0.76),
	]
	for i in range(3):
		var is_active := (i == _active_state)
		var bg: Color = active_colors[i] if is_active else Color(0.88, 0.93, 0.88, 0.65)
		var border: Color = bg.darkened(0.22) if is_active else Color(0.72, 0.80, 0.74, 0.6)
		_state_pills[i].add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(bg, border, 16, 2))
		_state_labels[i].add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.36, 0.48, 0.40))


func _process(delta: float) -> void:
	if _hint_panel.visible and _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer < 1.2:
			_hint_panel.modulate.a = clampf(_hint_timer / 1.2, 0.0, 1.0)
		if _hint_timer <= 0.0:
			_hint_panel.visible = false
