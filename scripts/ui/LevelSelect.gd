class_name LevelSelect
extends Node2D

signal level_selected(world_id: String, level_index: int)
signal back_pressed

const WORLD_ID := "greenhouse"


class MiniStars extends Control:
	var count: int = 0
	var locked: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(120, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if locked:
			return
		var spacing := 34.0
		var start_x := size.x * 0.5 - spacing
		var cy := size.y * 0.5
		for i in range(3):
			var c := Vector2(start_x + float(i) * spacing, cy)
			if i < count:
				for k in range(8):
					var a := TAU * float(k) / 8.0
					var tip := c + Vector2.from_angle(a) * 12.0
					var l := c + Vector2.from_angle(a - 0.28) * 6.5
					var r := c + Vector2.from_angle(a + 0.28) * 6.5
					draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.14))
				draw_circle(c, 7.5, Color(1.0, 0.88, 0.26))
			else:
				draw_circle(c, 8.5, Color(0.76, 0.82, 0.78, 0.7))
				draw_arc(c, 8.5, 0.0, TAU, 16, Color(0.54, 0.64, 0.56), 1.8, true)


func _ready() -> void:
	add_child(GreenhouseBackground.new())
	_build_ui()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# Header bar
	var header := PanelContainer.new()
	header.position = Vector2(24, 24)
	header.size = Vector2(672, 84)
	header.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.97, 0.99, 0.94, 0.94),
		Color(0.56, 0.74, 0.58),
		24,
		3
	))
	ui.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	header.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "←"
	back_btn.custom_minimum_size = Vector2(60, 52)
	UIThemeHelper.style_button(back_btn, Color(0.46, 0.68, 0.52), Color(0.54, 0.74, 0.58), Color(0.38, 0.58, 0.44), Color.WHITE, 28, 16)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		back_pressed.emit()
	)
	hbox.add_child(back_btn)

	var title := Label.new()
	title.text = "WORLD 1: GREENHOUSE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.18, 0.36, 0.22))
	hbox.add_child(title)

	var stars_info := SaveManager.get_world_stars(WORLD_ID)
	var badge := Label.new()
	badge.text = "★ %d/%d" % [stars_info.x, stars_info.y]
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 26)
	badge.add_theme_color_override("font_color", Color(0.84, 0.56, 0.08))
	hbox.add_child(badge)

	# 2x5 grid of 10 Greenhouse levels
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(34, 140)
	grid.size = Vector2(652, 1080)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	ui.add_child(grid)

	var levels := LevelRegistry.get_world_levels(WORLD_ID)
	for i in range(levels.size()):
		var lvl: Dictionary = levels[i]
		var lvl_id := String(lvl.get("id", "greenhouse_%02d" % (i + 1)))
		var lvl_title := String(lvl.get("title", "Level %d" % (i + 1)))
		var unlocked := SaveManager.is_level_unlocked(WORLD_ID, i)
		var earned := SaveManager.get_stars(lvl_id)
		var completed := SaveManager.is_completed(lvl_id)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(316, 192)
		btn.disabled = not unlocked
		var bg := Color(0.96, 0.99, 0.94) if unlocked else Color(0.84, 0.88, 0.84)
		var hover := Color(0.90, 0.97, 0.89)
		var pressed := Color(0.82, 0.93, 0.82)
		if completed:
			bg = Color(0.92, 0.98, 0.91)
		UIThemeHelper.style_button(btn, bg, hover, pressed, Color(0.18, 0.34, 0.22), 20, 22)

		var idx := i
		btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap")
			level_selected.emit(WORLD_ID, idx)
		)
		grid.add_child(btn)

		var card_vbox := VBoxContainer.new()
		card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", 6)
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(card_vbox)

		var num_lbl := Label.new()
		num_lbl.text = "%d" % (i + 1) if unlocked else "🔒 %d" % (i + 1)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 42)
		num_lbl.add_theme_color_override("font_color", Color(0.16, 0.50, 0.66) if unlocked else Color(0.52, 0.58, 0.54))
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(num_lbl)

		var name_lbl := Label.new()
		name_lbl.text = lvl_title
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.add_theme_color_override("font_color", Color(0.22, 0.38, 0.26) if unlocked else Color(0.52, 0.58, 0.54))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(name_lbl)

		var stars_ctrl := MiniStars.new()
		stars_ctrl.count = earned
		stars_ctrl.locked = not unlocked
		card_vbox.add_child(stars_ctrl)
