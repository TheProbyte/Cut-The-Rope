class_name ResultModal
extends ModalBase

signal next_requested
signal replay_requested
signal level_select_requested

var _subtitle: Label
var _message: Label
var _stars_row: HBoxContainer
var _big_stars: Array[BigStar] = []
var _tag: Label
var _fail_art: FailArt
var _next_btn: Button
var _replay_btn: Button
var _retry_btn: Button
var _levels_btn: Button
var _celebration: Celebration
var _serial: int = 0


class BigStar extends Control:
	var lit: bool = false
	var pop_scale: float = 1.0
	var t: float = 0.0
	var burst: float = 0.0

	func _init(big: bool) -> void:
		custom_minimum_size = Vector2(110, 120) if big else Vector2(92, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func slam_in() -> void:
		lit = true
		pop_scale = 0.01
		burst = 1.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(self, "pop_scale", 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "pop_scale", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	func _process(delta: float) -> void:
		t += delta
		burst = maxf(0.0, burst - delta * 1.8)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.40
		if lit:
			if burst > 0.0:
				var bt := 1.0 - burst
				draw_arc(c, r + bt * 50.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.36, burst), 5.0 * burst, true)
				for i in range(8):
					var a := TAU * float(i) / 8.0 + 0.2
					Art.draw_sparkle(self, c + Vector2.from_angle(a) * (r + bt * 60.0), 9.0 * burst, Color(1.0, 0.97, 0.7, burst))
			Art.draw_sun(self, c, r * pop_scale, t * 0.5, true)
		else:
			Art.draw_sun(self, c, r, 0.0, false)


class Celebration extends Control:
	var active: bool = false
	var t: float = 0.0
	var confetti: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func start() -> void:
		active = true
		t = 0.0
		confetti.clear()
		var cols := [Color(1.0, 0.80, 0.24), Color(1.0, 0.50, 0.60), Color(0.42, 0.84, 0.46), Color(0.40, 0.80, 1.0), Color(1.0, 0.66, 0.30)]
		for i in range(70):
			confetti.append({
				"pos": Vector2(randf_range(0, size.x), randf_range(-size.y * 0.6, -20.0)),
				"vel": Vector2(randf_range(-40, 40), randf_range(120, 260)),
				"rot": randf_range(0, TAU), "vrot": randf_range(-6, 6),
				"size": randf_range(6, 11), "col": cols[i % cols.size()],
				"phase": randf_range(0, TAU),
			})

	func _process(delta: float) -> void:
		if not active:
			return
		t += delta
		for c in confetti:
			var p: Vector2 = c["pos"]
			p += (c["vel"] as Vector2) * delta + Vector2(sin(t * 3.0 + float(c["phase"])) * 40.0 * delta, 0)
			c["pos"] = p
			c["rot"] = float(c["rot"]) + float(c["vrot"]) * delta
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var c := size * 0.5 + Vector2(0, -120)
		var a := clampf(t * 2.0, 0.0, 1.0)
		for i in range(14):
			var ang := t * 0.25 + TAU * float(i) / 14.0
			var p1 := c + Vector2.from_angle(ang - 0.09) * 900.0
			var p2 := c + Vector2.from_angle(ang + 0.09) * 900.0
			draw_polygon(PackedVector2Array([c, p1, p2]), PackedColorArray([Color(1, 0.95, 0.7, 0.22 * a), Color(1, 0.95, 0.7, 0.0), Color(1, 0.95, 0.7, 0.0)]))
		Art.draw_glow(self, c, 300.0, Color(1.0, 0.9, 0.55, 0.35 * a))
		for cf in confetti:
			var sz: float = cf["size"]
			var r: float = cf["rot"]
			var p: Vector2 = cf["pos"]
			var squash := absf(cos(r * 1.7))
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-sz, -sz * 0.5 * squash).rotated(r), p + Vector2(sz, -sz * 0.5 * squash).rotated(r),
				p + Vector2(sz, sz * 0.5 * squash).rotated(r), p + Vector2(-sz, sz * 0.5 * squash).rotated(r),
			]), cf["col"])


class FailArt extends Control:
	var art := DropletArt.new()
	var reason: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(0, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.size = 2.0
		art.mood = "worried"

	func _process(delta: float) -> void:
		art.advance(delta)
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 62)
		var bob := sin(art.time * 2.4) * 4.0
		Art.draw_ellipse(self, c + Vector2(0, 52), 46.0, 9.0, Color(0, 0, 0, 0.10))
		match reason:
			"hotplate":
				Art.draw_glow(self, c + Vector2(0, 40), 70.0, Color(1.0, 0.45, 0.2, 0.35))
			"drain":
				for i in range(3):
					draw_arc(c + Vector2(0, 50), 20.0 + float(i) * 12.0, art.time * 3.0 + float(i), art.time * 3.0 + float(i) + 2.4, 16, Color(0.3, 0.45, 0.6, 0.5), 3.0, true)
			"evaporated":
				for i in range(3):
					var ph := fmod(art.time * 0.6 + float(i) * 0.33, 1.0)
					draw_circle(c + Vector2(-30 + float(i) * 30, -10 - ph * 50), 10.0 * (1.0 - ph), Color(1, 1, 1, 0.8 * (1.0 - ph)))
		art.draw(self, c + Vector2(0, bob))


func _build_backdrop() -> void:
	_celebration = Celebration.new()
	_celebration.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_celebration)


func _build_content() -> void:
	_subtitle = UIThemeHelper.make_label("", 24, Color(0.40, 0.54, 0.46))
	_content.add_child(_subtitle)

	_stars_row = _row(0)
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_stars_row)
	for i in range(3):
		var s := BigStar.new(i == 1)
		_stars_row.add_child(s)
		_big_stars.append(s)

	_fail_art = FailArt.new()
	_content.add_child(_fail_art)

	_message = UIThemeHelper.make_label("", 24, Color(0.30, 0.42, 0.34), false)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_message)

	_tag = UIThemeHelper.make_label("", 22, Color(0.92, 0.52, 0.10))
	_content.add_child(_tag)

	var row := _row()
	_content.add_child(row)
	_levels_btn = UIThemeHelper.make_icon_button("levels", UIThemeHelper.C_BLUE, 82)
	_levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_back")
		level_select_requested.emit()
	)
	row.add_child(_levels_btn)
	_replay_btn = UIThemeHelper.make_icon_button("restart", UIThemeHelper.C_ORANGE, 82)
	_replay_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		replay_requested.emit()
	)
	row.add_child(_replay_btn)
	_next_btn = _primary_button("NEXT", "next", UIThemeHelper.C_GREEN, 82)
	_next_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		next_requested.emit()
	)
	row.add_child(_next_btn)
	_retry_btn = _primary_button("RETRY", "restart", UIThemeHelper.C_ORANGE, 82)
	_retry_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		replay_requested.emit()
	)
	row.add_child(_retry_btn)


func get_next_center() -> Vector2:
	return _next_btn.get_global_rect().get_center() if _next_btn.visible else get_viewport().get_visible_rect().size * 0.5


func hide_now() -> void:
	super.hide_now()
	_serial += 1
	_celebration.active = false
	_celebration.queue_redraw()


func show_win(stars: int, has_next: bool, new_best: bool, display_number: int, title: String, new_world: String = "") -> void:
	_serial += 1
	var serial := _serial
	_subtitle.text = "Level %d  ·  %s" % [display_number, title]
	match stars:
		3:
			_message.text = "Radiant! Every sun collected."
		2:
			_message.text = "Lovely! One sun is still hiding."
		1:
			_message.text = "The seedling is happy! Can you find more suns?"
		_:
			_message.text = "Watered! Now try grabbing the suns on the way."
	_tag.visible = new_best or new_world != ""
	_tag.text = ("%s UNLOCKED!" % new_world.to_upper()) if new_world != "" else "NEW BEST!"
	_stars_row.visible = true
	_fail_art.visible = false
	for s in _big_stars:
		s.lit = false
		s.pop_scale = 1.0
	_next_btn.visible = has_next
	_replay_btn.visible = true
	_retry_btn.visible = false
	if not has_next:
		_replay_btn.visible = false
		_retry_btn.visible = true
		_retry_btn.text = "REPLAY"
	_celebration.visible = true
	_open("BLOOMED!", Color(0.30, 0.72, 0.44))
	_celebration.start()
	for i in range(stars):
		var idx := i
		get_tree().create_timer(0.35 + float(idx) * 0.28, true).timeout.connect(func():
			if serial == _serial and visible:
				_big_stars[idx].slam_in()
				AudioManager.play_sfx("star_fanfare", 1.0 + float(idx) * 0.14, -2.0)
				SaveManager.haptic(20 + idx * 10)
		)
	if _tag.visible:
		_tag.modulate.a = 0.0
		var tw := _tag.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.4 + float(stars) * 0.28)
		tw.tween_property(_tag, "modulate:a", 1.0, 0.25)
		if new_world != "":
			tw.tween_callback(func(): AudioManager.play_sfx("unlock"))


func show_fail(reason: String, display_number: int, title: String) -> void:
	_serial += 1
	_subtitle.text = "Level %d  ·  %s" % [display_number, title]
	match reason:
		"drain":
			_message.text = "Whoops, slipped down the drain!"
		"hotplate":
			_message.text = "Sizzled on the hot plate!"
		"evaporated":
			_message.text = "Floated away into the sky!"
		_:
			_message.text = "Tumbled right off the bench!"
	_tag.visible = false
	_stars_row.visible = false
	_fail_art.visible = true
	_fail_art.reason = reason
	_next_btn.visible = false
	_replay_btn.visible = false
	_retry_btn.visible = true
	_retry_btn.text = "RETRY"
	_celebration.active = false
	_celebration.visible = false
	_open("OOPS!", Color(0.90, 0.46, 0.36))
