class_name Seedling
extends Node2D

signal watered

var is_bloomed: bool = false

var _time: float = 0.0
var _bloom_t: float = 0.0
var _excite_t: float = 0.0
var _shiver_timer: float = 0.0
var _confetti: Array[Dictionary] = []
var _frost_puffs: Array[Dictionary] = []
var _sensor: Area2D
var _overlapping_droplet: Droplet = null
var _tracked_droplet: Droplet = null
var _look_dir: Vector2 = Vector2.ZERO


func track_droplet(droplet: Droplet) -> void:
	_tracked_droplet = droplet


func _ready() -> void:
	_build_pot_collider()
	_build_sensor()


func _build_pot_collider() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.65
	mat.bounce = 0.05
	body.physics_material_override = mat
	add_child(body)

	var base := CollisionShape2D.new()
	var base_rect := RectangleShape2D.new()
	base_rect.size = Vector2(92.0, 20.0)
	base.shape = base_rect
	base.position = Vector2(0.0, 34.0)
	body.add_child(base)

	for side: float in [-1.0, 1.0]:
		var rim := CollisionShape2D.new()
		var rim_rect := RectangleShape2D.new()
		rim_rect.size = Vector2(12.0, 34.0)
		rim.shape = rim_rect
		rim.position = Vector2(side * 44.0, 18.0)
		body.add_child(rim)


func _build_sensor() -> void:
	_sensor = Area2D.new()
	_sensor.collision_layer = 16
	_sensor.collision_mask = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	shape.shape = circle
	shape.position = Vector2(0.0, -8.0)
	_sensor.add_child(shape)
	add_child(_sensor)

	_sensor.body_entered.connect(_on_body_entered)
	_sensor.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if is_bloomed:
		return
	if body is Droplet:
		_overlapping_droplet = body as Droplet
		_evaluate_droplet(_overlapping_droplet, true)


func _on_body_exited(body: Node) -> void:
	if body == _overlapping_droplet:
		_overlapping_droplet = null


func _physics_process(_delta: float) -> void:
	if is_bloomed or _overlapping_droplet == null:
		return
	if not is_instance_valid(_overlapping_droplet):
		_overlapping_droplet = null
		return
	_evaluate_droplet(_overlapping_droplet, false)


func _evaluate_droplet(droplet: Droplet, just_entered: bool) -> void:
	if not droplet.active or droplet.soaked or is_bloomed:
		return
	if droplet.is_water():
		_bloom(droplet)
	elif droplet.is_ice() and just_entered:
		_shiver_timer = 0.65
		AudioManager.play_sfx("seedling_shiver")
		for i in range(6):
			_frost_puffs.append({
				"pos": Vector2(randf_range(-12, 12), -26.0),
				"vel": Vector2(randf_range(-38, 38), randf_range(-55, -18)),
				"life": 0.55,
				"max_life": 0.55,
				"r": randf_range(3.5, 6.0),
			})


func _bloom(droplet: Droplet) -> void:
	is_bloomed = true
	droplet.freeze_for_end()
	droplet.visible = false
	AudioManager.play_sfx("seedling_bloom")

	var colors := [
		Color(1.0, 0.84, 0.24),
		Color(1.0, 0.48, 0.60),
		Color(0.42, 0.86, 0.44),
		Color(0.45, 0.86, 1.0),
		Color(1.0, 0.70, 0.34),
	]
	for i in range(26):
		var angle := randf_range(-PI * 0.94, -PI * 0.06)
		var speed := randf_range(110.0, 260.0)
		_confetti.append({
			"pos": Vector2(randf_range(-12, 12), -30.0),
			"vel": Vector2.from_angle(angle) * speed,
			"life": randf_range(0.9, 1.6),
			"max_life": 1.6,
			"size": randf_range(4.5, 8.2),
			"color": colors[i % colors.size()],
		})
	watered.emit()


func _process(delta: float) -> void:
	_time += delta
	if is_bloomed:
		_bloom_t = minf(1.0, _bloom_t + delta * 2.5)
	if _shiver_timer > 0.0:
		_shiver_timer = maxf(0.0, _shiver_timer - delta)

	# Eye tracking & anticipation excitement (Om Nom style!)
	var target_excite := 0.0
	if not is_bloomed and _tracked_droplet != null and is_instance_valid(_tracked_droplet) and _tracked_droplet.active:
		var delta_v := _tracked_droplet.global_position - (global_position + Vector2(0, -34))
		var dist := delta_v.length()
		if dist > 4.0:
			_look_dir = _look_dir.lerp(delta_v.normalized(), clampf(delta * 8.0, 0.0, 1.0))
		if dist < 210.0 and _tracked_droplet.is_water() and not _tracked_droplet.soaked:
			target_excite = clampf(1.0 - (dist / 210.0), 0.0, 1.0)
	_excite_t = lerpf(_excite_t, target_excite, clampf(delta * 7.0, 0.0, 1.0))

	for i in range(_confetti.size() - 1, -1, -1):
		var c: Dictionary = _confetti[i]
		c["life"] = float(c["life"]) - delta
		if float(c["life"]) <= 0.0:
			_confetti.remove_at(i)
		else:
			var vel: Vector2 = c["vel"]
			vel.y += 280.0 * delta
			c["vel"] = vel
			c["pos"] = (c["pos"] as Vector2) + vel * delta

	for i in range(_frost_puffs.size() - 1, -1, -1):
		var f: Dictionary = _frost_puffs[i]
		f["life"] = float(f["life"]) - delta
		if float(f["life"]) <= 0.0:
			_frost_puffs.remove_at(i)
		else:
			f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * delta

	queue_redraw()


func _draw() -> void:
	var shiver_x := sin(_time * 48.0) * 4.5 * (_shiver_timer / 0.65) if _shiver_timer > 0.0 else 0.0
	var bx := shiver_x

	# Soft warm ground shadow under pot
	draw_circle(Vector2(0, 45), 40.0, Color(0.14, 0.22, 0.14, 0.20))

	# Radiant sunlit halo behind bloomed seedling
	if _bloom_t > 0.05:
		var halo_center := Vector2(bx, -52.0)
		draw_circle(halo_center, 58.0 * _bloom_t, Color(1.0, 0.90, 0.38, 0.20 * _bloom_t))
		for i in range(10):
			var a := _time * 0.7 + TAU * float(i) / 10.0
			draw_line(
				halo_center + Vector2.from_angle(a) * (26.0 * _bloom_t),
				halo_center + Vector2.from_angle(a) * (54.0 * _bloom_t),
				Color(1.0, 0.92, 0.45, 0.42 * _bloom_t),
				3.2,
				true
			)

	# Terracotta pot with cozy curved highlight & shading
	var pot := PackedVector2Array([
		Vector2(-36 + bx, 4),
		Vector2(36 + bx, 4),
		Vector2(28 + bx, 44),
		Vector2(-28 + bx, 44),
	])
	draw_colored_polygon(pot, Color(0.82, 0.44, 0.27))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-28 + bx, 6), Vector2(-12 + bx, 6),
		Vector2(-15 + bx, 42), Vector2(-24 + bx, 42),
	]), Color(0.94, 0.62, 0.44, 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2(14 + bx, 4), Vector2(36 + bx, 4),
		Vector2(28 + bx, 44), Vector2(12 + bx, 44),
	]), Color(0.64, 0.30, 0.18, 0.50))
	var pot_outline := pot.duplicate()
	pot_outline.append(pot[0])
	draw_polyline(pot_outline, Color(0.50, 0.24, 0.14), 2.2, true)

	# Rich soil mound
	draw_rect(Rect2(-34 + bx, 0, 68, 10), Color(0.32, 0.21, 0.14))
	draw_circle(Vector2(-14 + bx, 2), 6.0, Color(0.38, 0.25, 0.16))
	draw_circle(Vector2(12 + bx, 2), 5.5, Color(0.38, 0.25, 0.16))

	# Pot rim with rounded lip highlight
	var rim := Rect2(-41 + bx, -3, 82, 13)
	draw_rect(rim, Color(0.88, 0.50, 0.32))
	draw_rect(Rect2(-39 + bx, -2, 78, 4), Color(0.98, 0.72, 0.54, 0.65))
	draw_rect(rim, Color(0.52, 0.24, 0.14), false, 2.2)

	# Stem & posture: droopy -> perks up with excitement -> tall bloom!
	var perk := maxf(_bloom_t, _excite_t * 0.65)
	var droop := 1.0 - perk
	var sway_spd := 4.4 if is_bloomed else (6.5 if _excite_t > 0.3 else 2.2)
	var sway := sin(_time * sway_spd) * (3.8 if is_bloomed else (3.5 if _excite_t > 0.3 else 2.6))
	var head_pos := Vector2(
		bx + droop * 10.0 + sway,
		lerpf(-28.0, -52.0, perk)
	)
	var stem_mid := Vector2(bx + droop * 12.0 + sway * 0.45, lerpf(-12.0, -26.0, perk))

	var stem_pts := PackedVector2Array([Vector2(bx, 2.0), stem_mid, head_pos])
	draw_polyline(stem_pts, Color(0.24, 0.60, 0.26), 7.2, true)
	draw_polyline(stem_pts, Color(0.44, 0.82, 0.40), 3.4, true)

	# Expressive leaves
	var leaf_l := lerpf(-2.15, -2.72, perk)
	var leaf_r := lerpf(-0.42, -0.45, perk)
	_draw_leaf(stem_mid + Vector2(-2, 2), leaf_l, 17.0 + perk * 6.0)
	_draw_leaf(stem_mid + Vector2(2, 2), leaf_r, 17.0 + perk * 6.0)

	# Multi-layered flower petals when bloomed
	if _bloom_t > 0.05:
		var petal_r := 12.5 * _bloom_t
		var petal_dist := 18.0 * _bloom_t
		for i in range(7):
			var a := TAU * float(i) / 7.0 + _time * 0.45
			var ppos := head_pos + Vector2.from_angle(a) * petal_dist
			draw_circle(ppos, petal_r, Color(1.0, 0.78, 0.22))
			draw_circle(ppos, petal_r * 0.62, Color(1.0, 0.94, 0.66))
			draw_arc(ppos, petal_r, 0.0, TAU, 16, Color(0.88, 0.56, 0.10, 0.6), 1.5, true)

	# Cute head bud
	var head_r := lerpf(15.5, 18.0, _bloom_t)
	var head_col := Color(0.56, 0.82, 0.42).lerp(Color(0.38, 0.84, 0.36), perk)
	draw_circle(head_pos, head_r, head_col)
	draw_circle(head_pos + Vector2(-4.5, -5.5), 5.0, Color(0.76, 0.96, 0.66, 0.55))
	draw_arc(head_pos, head_r, 0.0, TAU, 26, Color(0.20, 0.50, 0.22), 2.2, true)

	# Expressive Face
	var ink := Color(0.11, 0.26, 0.13)
	if is_bloomed:
		draw_arc(head_pos + Vector2(-5.8, -1.0), 3.4, PI + 0.28, TAU - 0.28, 8, ink, 2.2, true)
		draw_arc(head_pos + Vector2(5.8, -1.0), 3.4, PI + 0.28, TAU - 0.28, 8, ink, 2.2, true)
		draw_arc(head_pos + Vector2(0.0, 2.5), 5.2, 0.12, PI - 0.12, 10, ink, 2.2, true)
		draw_circle(head_pos + Vector2(-9.8, 3.2), 3.2, Color(1.0, 0.54, 0.60, 0.65))
		draw_circle(head_pos + Vector2(9.8, 3.2), 3.2, Color(1.0, 0.54, 0.60, 0.65))
	elif _shiver_timer > 0.0:
		draw_line(head_pos + Vector2(-7.5, -3), head_pos + Vector2(-3, 0), ink, 2.2)
		draw_line(head_pos + Vector2(-7.5, 2.5), head_pos + Vector2(-3, 0), ink, 2.2)
		draw_line(head_pos + Vector2(7.5, -3), head_pos + Vector2(3, 0), ink, 2.2)
		draw_line(head_pos + Vector2(7.5, 2.5), head_pos + Vector2(3, 0), ink, 2.2)
		draw_circle(head_pos + Vector2(0, 5.8), 3.0, ink)
	else:
		var eye_off := _look_dir * 2.3
		var eye_r := 3.1 if _excite_t > 0.25 else 2.6
		draw_circle(head_pos + Vector2(-5.2, -1.2) + eye_off, eye_r, ink)
		draw_circle(head_pos + Vector2(5.2, -1.2) + eye_off, eye_r, ink)
		draw_circle(head_pos + Vector2(-6.0, -2.0) + eye_off, 1.1, Color.WHITE)
		draw_circle(head_pos + Vector2(4.4, -2.0) + eye_off, 1.1, Color.WHITE)
		if _excite_t > 0.25:
			# Excited anticipation smile!
			draw_circle(head_pos + Vector2(-9.2, 3.0), 3.0, Color(1.0, 0.56, 0.60, 0.55))
			draw_circle(head_pos + Vector2(9.2, 3.0), 3.0, Color(1.0, 0.56, 0.60, 0.55))
			draw_arc(head_pos + Vector2(0.0, 2.5), 4.6, 0.15, PI - 0.15, 10, ink, 2.1, true)
		else:
			draw_arc(head_pos + Vector2(0.0, 7.6), 3.6, PI + 0.35, TAU - 0.35, 8, ink, 1.9, true)
			# Floating water-drop thought bubble
			var bob := sin(_time * 3.0) * 3.2
			var bpos := head_pos + Vector2(25.0, -25.0 + bob)
			draw_circle(bpos, 12.2, Color(1.0, 1.0, 1.0, 0.88))
			draw_arc(bpos, 12.2, 0.0, TAU, 20, Color(0.62, 0.80, 0.68, 0.5), 1.4, true)
			draw_circle(bpos + Vector2(-10.5, 11.5), 3.4, Color(1.0, 1.0, 1.0, 0.80))
			draw_circle(bpos + Vector2(0.0, 2.2), 4.8, Color(0.20, 0.72, 0.96))
			draw_colored_polygon(PackedVector2Array([
				bpos + Vector2(0.0, -6.2),
				bpos + Vector2(4.4, 1.2),
				bpos + Vector2(-4.4, 1.2),
			]), Color(0.20, 0.72, 0.96))

	# Frost puffs when shivering
	for f in _frost_puffs:
		var a: float = clampf(float(f["life"]) / float(f["max_life"]), 0.0, 1.0)
		draw_circle(f["pos"], float(f["r"]) * a, Color(0.84, 0.97, 1.0, a * 0.85))

	# Confetti shower on bloom
	for c in _confetti:
		var a: float = clampf(float(c["life"]) / float(c["max_life"]), 0.0, 1.0)
		var col: Color = c["color"]
		col.a = a
		draw_circle(c["pos"], float(c["size"]) * (0.45 + 0.55 * a), col)


func _draw_leaf(origin: Vector2, angle: float, length: float) -> void:
	var dir := Vector2.from_angle(angle)
	var perp := dir.orthogonal()
	var tip := origin + dir * length
	var mid := origin + dir * (length * 0.52)
	var pts := PackedVector2Array([
		origin,
		mid + perp * (length * 0.36),
		tip,
		mid - perp * (length * 0.36),
	])
	draw_colored_polygon(pts, Color(0.32, 0.74, 0.34))
	draw_colored_polygon(PackedVector2Array([origin, mid + perp * (length * 0.22), tip]), Color(0.46, 0.84, 0.44, 0.55))
	draw_line(origin, tip, Color(0.20, 0.52, 0.22), 1.7, true)
