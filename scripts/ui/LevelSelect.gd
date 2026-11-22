class_name LevelSelect
extends Node2D

signal level_selected(world_id: String, level_index: int)
signal back_pressed

var active_world: String = "greenhouse"

var _bg: GreenhouseBackground
var _badge_label: Label
var _grid: GridContainer
var _tab_buttons: Dictionary = {}


class MiniStars extends Control:
	var count: int = 0
	var locked: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(126, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if locked:
			return
		var spacing := 36.0
		var start_x := size.x * 0.5 - spacing
		var cy := size.y * 0.5
		for i in range(3):
			var c := Vector2(start_x + float(i) * spacing, cy)
			if i < count:
				for k in range(8):
					var a := TAU * float(k) / 8.0
					var tip := c + Vector2.from_angle(a) * 13.0
					var l := c + Vector2.from_angle(a - 0.28) * 7.0
					var r := c + Vector2.from_angle(a + 0.28) * 7.0
					draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1.0, 0.76, 0.14))
				draw_circle(c, 8.0, Color(1.0, 0.89, 0.26))
			else:
				draw_circle(c, 9.0, Color(0.76, 0.82, 0.78, 0.7))
				draw_arc(c, 9.0, 0.0, TAU, 16, Color(0.54, 0.64, 0.56), 1.9, true)


func _ready() -> void:
	_bg = GreenhouseBackground.new()
	add_child(_bg)
	_build_ui()
	_select_world(active_world, false)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# Header bar
	var header := PanelContainer.new()
	header.position = Vector2(22, 18)
	header.size = Vector2(676, 80)
	header.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.99, 0.98, 0.94, 0.95),
		Color(0.56, 0.74, 0.58),
		24,
		2,
		5
	))
	ui.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	header.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "←"
	back_btn.custom_minimum_size = Vector2(60, 50)
	UIThemeHelper.style_button(back_btn, Color(0.42, 0.68, 0.50), Color(0.50, 0.74, 0.58), Color(0.34, 0.58, 0.42), Color.WHITE, 28, 16)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		back_pressed.emit()
	)
	hbox.add_child(back_btn)

	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(title, 30, Color(0.18, 0.36, 0.24))
	hbox.add_child(title)

	_badge_label = Label.new()
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(_badge_label, 28, Color(0.84, 0.54, 0.08))
	hbox.add_child(_badge_label)

	# World switcher tabs (World 1: Greenhouse | World 2: Kitchen)
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(28, 114)
	tab_row.size = Vector2(664, 64)
	tab_row.add_theme_constant_override("separation", 14)
	ui.add_child(tab_row)

	var worlds := LevelRegistry.get_worlds()
	for i in range(worlds.size()):
		var w: Dictionary = worlds[i]
		var w_id := String(w.get("id", "greenhouse"))
		var w_name := String(w.get("name", "World"))
		var tab_btn := Button.new()
		tab_btn.text = "%d. %s" % [i + 1, w_name.to_upper()]
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.custom_minimum_size = Vector2(0, 60)
		var captured_id := w_id
		tab_btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap")
			_select_world(captured_id, true)
		)
		tab_row.add_child(tab_btn)
		_tab_buttons[w_id] = tab_btn

	# 2x5 grid of 10 levels for the active world
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.position = Vector2(32, 194)
	_grid.size = Vector2(656, 1055)
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 16)
	ui.add_child(_grid)


func _select_world(world_id: String, animate_cards: bool) -> void:
	active_world = world_id
	_bg.set_theme(world_id)

	# Refresh world tab styling
	for wid: String in _tab_buttons.keys():
		var btn: Button = _tab_buttons[wid]
		var is_sel: bool = (wid == active_world)
		var sel_bg := Color(0.28, 0.70, 0.44) if wid == "greenhouse" else Color(0.84, 0.54, 0.28)
		var bg := sel_bg if is_sel else Color(0.95, 0.96, 0.92)
		var txt := Color.WHITE if is_sel else Color(0.32, 0.42, 0.34)
		UIThemeHelper.style_button(btn, bg, bg.lightened(0.06), bg.darkened(0.08), txt, 23, 18)

	var stars_info := SaveManager.get_world_stars(active_world)
	_badge_label.text = "★ %d/%d" % [stars_info.x, stars_info.y]

	for c in _grid.get_children():
		c.queue_free()

	var levels := LevelRegistry.get_world_levels(active_world)
	var num_offset := 10 if active_world == "kitchen" else 0
	for i in range(levels.size()):
		var lvl: Dictionary = levels[i]
		var lvl_id := String(lvl.get("id", "%s_%02d" % [active_world, i + 1]))
		var lvl_title := String(lvl.get("title", "Level %d" % (i + 1 + num_offset)))
		var unlocked := SaveManager.is_level_unlocked(active_world, i)
		var earned := SaveManager.get_stars(lvl_id)
		var completed := SaveManager.is_completed(lvl_id)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(318, 184)
		btn.disabled = not unlocked
		var bg := Color(0.98, 0.99, 0.95) if unlocked else Color(0.86, 0.89, 0.85)
		if completed:
			bg = Color(0.92, 0.98, 0.91) if active_world == "greenhouse" else Color(0.99, 0.95, 0.88)
		UIThemeHelper.style_button(btn, bg, bg.darkened(0.04), bg.darkened(0.10), Color(0.18, 0.34, 0.22), 20, 24)

		var idx := i
		var wid := active_world
		btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap")
			level_selected.emit(wid, idx)
		)
		_grid.add_child(btn)

		var card_vbox := VBoxContainer.new()
		card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", 4)
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(card_vbox)

		var num_lbl := Label.new()
		var display_n := i + 1 + num_offset
		num_lbl.text = "%d" % display_n if unlocked else "🔒 %d" % display_n
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var num_col := (Color(0.16, 0.52, 0.72) if active_world == "greenhouse" else Color(0.78, 0.44, 0.20)) if unlocked else Color(0.52, 0.58, 0.54)
		UIThemeHelper.apply_display_font(num_lbl, 42, num_col)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(num_lbl)

		var name_lbl := Label.new()
		name_lbl.text = lvl_title
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIThemeHelper.apply_body_font(name_lbl, 21, Color(0.22, 0.38, 0.26) if unlocked else Color(0.52, 0.58, 0.54))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(name_lbl)

		var stars_ctrl := MiniStars.new()
		stars_ctrl.count = earned
		stars_ctrl.locked = not unlocked
		card_vbox.add_child(stars_ctrl)

		if animate_cards:
			btn.modulate.a = 0.0
			var tw := btn.create_tween()
			tw.tween_interval(float(i) * 0.025)
			tw.tween_property(btn, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
