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
## Menu showcases: look at this global point when no droplet is tracked.
var look_target: Vector2 = Vector2.INF
var excite_override: float = -1.0
var _bloom_delay: float = -1.0
var _hop: float = 0.0
var _hop_vel: float = 0.0
var _sparkles: Array[Dictionary] = []
var _blink_timer: float = 3.0
var _blinking: bool = false


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
	droplet.play_end_anim("absorb", global_position + Vector2(0, 2))
	_bloom_delay = 0.34
	watered.emit()


## Starts the bloom celebration (also used by menu showcases).
func play_bloom() -> void:
	is_bloomed = true
	_bloom_delay = -1.0
	_hop_vel = -9.0
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
			"rot": randf_range(0, TAU),
			"vrot": randf_range(-8, 8),
		})
	for i in range(12):
		_sparkles.append({
			"ang": TAU * float(i) / 12.0,
			"life": randf_range(0.6, 1.1),
			"max_life": 1.1,
			"dist": randf_range(30, 46),
		})


func _process(delta: float) -> void:
	_time += delta
	if _bloom_delay > 0.0:
		_bloom_delay -= delta
		if _bloom_delay <= 0.0:
			play_bloom()
	if is_bloomed and _bloom_delay <= 0.0:
		_bloom_t = minf(1.0, _bloom_t + delta * 1.8)
	if _shiver_timer > 0.0:
		_shiver_timer = maxf(0.0, _shiver_timer - delta)

	# Springy hop
	var acc := -160.0 * _hop - 10.0 * _hop_vel
	_hop_vel += acc * delta
	_hop += _hop_vel * delta

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blinking = not _blinking
		_blink_timer = 0.12 if _blinking else randf_range(2.0, 4.5)

	# Eye tracking & anticipation excitement
	var target_excite := 0.0
	if not is_bloomed and _tracked_droplet != null and is_instance_valid(_tracked_droplet) and _tracked_droplet.active:
		var delta_v := _tracked_droplet.global_position - (global_position + Vector2(0, -34))
		var dist := delta_v.length()
		if dist > 4.0:
			_look_dir = _look_dir.lerp(delta_v.normalized(), clampf(delta * 8.0, 0.0, 1.0))
		if dist < 230.0 and _tracked_droplet.is_water() and not _tracked_droplet.soaked:
			target_excite = clampf(1.0 - (dist / 230.0), 0.0, 1.0)
	elif look_target != Vector2.INF:
		var dv := look_target - (global_position + Vector2(0, -34) * scale)
		if dv.length() > 4.0:
			_look_dir = _look_dir.lerp(dv.normalized(), clampf(delta * 6.0, 0.0, 1.0))
	if excite_override >= 0.0 and not is_bloomed:
		target_excite = excite_override
	_excite_t = lerpf(_excite_t, target_excite, clampf(delta * 7.0, 0.0, 1.0))

	for i in range(_confetti.size() - 1, -1, -1):
		var c: Dictionary = _confetti[i]
		c["life"] = float(c["life"]) - delta
		if float(c["life"]) <= 0.0:
			_confetti.remove_at(i)
		else:
			var vel: Vector2 = c["vel"]
			vel.y += 300.0 * delta
			vel.x *= 1.0 - delta * 1.2
			c["vel"] = vel
			c["pos"] = (c["pos"] as Vector2) + vel * delta
			c["rot"] = float(c["rot"]) + float(c["vrot"]) * delta

	for i in range(_frost_puffs.size() - 1, -1, -1):
		var f: Dictionary = _frost_puffs[i]
		f["life"] = float(f["life"]) - delta
		if float(f["life"]) <= 0.0:
			_frost_puffs.remove_at(i)
		else:
			f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * delta

	for i in range(_sparkles.size() - 1, -1, -1):
		var sp: Dictionary = _sparkles[i]
		sp["life"] = float(sp["life"]) - delta
		sp["dist"] = float(sp["dist"]) + delta * 40.0
		if float(sp["life"]) <= 0.0:
			_sparkles.remove_at(i)

	queue_redraw()


static func _elastic(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * (TAU / 3.0)) + 1.0


func _draw() -> void:
	var shiver_x := sin(_time * 48.0) * 4.0 * (_shiver_timer / 0.65) if _shiver_timer > 0.0 else 0.0
	var bx := shiver_x
	var hop := minf(0.0, _hop) * 3.0
	var squash := clampf(_hop * 0.05, -0.12, 0.12)
	var bloom_e := _elastic(_bloom_t)

	Art.draw_ground_shadow(self, Vector2(2, 46), 40.0 - hop * 0.2, 7.0, 0.22)

	# Radiant halo behind bloomed flower
	if _bloom_t > 0.02:
		var halo := Vector2(bx, -58.0 + hop)
		Art.draw_glow(self, halo, 90.0 * bloom_e, Color(1.0, 0.86, 0.36, 0.55 * _bloom_t))
		for i in range(12):
			var a := _time * 0.6 + TAU * float(i) / 12.0
			draw_line(halo + Vector2.from_angle(a) * 34.0 * bloom_e, halo + Vector2.from_angle(a) * (58.0 + 6.0 * sin(_time * 3.0 + float(i))) * bloom_e,
				Color(1.0, 0.92, 0.5, 0.45 * _bloom_t), 3.0, true)

	draw_set_transform(Vector2(bx, hop), 0.0, Vector2(1.0 + squash, 1.0 - squash))

	# Stem posture: droopy -> perks up with excitement -> tall bloom
	var perk := maxf(bloom_e, _excite_t * 0.7)
	var droop := 1.0 - clampf(perk, 0.0, 1.0)
	var sway_spd := 3.6 if is_bloomed else (7.0 if _excite_t > 0.3 else 2.0)
	var sway := sin(_time * sway_spd) * (3.0 if is_bloomed else (3.0 if _excite_t > 0.3 else 2.4))
	var head_pos := Vector2(droop * 12.0 + sway, lerpf(-30.0, -60.0, perk))
	var ctrl := Vector2(droop * 16.0 + sway * 0.3, lerpf(-14.0, -30.0, perk))
	var stem := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		stem.append(Vector2.ZERO.lerp(ctrl, t).lerp(ctrl.lerp(head_pos, t), t))
	draw_polyline(stem, Art.LEAF_DEEP, 8.0, true)
	draw_polyline(stem, Color(0.46, 0.82, 0.42), 3.6, true)

	# Leaves
	var leaf_root := stem[3]
	_draw_leaf(leaf_root, lerpf(-2.3, -2.75, perk) - sway * 0.02, 19.0 + perk * 7.0)
	_draw_leaf(leaf_root + Vector2(1, 3), lerpf(-0.75, -0.40, perk) + sway * 0.02, 18.0 + perk * 7.0)

	# Pot (drawn over the stem base)
	_draw_pot()

	# Flower petals
	if _bloom_t > 0.02:
		var pr := 13.5 * bloom_e
		var pd := 19.0 * bloom_e
		var petal_cols := [Color(1.0, 0.60, 0.68), Color(1.0, 0.76, 0.30)]
		for layer in range(2):
			var n := 8
			for i in range(n):
				var a := TAU * float(i) / float(n) + _time * 0.35 + float(layer) * (PI / float(n))
				var dist := pd * (1.0 if layer == 0 else 0.68)
				var pp := head_pos + Vector2.from_angle(a) * dist
				var col: Color = petal_cols[layer]
				var pts := Art.ellipse_points(Vector2.ZERO, pr * (1.0 if layer == 0 else 0.8), pr * 0.62, 16)
				var rotated := PackedVector2Array()
				for q in pts:
					rotated.append(pp + q.rotated(a))
				draw_colored_polygon(rotated, col.darkened(0.12))
				var inner := PackedVector2Array()
				for q in pts:
					inner.append(pp + (q * 0.78).rotated(a) - Vector2(0, 1))
				draw_colored_polygon(inner, col)

	# Head bud / flower center
	var head_r := lerpf(16.0, 17.5, _bloom_t)
	var bud_top := Color(0.66, 0.90, 0.52).lerp(Color(1.0, 0.92, 0.50), _bloom_t)
	var bud_bot := Color(0.40, 0.74, 0.36).lerp(Color(0.98, 0.74, 0.26), _bloom_t)
	if _shiver_timer > 0.0:
		bud_top = bud_top.lerp(Color(0.80, 0.94, 1.0), 0.5)
		bud_bot = bud_bot.lerp(Color(0.56, 0.80, 0.94), 0.5)
	var head := Art.ellipse_points(head_pos, head_r, head_r * 0.94, 28)
	draw_polygon(head, Art.vgrad_colors(head, bud_top, bud_bot))
	Art.draw_ellipse(self, head_pos + Vector2(-5.5, -6.0), 5.0, 3.4, Color(1, 1, 1, 0.45))
	draw_polyline(Art.closed(head), Art.LEAF_DEEP if _bloom_t < 0.5 else Art.SUN_DEEP, 2.2, true)
	if _bloom_t < 0.5:
		# little bud tuft
		draw_colored_polygon(PackedVector2Array([
			head_pos + Vector2(-4, -head_r + 2), head_pos + Vector2(2 + sway * 0.4, -head_r - 9), head_pos + Vector2(5, -head_r + 3)
		]), Art.LEAF)

	# Face
	var ink := Color(0.12, 0.26, 0.14)
	var look := _look_dir * 2.2
	if is_bloomed:
		Art.draw_face(self, head_pos + Vector2(0, 1), 0.95, ink, "joy")
	elif _shiver_timer > 0.0:
		Art.draw_face(self, head_pos + Vector2(0, 1), 0.9, ink, "wince")
	elif _excite_t > 0.3:
		Art.draw_face(self, head_pos + Vector2(0, 1), 0.92, ink, "scared", look, _blinking)
	else:
		Art.draw_face(self, head_pos + Vector2(0, 1), 0.88, ink, "worried", look, _blinking)
		# Thirsty thought bubble
		var bob := sin(_time * 2.6) * 3.0
		var bpos := head_pos + Vector2(27.0, -27.0 + bob)
		draw_circle(bpos + Vector2(-11.0, 12.0), 3.0, Color(1, 1, 1, 0.85))
		draw_circle(bpos + Vector2(-16.0, 18.0), 1.8, Color(1, 1, 1, 0.75))
		draw_circle(bpos + Vector2(1, 2), 13.0, Color(0.2, 0.3, 0.2, 0.10))
		draw_circle(bpos, 13.0, Color(1, 1, 1, 0.95))
		var drop := PackedVector2Array()
		for i in range(20):
			var a := TAU * float(i) / 20.0
			var up := maxf(0.0, -sin(a))
			drop.append(bpos + Vector2(cos(a) * 5.0 * (1.0 - up * 0.6), sin(a) * 5.0 - up * up * 4.5 + 1.8))
		draw_colored_polygon(drop, Art.WATER)
		draw_circle(bpos + Vector2(-1.6, 1.0), 1.3, Color(1, 1, 1, 0.8))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for f in _frost_puffs:
		var a: float = clampf(float(f["life"]) / float(f["max_life"]), 0.0, 1.0)
		draw_circle(f["pos"], float(f["r"]) * (1.4 - 0.4 * a), Color(0.84, 0.97, 1.0, a * 0.85))
		Art.draw_sparkle(self, (f["pos"] as Vector2) + Vector2(5, -4), 4.0 * a, Color(1, 1, 1, a))

	for sp in _sparkles:
		var a: float = clampf(float(sp["life"]) / float(sp["max_life"]), 0.0, 1.0)
		var p := Vector2(0, -58) + Vector2.from_angle(float(sp["ang"])) * float(sp["dist"])
		Art.draw_sparkle(self, p, 7.0 * a, Color(1.0, 0.96, 0.7, a))

	for c in _confetti:
		var a: float = clampf(float(c["life"]) / float(c["max_life"]), 0.0, 1.0)
		var col: Color = c["color"]
		col.a = a
		var sz := float(c["size"]) * (0.5 + 0.5 * a)
		var r := float(c["rot"])
		var p: Vector2 = c["pos"]
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-sz, -sz * 0.45).rotated(r), p + Vector2(sz, -sz * 0.45).rotated(r),
			p + Vector2(sz, sz * 0.45).rotated(r), p + Vector2(-sz, sz * 0.45).rotated(r),
		]), col)


func _draw_pot() -> void:
	var body := PackedVector2Array([
		Vector2(-34, 6), Vector2(34, 6), Vector2(27, 40), Vector2(24, 44),
		Vector2(-24, 44), Vector2(-27, 40),
	])
	draw_polygon(body, Art.vgrad_colors(body, Color(0.92, 0.54, 0.34), Color(0.74, 0.36, 0.22)))
	draw_colored_polygon(PackedVector2Array([Vector2(-27, 8), Vector2(-15, 8), Vector2(-17, 41), Vector2(-23, 41)]), Color(1.0, 0.76, 0.58, 0.40))
	# painted heart
	var hc := Vector2(6, 25)
	draw_circle(hc + Vector2(-3, -2), 3.6, Color(1.0, 0.86, 0.72, 0.85))
	draw_circle(hc + Vector2(3, -2), 3.6, Color(1.0, 0.86, 0.72, 0.85))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-6.4, -1), hc + Vector2(6.4, -1), hc + Vector2(0, 6)]), Color(1.0, 0.86, 0.72, 0.85))
	draw_polyline(Art.closed(body), Art.TERRACOTTA_DEEP, 2.4, true)
	# soil
	Art.draw_ellipse(self, Vector2(0, 3), 32.0, 6.0, Color(0.34, 0.22, 0.14))
	if _bloom_t > 0.0 or is_bloomed:
		Art.draw_ellipse(self, Vector2(0, 3), 28.0, 4.5, Color(0.22, 0.14, 0.10))
	# rim
	var rim := Rect2(-41, -4, 82, 14)
	Art.draw_rrect_grad(self, rim, 5.0, Color(0.98, 0.64, 0.44), Color(0.82, 0.44, 0.28))
	draw_rect(Rect2(-37, -2, 74, 3), Color(1.0, 0.84, 0.70, 0.7))
	Art.draw_rrect_outline(self, rim, 5.0, Art.TERRACOTTA_DEEP, 2.4)


func _draw_leaf(origin: Vector2, angle: float, length: float) -> void:
	var dir := Vector2.from_angle(angle)
	var perp := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		pts.append(origin + dir * (length * t) + perp * sin(t * PI) * length * 0.34)
	for i in range(7, 0, -1):
		var t := float(i) / 8.0
		pts.append(origin + dir * (length * t) - perp * sin(t * PI) * length * 0.30)
	draw_colored_polygon(pts, Art.LEAF)
	var hi := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		hi.append(origin + dir * (length * t) + perp * sin(t * PI) * length * 0.22)
	hi.append(origin + dir * length * 0.5)
	draw_colored_polygon(hi, Color(0.62, 0.90, 0.52, 0.55))
	draw_polyline(Art.closed(pts), Art.LEAF_DEEP, 1.6, true)
	draw_line(origin, origin + dir * length * 0.85, Art.LEAF_DEEP, 1.4, true)


## Menu showcase: return to the thirsty state.
func reset_bloom() -> void:
	is_bloomed = false
	_bloom_t = 0.0
	_bloom_delay = -1.0
