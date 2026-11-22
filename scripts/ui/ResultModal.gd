class_name ResultModal
extends CanvasLayer

signal next_requested
signal replay_requested
signal level_select_requested

var _title_label: Label
var _subtitle_label: Label
var _stars_row: HBoxContainer
var _star_icons: Array[Control] = []
var _next_btn: Button
var _replay_btn: Button


class BigStar extends Control:
	var lit: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)

	func _draw() -> void:
		var c := size * 0.5
		if lit:
			draw_circle(c, 32.0, Color(1.0, 0.86, 0.25, 0.28))
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var tip := c + Vector2.from_angle(a) * 28.0
				var l := c + Vector2.from_angle(a - 0.26) * 16.0
				var r := c + Vector2.from_angle(a + 0.26) * 16.0
				draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.14))
			draw_circle(c, 17.5, Color(1.0, 0.88, 0.26))
			draw_circle(c + Vector2(-4, -5), 5.5, Color(1.0, 0.97, 0.78, 0.85))
			draw_arc(c, 17.5, 0.0, TAU, 24, Color(0.84, 0.52, 0.08), 2.2, true)
		else:
			draw_circle(c, 20.0, Color(0.76, 0.82, 0.78, 0.65))
			draw_arc(c, 20.0, 0.0, TAU, 24, Color(0.54, 0.64, 0.56), 2.5, true)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.14, 0.10, 0.52)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(490, 430)
	card.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.98, 0.99, 0.95),
		Color(0.46, 0.68, 0.50),
		28,
		4
	))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", Color(0.18, 0.36, 0.22))
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 22)
	_subtitle_label.add_theme_color_override("font_color", Color(0.36, 0.48, 0.38))
	vbox.add_child(_subtitle_label)

	_stars_row = HBoxContainer.new()
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", 18)
	vbox.add_child(_stars_row)
	for i in range(3):
		var s := BigStar.new()
		_stars_row.add_child(s)
		_star_icons.append(s)

	_next_btn = Button.new()
	_next_btn.text = "NEXT LEVEL"
	_next_btn.custom_minimum_size = Vector2(0, 66)
	UIThemeHelper.style_button(_next_btn, Color(0.30, 0.72, 0.44), Color(0.36, 0.78, 0.50), Color(0.24, 0.60, 0.36), Color.WHITE, 26)
	_next_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		next_requested.emit()
	)
	vbox.add_child(_next_btn)

	_replay_btn = Button.new()
	_replay_btn.text = "TRY AGAIN"
	_replay_btn.custom_minimum_size = Vector2(0, 62)
	UIThemeHelper.style_button(_replay_btn, Color(0.86, 0.58, 0.28), Color(0.92, 0.64, 0.34), Color(0.74, 0.46, 0.20), Color.WHITE, 25)
	_replay_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		replay_requested.emit()
	)
	vbox.add_child(_replay_btn)

	var levels_btn := Button.new()
	levels_btn.text = "LEVEL SELECT"
	levels_btn.custom_minimum_size = Vector2(0, 56)
	UIThemeHelper.style_button(levels_btn, Color(0.46, 0.62, 0.54), Color(0.54, 0.70, 0.62), Color(0.38, 0.52, 0.45), Color.WHITE, 22)
	levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		level_select_requested.emit()
	)
	vbox.add_child(levels_btn)


func show_win(stars: int, has_next: bool) -> void:
	_title_label.text = "BLOOMED!"
	_title_label.add_theme_color_override("font_color", Color(0.18, 0.48, 0.26))
	match stars:
		3:
			_subtitle_label.text = "Perfect greenhouse harvest!"
		2:
			_subtitle_label.text = "Lovely! One more sun to discover."
		1:
			_subtitle_label.text = "The seedling is happy and watered!"
		_:
			_subtitle_label.text = "Seedling watered! Try grabbing the suns too."

	_stars_row.visible = true
	for i in range(3):
		var icon := _star_icons[i] as BigStar
		icon.lit = i < stars
		icon.queue_redraw()

	_next_btn.visible = has_next
	_replay_btn.text = "REPLAY"
	visible = true


func show_fail(reason: String) -> void:
	_title_label.text = "OOPS!"
	_title_label.add_theme_color_override("font_color", Color(0.72, 0.30, 0.24))
	match reason:
		"drain":
			_subtitle_label.text = "Slipped down the drain!"
		"evaporated":
			_subtitle_label.text = "Floated away into the sky!"
		_:
			_subtitle_label.text = "The droplet tumbled off the bench!"
	_stars_row.visible = false
	_next_btn.visible = false
	_replay_btn.text = "RETRY"
	visible = true
