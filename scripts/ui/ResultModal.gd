class_name ResultModal
extends CanvasLayer

signal next_requested
signal replay_requested
signal level_select_requested

var _card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _stars_row: HBoxContainer
var _star_icons: Array[Control] = []
var _next_btn: Button
var _replay_btn: Button


class BigStar extends Control:
	var lit: bool = false
	var pop_scale: float = 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(78, 78)

	func slam_in() -> void:
		lit = true
		pop_scale = 0.01
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(self, "pop_scale", 1.18, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "pop_scale", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		queue_redraw()

	func _process(_delta: float) -> void:
		if absf(pop_scale - 1.0) > 0.005:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if lit:
			var sc := pop_scale
			draw_circle(c, 35.0 * sc, Color(1.0, 0.86, 0.25, 0.30))
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var tip := c + Vector2.from_angle(a) * (30.0 * sc)
				var l := c + Vector2.from_angle(a - 0.26) * (17.0 * sc)
				var r := c + Vector2.from_angle(a + 0.26) * (17.0 * sc)
				draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.14))
			draw_circle(c, 18.5 * sc, Color(1.0, 0.89, 0.26))
			draw_circle(c + Vector2(-4.5, -5.5) * sc, 5.8 * sc, Color(1.0, 0.98, 0.80, 0.88))
			draw_arc(c, 18.5 * sc, 0.0, TAU, 24, Color(0.84, 0.52, 0.08), 2.3, true)
		else:
			draw_circle(c, 21.0, Color(0.76, 0.82, 0.78, 0.65))
			draw_arc(c, 21.0, 0.0, TAU, 24, Color(0.54, 0.64, 0.56), 2.5, true)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.14, 0.10, 0.54)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(506, 460)
	_card.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.99, 0.98, 0.94),
		Color(0.44, 0.68, 0.48),
		30,
		3,
		7
	))
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(_title_label, 48, Color(0.18, 0.44, 0.24))
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIThemeHelper.apply_body_font(_subtitle_label, 22, Color(0.36, 0.48, 0.38))
	vbox.add_child(_subtitle_label)

	_stars_row = HBoxContainer.new()
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_stars_row)
	for i in range(3):
		var s := BigStar.new()
		_stars_row.add_child(s)
		_star_icons.append(s)

	_next_btn = Button.new()
	_next_btn.text = "NEXT LEVEL"
	_next_btn.custom_minimum_size = Vector2(0, 68)
	UIThemeHelper.style_button(_next_btn, Color(0.28, 0.72, 0.44), Color(0.35, 0.78, 0.50), Color(0.22, 0.60, 0.36), Color.WHITE, 26, 20)
	_next_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		next_requested.emit()
	)
	vbox.add_child(_next_btn)

	_replay_btn = Button.new()
	_replay_btn.text = "TRY AGAIN"
	_replay_btn.custom_minimum_size = Vector2(0, 64)
	UIThemeHelper.style_button(_replay_btn, Color(0.88, 0.58, 0.26), Color(0.94, 0.65, 0.34), Color(0.76, 0.46, 0.18), Color.WHITE, 25, 18)
	_replay_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		replay_requested.emit()
	)
	vbox.add_child(_replay_btn)

	var levels_btn := Button.new()
	levels_btn.text = "LEVEL SELECT"
	levels_btn.custom_minimum_size = Vector2(0, 58)
	UIThemeHelper.style_button(levels_btn, Color(0.42, 0.62, 0.54), Color(0.50, 0.70, 0.62), Color(0.34, 0.52, 0.45), Color.WHITE, 22, 18)
	levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		level_select_requested.emit()
	)
	vbox.add_child(levels_btn)


func _pop_card() -> void:
	visible = true
	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.72, 0.72)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_win(stars: int, has_next: bool) -> void:
	_title_label.text = "BLOOMED!"
	_title_label.add_theme_color_override("font_color", Color(0.18, 0.50, 0.26))
	match stars:
		3:
			_subtitle_label.text = "Radiant! All 3 suns collected!"
		2:
			_subtitle_label.text = "Lovely! One more sun to discover."
		1:
			_subtitle_label.text = "The seedling is happy and watered!"
		_:
			_subtitle_label.text = "Seedling watered! Try grabbing the suns too."

	_stars_row.visible = true
	for i in range(3):
		var icon := _star_icons[i] as BigStar
		icon.lit = false
		icon.pop_scale = 1.0
		icon.queue_redraw()

	_next_btn.visible = has_next
	_replay_btn.text = "REPLAY"
	_pop_card()

	# Sequential star celebration pop-in with ascending chimes!
	for i in range(stars):
		var idx := i
		var timer := get_tree().create_timer(0.22 + float(idx) * 0.22)
		timer.timeout.connect(func():
			if is_instance_valid(self) and visible:
				(_star_icons[idx] as BigStar).slam_in()
				AudioManager.play_sfx("star_fanfare", 1.0 + float(idx) * 0.14, -2.0)
		)


func show_fail(reason: String) -> void:
	_title_label.text = "OOPS!"
	_title_label.add_theme_color_override("font_color", Color(0.74, 0.28, 0.22))
	match reason:
		"drain":
			_subtitle_label.text = "Slipped down the drain!"
		"hotplate":
			_subtitle_label.text = "Sizzled on the hot plate!"
		"evaporated":
			_subtitle_label.text = "Floated away into the sky!"
		_:
			_subtitle_label.text = "The droplet tumbled off the bench!"
	_stars_row.visible = false
	_next_btn.visible = false
	_replay_btn.text = "RETRY"
	_pop_card()
