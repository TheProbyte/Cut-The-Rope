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

	func _process(delta: float) -> void:
		_time += delta
		_state_timer += delta
		if _state_timer > 2.4:
			_state_timer = 0.0
			_demo_state = (_demo_state + 1) % 3
		queue_redraw()

	func _draw() -> void:
		# Cozy greenhouse shelf
		var shelf := Rect2(140, 560, 440, 26)
		draw_rect(Rect2(144, 566, 440, 26), Color(0.10, 0.20, 0.12, 0.18))
		draw_rect(shelf, Color(0.68, 0.48, 0.30))
		draw_rect(Rect2(140, 560, 440, 9), Color(0.82, 0.64, 0.44, 0.7))
		draw_rect(shelf, Color(0.42, 0.26, 0.14), false, 2.5)

		# Cute smiling seedling on right side of shelf
		var sp := Vector2(465, 520)
		var pot := PackedVector2Array([
			sp + Vector2(-34, 4), sp + Vector2(34, 4),
			sp + Vector2(26, 42), sp + Vector2(-26, 42),
		])
		draw_colored_polygon(pot, Color(0.82, 0.44, 0.27))
		draw_rect(Rect2(sp + Vector2(-39, -2), Vector2(78, 12)), Color(0.89, 0.52, 0.34))
		var sway := sin(_time * 2.8) * 5.0
		var head := sp + Vector2(sway, -44)
		draw_polyline(PackedVector2Array([sp + Vector2(0, 2), sp + Vector2(sway * 0.5, -20), head]), Color(0.32, 0.72, 0.34), 6.5, true)
		for i in range(6):
			var a := TAU * float(i) / 6.0 + _time * 0.45
			draw_circle(head + Vector2.from_angle(a) * 16.0, 10.5, Color(1.0, 0.84, 0.28))
		draw_circle(head, 16.5, Color(0.44, 0.84, 0.40))
		draw_circle(head + Vector2(-5.5, -1.5), 2.5, Color(0.12, 0.28, 0.14))
		draw_circle(head + Vector2(5.5, -1.5), 2.5, Color(0.12, 0.28, 0.14))
		draw_arc(head + Vector2(0, 2.5), 4.5, 0.2, PI - 0.2, 8, Color(0.12, 0.28, 0.14), 2.0, true)

		# Animated state-cycling hero droplet on left side
		var bob := sin(_time * 3.4) * 12.0
		var dp := Vector2(260, 470 + bob)
		draw_circle(Vector2(260, 554), 28.0 - bob * 0.3, Color(0.10, 0.20, 0.14, 0.16))

		match _demo_state:
			0:
				# Water
				var r := 36.0
				var pts := PackedVector2Array()
				for i in range(28):
					var a := TAU * float(i) / 28.0
					var ca := cos(a)
					var sa := sin(a)
					var taper := 1.0 - maxf(0.0, -sa) * 0.18
					var lift := maxf(0.0, -sa) * 10.0
					pts.append(dp + Vector2(ca * r * taper, sa * r - lift))
				draw_colored_polygon(pts, Color(0.18, 0.70, 0.94))
				draw_circle(dp + Vector2(-12, -14), 7.5, Color(1, 1, 1, 0.65))
				draw_circle(dp + Vector2(-10, 2), 4.0, Color(0.08, 0.22, 0.34))
				draw_circle(dp + Vector2(10, 2), 4.0, Color(0.08, 0.22, 0.34))
				draw_arc(dp + Vector2(0, 8), 6.0, 0.2, PI - 0.2, 10, Color(0.08, 0.22, 0.34), 2.5, true)
			1:
				# Ice
				var s := 34.0
				var c := 9.0
				var cube := PackedVector2Array([
					dp + Vector2(-s + c, -s), dp + Vector2(s - c, -s),
					dp + Vector2(s, -s + c), dp + Vector2(s, s - c),
					dp + Vector2(s - c, s), dp + Vector2(-s + c, s),
					dp + Vector2(-s, s - c), dp + Vector2(-s, -s + c),
				])
				draw_colored_polygon(cube, Color(0.72, 0.94, 1.0))
				var border := cube.duplicate()
				border.append(cube[0])
				draw_polyline(border, Color(0.32, 0.68, 0.88), 3.2, true)
				draw_circle(dp + Vector2(-10, 0), 4.0, Color(0.08, 0.26, 0.40))
				draw_circle(dp + Vector2(10, 0), 4.0, Color(0.08, 0.26, 0.40))
				draw_line(dp + Vector2(-5, 9), dp + Vector2(5, 9), Color(0.08, 0.26, 0.40), 2.6, true)
			2:
				# Steam
				var puffs := [
					[Vector2(-22, 5), 22.0], [Vector2(22, 5), 22.0],
					[Vector2(-12, -14), 24.0], [Vector2(14, -12), 22.0],
					[Vector2(0, 8), 25.0],
				]
				for pf in puffs:
					draw_circle(dp + (pf[0] as Vector2), float(pf[1]), Color(0.97, 0.99, 1.0, 0.94))
				draw_arc(dp + Vector2(-10, 2), 5.5, PI + 0.3, TAU - 0.3, 8, Color(0.26, 0.40, 0.48), 2.5, true)
				draw_arc(dp + Vector2(10, 2), 5.5, PI + 0.3, TAU - 0.3, 8, Color(0.26, 0.40, 0.48), 2.5, true)
				draw_arc(dp + Vector2(0, 8), 5.0, 0.2, PI - 0.2, 8, Color(0.26, 0.40, 0.48), 2.2, true)


func _ready() -> void:
	add_child(GreenhouseBackground.new())
	_hero = MenuHero.new()
	add_child(_hero)
	_build_ui()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var title_box := VBoxContainer.new()
	title_box.position = Vector2(60, 145)
	title_box.size = Vector2(600, 180)
	title_box.add_theme_constant_override("separation", 6)
	ui.add_child(title_box)

	var title := Label.new()
	title.text = "DRIP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(0.14, 0.48, 0.68))
	title.add_theme_color_override("font_shadow_color", Color(0.10, 0.22, 0.16, 0.22))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title_box.add_child(title)

	var tagline := Label.new()
	tagline.text = "Water  •  Ice  •  Steam"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 26)
	tagline.add_theme_color_override("font_color", Color(0.28, 0.46, 0.34))
	title_box.add_child(tagline)

	var btn_box := VBoxContainer.new()
	btn_box.position = Vector2(150, 680)
	btn_box.size = Vector2(420, 340)
	btn_box.add_theme_constant_override("separation", 20)
	ui.add_child(btn_box)

	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(0, 82)
	UIThemeHelper.style_button(play_btn, Color(0.28, 0.72, 0.44), Color(0.35, 0.78, 0.50), Color(0.22, 0.60, 0.36), Color.WHITE, 36, 24)
	play_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		play_pressed.emit()
	)
	btn_box.add_child(play_btn)

	var levels_btn := Button.new()
	levels_btn.text = "GREENHOUSE LEVELS"
	levels_btn.custom_minimum_size = Vector2(0, 68)
	UIThemeHelper.style_button(levels_btn, Color(0.20, 0.64, 0.84), Color(0.26, 0.70, 0.90), Color(0.16, 0.54, 0.72), Color.WHITE, 26, 20)
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
	_music_btn.custom_minimum_size = Vector2(0, 56)
	_music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	audio_row.add_child(_music_btn)

	_sfx_btn = Button.new()
	_sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_btn.custom_minimum_size = Vector2(0, 56)
	_sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	audio_row.add_child(_sfx_btn)

	var stars_info := SaveManager.get_world_stars("greenhouse")
	var footer := Label.new()
	footer.position = Vector2(60, 1140)
	footer.size = Vector2(600, 44)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.text = "World 1: Greenhouse   ★ %d / %d" % [stars_info.x, stars_info.y]
	footer.add_theme_font_size_override("font_size", 22)
	footer.add_theme_color_override("font_color", Color(0.24, 0.42, 0.28))
	ui.add_child(footer)

	_refresh_audio_buttons()


func _refresh_audio_buttons() -> void:
	var m_on := SaveManager.is_music_enabled()
	_music_btn.text = "MUSIC: ON" if m_on else "MUSIC: OFF"
	UIThemeHelper.style_button(
		_music_btn,
		Color(0.46, 0.66, 0.54) if m_on else Color(0.64, 0.70, 0.66),
		Color(0.52, 0.72, 0.60) if m_on else Color(0.70, 0.76, 0.72),
		Color(0.38, 0.56, 0.46),
		Color.WHITE,
		20,
		16
	)
	var s_on := SaveManager.is_sfx_enabled()
	_sfx_btn.text = "SFX: ON" if s_on else "SFX: OFF"
	UIThemeHelper.style_button(
		_sfx_btn,
		Color(0.46, 0.66, 0.54) if s_on else Color(0.64, 0.70, 0.66),
		Color(0.52, 0.72, 0.60) if s_on else Color(0.70, 0.76, 0.72),
		Color(0.38, 0.56, 0.46),
		Color.WHITE,
		20,
		16
	)
