class_name MainMenu
extends Node2D

signal play_pressed
signal levels_pressed

var _music_btn: Button
var _sfx_btn: Button
var _hero: Node2D


class MenuHero extends Node2D:
	var _time: float = 0.0
	var _demo_state: int = 0
	var _state_timer: float = 0.0
	var _morph_pop: float = 1.0

	func _process(delta: float) -> void:
		_time += delta
		_state_timer += delta
		_morph_pop = lerpf(_morph_pop, 1.0, clampf(delta * 9.0, 0.0, 1.0))
		if _state_timer > 2.3:
			_state_timer = 0.0
			_demo_state = (_demo_state + 1) % 3
			_morph_pop = 1.28
		queue_redraw()

	func _draw() -> void:
		# Cozy greenhouse cedar shelf with little sprouting leaves
		var shelf := Rect2(124, 560, 472, 28)
		draw_rect(Rect2(128, 568, 472, 28), Color(0.10, 0.20, 0.12, 0.20))
		draw_rect(shelf, Color(0.70, 0.50, 0.30))
		draw_rect(Rect2(124, 560, 472, 10), Color(0.86, 0.68, 0.46, 0.72))
		draw_rect(shelf, Color(0.42, 0.26, 0.14), false, 2.5)
		draw_circle(Vector2(142, 574), 4.0, Color(0.90, 0.74, 0.42))
		draw_circle(Vector2(578, 574), 4.0, Color(0.90, 0.74, 0.42))

		# Cute eye-tracking blooming seedling on right side of shelf
		var bob := sin(_time * 3.4) * 14.0
		var dp := Vector2(252, 466 + bob)
		var sp := Vector2(468, 518)
		var pot := PackedVector2Array([
			sp + Vector2(-36, 4), sp + Vector2(36, 4),
			sp + Vector2(28, 44), sp + Vector2(-28, 44),
		])
		draw_colored_polygon(pot, Color(0.82, 0.44, 0.27))
		draw_colored_polygon(PackedVector2Array([
			sp + Vector2(-28, 6), sp + Vector2(-12, 6),
			sp + Vector2(-15, 42), sp + Vector2(-24, 42),
		]), Color(0.94, 0.64, 0.46, 0.40))
		draw_rect(Rect2(sp + Vector2(-41, -3), Vector2(82, 13)), Color(0.89, 0.52, 0.34))
		draw_rect(Rect2(sp + Vector2(-41, -3), Vector2(82, 13)), Color(0.52, 0.24, 0.14), false, 2.2)

		var sway := sin(_time * 2.8) * 5.0
		var head := sp + Vector2(sway, -48)
		draw_polyline(PackedVector2Array([sp + Vector2(0, 2), sp + Vector2(sway * 0.5, -22), head]), Color(0.28, 0.66, 0.30), 7.0, true)
		draw_circle(head, 48.0, Color(1.0, 0.90, 0.40, 0.18))
		for i in range(7):
			var a := TAU * float(i) / 7.0 + _time * 0.45
			var ppos := head + Vector2.from_angle(a) * 18.0
			draw_circle(ppos, 11.5, Color(1.0, 0.80, 0.24))
			draw_circle(ppos, 7.0, Color(1.0, 0.94, 0.66))
		draw_circle(head, 17.5, Color(0.42, 0.84, 0.38))
		draw_arc(head, 17.5, 0.0, TAU, 24, Color(0.20, 0.50, 0.22), 2.0, true)
		var look := (dp - head).normalized() * 2.2
		draw_circle(head + Vector2(-5.5, -1.5) + look, 2.8, Color(0.11, 0.26, 0.13))
		draw_circle(head + Vector2(5.5, -1.5) + look, 2.8, Color(0.11, 0.26, 0.13))
		draw_circle(head + Vector2(-6.3, -2.3) + look, 1.0, Color.WHITE)
		draw_circle(head + Vector2(4.7, -2.3) + look, 1.0, Color.WHITE)
		draw_arc(head + Vector2(0, 2.5), 4.8, 0.2, PI - 0.2, 8, Color(0.11, 0.26, 0.13), 2.1, true)
		draw_circle(head + Vector2(-9.5, 3.0), 3.0, Color(1.0, 0.56, 0.60, 0.6))
		draw_circle(head + Vector2(9.5, 3.0), 3.0, Color(1.0, 0.56, 0.60, 0.6))

		# Animated morphing hero droplet on left side
		draw_circle(Vector2(252, 554), 30.0 - bob * 0.3, Color(0.10, 0.20, 0.14, 0.16))
		var sc := _morph_pop
		match _demo_state:
			0:
				draw_circle(dp, 46.0 * sc, Color(0.32, 0.84, 1.0, 0.16))
				var r := 36.0 * sc
				var pts := PackedVector2Array()
				for i in range(30):
					var a := TAU * float(i) / 30.0
					var ca := cos(a)
					var sa := sin(a)
					var taper := 1.0 - maxf(0.0, -sa) * 0.19
					var lift := maxf(0.0, -sa) * 10.5 * sc
					pts.append(dp + Vector2(ca * r * taper, sa * r - lift))
				draw_colored_polygon(pts, Color(0.14, 0.64, 0.92))
				draw_circle(dp + Vector2(0, 14) * sc, 14.0 * sc, Color(0.76, 0.96, 1.0, 0.42))
				draw_circle(dp + Vector2(-12, -14) * sc, 8.0 * sc, Color(1, 1, 1, 0.72))
				draw_circle(dp + Vector2(-10, 2), 4.2, Color(0.08, 0.22, 0.34))
				draw_circle(dp + Vector2(10, 2), 4.2, Color(0.08, 0.22, 0.34))
				draw_circle(dp + Vector2(-11.3, 0.6), 1.5, Color.WHITE)
				draw_circle(dp + Vector2(8.7, 0.6), 1.5, Color.WHITE)
				draw_arc(dp + Vector2(0, 8), 6.2, 0.2, PI - 0.2, 10, Color(0.08, 0.22, 0.34), 2.5, true)
			1:
				var s := 35.0 * sc
				var c := 9.5 * sc
				var cube := PackedVector2Array([
					dp + Vector2(-s + c, -s), dp + Vector2(s - c, -s),
					dp + Vector2(s, -s + c), dp + Vector2(s, s - c),
					dp + Vector2(s - c, s), dp + Vector2(-s + c, s),
					dp + Vector2(-s, s - c), dp + Vector2(-s, -s + c),
				])
				draw_colored_polygon(cube, Color(0.70, 0.94, 1.0))
				draw_colored_polygon(PackedVector2Array([
					dp + Vector2(-s + c, -s), dp + Vector2(s * 0.4, -s),
					dp + Vector2(-s, s * 0.4), dp + Vector2(-s, -s + c),
				]), Color(1, 1, 1, 0.45))
				var border := cube.duplicate()
				border.append(cube[0])
				draw_polyline(border, Color(0.30, 0.66, 0.88), 3.4, true)
				draw_circle(dp + Vector2(-10, 0), 4.2, Color(0.08, 0.26, 0.40))
				draw_circle(dp + Vector2(10, 0), 4.2, Color(0.08, 0.26, 0.40))
				draw_line(dp + Vector2(-5, 9), dp + Vector2(5, 9), Color(0.08, 0.26, 0.40), 2.6, true)
			2:
				var puffs := [
					[Vector2(-23, 5), 23.0], [Vector2(23, 5), 23.0],
					[Vector2(-13, -15), 25.0], [Vector2(14, -13), 23.0],
					[Vector2(0, 8), 26.0],
				]
				for pf in puffs:
					draw_circle(dp + (pf[0] as Vector2) * sc, float(pf[1]) * sc, Color(0.97, 0.99, 1.0, 0.94))
				draw_arc(dp + Vector2(-10, 2), 5.6, PI + 0.3, TAU - 0.3, 8, Color(0.26, 0.40, 0.48), 2.6, true)
				draw_arc(dp + Vector2(10, 2), 5.6, PI + 0.3, TAU - 0.3, 8, Color(0.26, 0.40, 0.48), 2.6, true)
				draw_arc(dp + Vector2(0, 8), 5.2, 0.2, PI - 0.2, 8, Color(0.26, 0.40, 0.48), 2.3, true)


func _ready() -> void:
	add_child(GreenhouseBackground.new())
	_hero = MenuHero.new()
	add_child(_hero)
	_build_ui()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var title_box := VBoxContainer.new()
	title_box.position = Vector2(60, 130)
	title_box.size = Vector2(600, 195)
	title_box.add_theme_constant_override("separation", 4)
	ui.add_child(title_box)

	var title := Label.new()
	title.text = "DRIP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(title, 118, Color(0.13, 0.54, 0.78))
	title.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.92))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_shadow_color", Color(0.10, 0.24, 0.18, 0.26))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title_box.add_child(title)

	var tagline := Label.new()
	tagline.text = "Water  •  Ice  •  Steam"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(tagline, 28, Color(0.24, 0.44, 0.32))
	title_box.add_child(tagline)

	var btn_box := VBoxContainer.new()
	btn_box.position = Vector2(142, 668)
	btn_box.size = Vector2(436, 360)
	btn_box.add_theme_constant_override("separation", 20)
	ui.add_child(btn_box)

	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(0, 86)
	UIThemeHelper.style_button(play_btn, Color(0.26, 0.72, 0.44), Color(0.33, 0.78, 0.50), Color(0.20, 0.60, 0.36), Color.WHITE, 38, 26)
	play_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		play_pressed.emit()
	)
	btn_box.add_child(play_btn)

	var levels_btn := Button.new()
	levels_btn.text = "SELECT WORLD & LEVEL"
	levels_btn.custom_minimum_size = Vector2(0, 70)
	UIThemeHelper.style_button(levels_btn, Color(0.18, 0.64, 0.86), Color(0.24, 0.70, 0.92), Color(0.14, 0.54, 0.74), Color.WHITE, 25, 22)
	levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		levels_pressed.emit()
	)
	btn_box.add_child(levels_btn)

	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 16)
	btn_box.add_child(audio_row)

	_music_btn = Button.new()
	_music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_btn.custom_minimum_size = Vector2(0, 58)
	_music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	audio_row.add_child(_music_btn)

	_sfx_btn = Button.new()
	_sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_btn.custom_minimum_size = Vector2(0, 58)
	_sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	audio_row.add_child(_sfx_btn)

	var stars_info := SaveManager.get_total_stars()
	var pill := PanelContainer.new()
	pill.position = Vector2(150, 1134)
	pill.size = Vector2(420, 58)
	pill.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.99, 0.98, 0.94, 0.92),
		Color(0.56, 0.74, 0.58),
		22,
		2,
		4
	))
	ui.add_child(pill)

	var footer := Label.new()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.text = "2 Worlds • 20 Levels   ★ %d / %d" % [stars_info.x, stars_info.y]
	UIThemeHelper.apply_display_font(footer, 22, Color(0.22, 0.40, 0.28))
	pill.add_child(footer)

	_refresh_audio_buttons()


func _refresh_audio_buttons() -> void:
	var m_on := SaveManager.is_music_enabled()
	_music_btn.text = "MUSIC: ON" if m_on else "MUSIC: OFF"
	UIThemeHelper.style_button(
		_music_btn,
		Color(0.42, 0.66, 0.52) if m_on else Color(0.64, 0.70, 0.66),
		Color(0.48, 0.72, 0.58) if m_on else Color(0.70, 0.76, 0.72),
		Color(0.34, 0.56, 0.44),
		Color.WHITE,
		21,
		18
	)
	var s_on := SaveManager.is_sfx_enabled()
	_sfx_btn.text = "SFX: ON" if s_on else "SFX: OFF"
	UIThemeHelper.style_button(
		_sfx_btn,
		Color(0.42, 0.66, 0.52) if s_on else Color(0.64, 0.70, 0.66),
		Color(0.48, 0.72, 0.58) if s_on else Color(0.70, 0.76, 0.72),
		Color(0.34, 0.56, 0.44),
		Color.WHITE,
		21,
		18
	)
