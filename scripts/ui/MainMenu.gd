class_name MainMenu
extends Node2D
## Title screen: animated logo, living character showcase, play/continue.

signal play_pressed(from_pos: Vector2)
signal levels_pressed

var first_boot: bool = false

var _music_btn: Button
var _sfx_btn: Button
var _play_btn: Button
var _hero: MenuHero
var _logo: Logo


class Logo extends Control:
	var t: float = 0.0
	var drop_in: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var f := UIThemeHelper.get_display_font()
		if f == null:
			return
		var letters := ["D", "R", "I", "P"]
		var cols := [Color(0.16, 0.62, 0.92), Color(0.36, 0.78, 0.98), Color(0.64, 0.86, 0.98), Color(0.16, 0.62, 0.92)]
		var fs := 150
		var widths: Array[float] = []
		var total := 0.0
		for l in letters:
			var w := f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			widths.append(w)
			total += w + 6.0
		var x := size.x * 0.5 - total * 0.5
		var base_y := size.y * 0.5 + fs * 0.36
		for i in range(letters.size()):
			var delay := float(i) * 0.09
			var e := clampf((drop_in - delay) / 0.5, 0.0, 1.0)
			var fall := (1.0 - Seedling._elastic(e)) * -220.0
			var bob := sin(t * 2.2 + float(i) * 0.9) * 6.0
			var p := Vector2(x, base_y + bob + fall)
			var a := clampf(e * 3.0, 0.0, 1.0)
			draw_string_outline(f, p + Vector2(0, 10), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 26, Color(0.10, 0.28, 0.20, 0.22 * a))
			draw_string_outline(f, p, letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 26, Color(1, 1, 1, a))
			draw_string_outline(f, p, letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 9, Color(0.06, 0.34, 0.58, a))
			draw_string(f, p, letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(cols[i], a))
			# glossy highlight dot on each letter
			draw_circle(p + Vector2(widths[i] * 0.3, -fs * 0.56), 6.0, Color(1, 1, 1, 0.7 * a))
			x += widths[i] + 6.0
		# droplet dripping off the P
		var drip_cycle := fmod(t, 3.2)
		if drop_in > 0.8 and drip_cycle < 1.2:
			var px := x - widths[3] * 0.55
			var py := base_y + 10.0
			var grow := clampf(drip_cycle / 0.7, 0.0, 1.0)
			var fall_t := clampf((drip_cycle - 0.7) / 0.5, 0.0, 1.0)
			var dp := Vector2(px, py + fall_t * fall_t * 120.0)
			Art.draw_ellipse(self, dp, 6.0 * grow, 8.0 * grow, Color(0.30, 0.74, 0.98, 1.0 - fall_t))


class MenuHero extends Node2D:
	var art := DropletArt.new()
	var seedling: Seedling
	var t: float = 0.0
	var phase_t: float = 0.0
	var step: int = 0
	var hop: float = 0.0
	var drop_pos := Vector2(250, 668)

	func _ready() -> void:
		art.size = 1.9
		seedling = load("res://scenes/entities/Seedling.tscn").instantiate()
		seedling.position = Vector2(470, 700)
		seedling.scale = Vector2(1.45, 1.45)
		add_child(seedling)

	func _process(delta: float) -> void:
		t += delta
		phase_t += delta
		art.advance(delta)
		art.squish = lerpf(art.squish, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		art.pop = lerpf(art.pop, 1.0, clampf(delta * 8.0, 0.0, 1.0))
		# Little hop every beat
		hop = absf(sin(t * 2.6)) * 22.0 if art.state != 2 else 30.0 + sin(t * 2.0) * 8.0
		if art.state == 1:
			hop *= 0.4
		if phase_t > 2.1:
			phase_t = 0.0
			step += 1
			var nxt := (art.state + 1) % 3
			art.start_morph(art.state, nxt)
			art.pop = 1.25
			art.squish = 0.25
			if nxt == 0 and step % 3 == 0:
				seedling.play_bloom()
			elif nxt == 1 and seedling.is_bloomed:
				seedling.reset_bloom()
		var dp := drop_pos + Vector2(0, -hop)
		seedling.look_target = to_global(dp)
		seedling.excite_override = 0.8 if art.state == 0 else 0.0
		queue_redraw()

	func _draw() -> void:
		# Cedar shelf with brackets and little decor
		var shelf := Rect2(110, 744, 500, 26)
		Art.draw_rrect(self, Rect2(shelf.position + Vector2(4, 10), shelf.size), 8.0, Color(0.10, 0.18, 0.10, 0.18))
		Art.draw_rrect_grad(self, shelf, 8.0, Color(0.86, 0.66, 0.44), Color(0.64, 0.44, 0.26))
		Art.draw_rrect(self, Rect2(shelf.position + Vector2(4, 3), Vector2(shelf.size.x - 8, 7)), 4.0, Color(1, 0.92, 0.74, 0.5))
		Art.draw_rrect_outline(self, shelf, 8.0, Color(0.42, 0.26, 0.13), 2.6)
		for bx in [150.0, 570.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, 770), Vector2(bx + 8, 770), Vector2(bx + 8, 820), Vector2(bx - 8, 790)]), Color(0.52, 0.36, 0.22))
		# droplet shadow + droplet
		var dp := drop_pos + Vector2(0, -hop)
		var sh := clampf(1.0 - hop / 60.0, 0.4, 1.0)
		Art.draw_ellipse(self, Vector2(drop_pos.x, 744), 34.0 * sh, 7.0 * sh, Color(0.10, 0.18, 0.10, 0.20))
		art.velocity = Vector2(0, cos(t * 2.6) * 120.0) if art.state == 0 else Vector2.ZERO
		art.draw(self, dp)


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(360, 640)
	add_child(cam)
	cam.make_current()
	var bg := WorldBackground.new()
	add_child(bg)
	_hero = MenuHero.new()
	add_child(_hero)
	_build_ui()
	AudioManager.play_music("menu")


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# 720x1280 design frame centered in the viewport (matches the camera).
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -360
	frame.offset_right = 360
	frame.offset_top = -640
	frame.offset_bottom = 640
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	_logo = Logo.new()
	_logo.position = Vector2(0, 150)
	_logo.size = Vector2(720, 200)
	frame.add_child(_logo)
	var tw := _logo.create_tween()
	tw.tween_interval(0.15 if first_boot else 0.05)
	tw.tween_property(_logo, "drop_in", 1.5, 1.4)

	var tagline := HBoxContainer.new()
	tagline.alignment = BoxContainer.ALIGNMENT_CENTER
	tagline.position = Vector2(0, 360)
	tagline.size = Vector2(720, 50)
	tagline.add_theme_constant_override("separation", 10)
	frame.add_child(tagline)
	var names := ["Water", "Ice", "Steam"]
	for i in range(3):
		var l := UIThemeHelper.make_label(names[i], 30, Art.state_color(i).darkened(0.35))
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		l.add_theme_constant_override("outline_size", 8)
		tagline.add_child(l)
		if i < 2:
			var dot := UIThemeHelper.make_label("·", 30, Color(0.40, 0.54, 0.46))
			tagline.add_child(dot)
	UIThemeHelper.pop_in(tagline, 0.9 if first_boot else 0.4)

	var col := VBoxContainer.new()
	col.position = Vector2(130, 870)
	col.size = Vector2(460, 300)
	col.add_theme_constant_override("separation", 18)
	frame.add_child(col)

	var nxt := SaveManager.get_next_unfinished()
	var started := SaveManager.get_total_stars().x > 0 or not nxt.is_empty() and (String(nxt["world"]) != String(LevelRegistry.get_worlds()[0].get("id", "")) or int(nxt["index"]) > 0)
	_play_btn = Button.new()
	_play_btn.text = "CONTINUE" if started and not nxt.is_empty() else "PLAY"
	_play_btn.custom_minimum_size = Vector2(0, 104)
	UIThemeHelper.style_primary(_play_btn, UIThemeHelper.C_GREEN, 44, 34)
	_play_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		play_pressed.emit(_play_btn.get_global_rect().get_center())
	)
	col.add_child(_play_btn)
	if not nxt.is_empty() and started:
		var sub := UIThemeHelper.make_label("Level %d · %s" % [
			LevelRegistry.get_display_number(String(nxt["world"]), int(nxt["index"])),
			String(LevelRegistry.get_level_meta(String(nxt["world"]), int(nxt["index"])).get("title", ""))], 19, Color(1, 1, 1, 0.9))
		sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		sub.offset_top = -34
		sub.offset_bottom = -10
		_play_btn.add_child(sub)
		_play_btn.add_theme_constant_override("h_separation", 0)
		var ps := _play_btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		ps.content_margin_bottom = 40
		_play_btn.add_theme_stylebox_override("normal", ps)
		var ph := _play_btn.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
		ph.content_margin_bottom = 40
		_play_btn.add_theme_stylebox_override("hover", ph)

	var levels_btn := Button.new()
	levels_btn.text = "LEVELS"
	levels_btn.custom_minimum_size = Vector2(0, 78)
	UIThemeHelper.style_primary(levels_btn, UIThemeHelper.C_BLUE, 30, 28)
	levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		levels_pressed.emit()
	)
	col.add_child(levels_btn)

	var stars := SaveManager.get_total_stars()
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(1.0, 0.985, 0.95, 0.92), Color(0.84, 0.88, 0.80), 22, 0, 4))
	col.add_child(pill)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	pill.add_child(prow)
	var sun := UIIcon.new()
	sun.kind = "star"
	sun.shadow = false
	sun.custom_minimum_size = Vector2(36, 36)
	prow.add_child(sun)
	prow.add_child(UIThemeHelper.make_label("%d / %d" % [stars.x, stars.y], 24))
	prow.add_child(UIThemeHelper.make_label("  ·  %d levels" % LevelRegistry.get_total_level_count(), 20, Color(0.44, 0.56, 0.48), false))

	var d := 1.0 if first_boot else 0.3
	UIThemeHelper.pop_in(_play_btn, d)
	UIThemeHelper.pop_in(levels_btn, d + 0.1)
	UIThemeHelper.pop_in(pill, d + 0.2)

	# Top-right audio toggles hug the real top edge.
	var toggles := HBoxContainer.new()
	toggles.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggles.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toggles.offset_left = -170
	toggles.offset_right = -20
	toggles.offset_top = UIThemeHelper.safe_top(get_viewport()) + 20
	toggles.add_theme_constant_override("separation", 12)
	root.add_child(toggles)
	_music_btn = UIThemeHelper.make_icon_button("music", UIThemeHelper.C_SAGE, 64)
	_music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	toggles.add_child(_music_btn)
	_sfx_btn = UIThemeHelper.make_icon_button("sfx", UIThemeHelper.C_SAGE, 64)
	_sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	toggles.add_child(_sfx_btn)
	_refresh_audio_buttons()


func _refresh_audio_buttons() -> void:
	PauseModal._set_toggle(_music_btn, "music", SaveManager.is_music_enabled())
	PauseModal._set_toggle(_sfx_btn, "sfx", SaveManager.is_sfx_enabled())
