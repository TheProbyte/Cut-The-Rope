class_name Seedling
extends Node2D

signal watered

var is_bloomed: bool = false

var _time: float = 0.0
var _bloom_t: float = 0.0
var _shiver_timer: float = 0.0
var _shiver_hint_timer: float = 0.0
var _confetti: Array[Dictionary] = []
var _sensor: Area2D
var _overlapping_droplet: Droplet = null


func _ready() -> void:
	_build_pot_collider()
	_build_sensor()


func _build_pot_collider() -> void:
	# Gentle terracotta saucer/rim that catches Ice cubes calmly without bouncing them off-screen
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.65
	mat.bounce = 0.05
	body.physics_material_override = mat
	add_child(body)

	# Bottom base of pot
	var base := CollisionShape2D.new()
	var base_rect := RectangleShape2D.new()
	base_rect.size = Vector2(92.0, 20.0)
	base.shape = base_rect
	base.position = Vector2(0.0, 34.0)
	body.add_child(base)

	# Subtle left & right pot rims so an ice cube lands neatly in the cup
	for side in [-1.0, 1.0]:
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
	if not droplet.active or is_bloomed:
		return
	if droplet.is_water():
		_bloom(droplet)
	elif droplet.is_ice() and just_entered:
		_shiver_timer = 0.55
		_shiver_hint_timer = 2.0
		AudioManager.play_sfx("seedling_shiver")


func _bloom(droplet: Droplet) -> void:
	is_bloomed = true
	droplet.freeze_for_end()
	droplet.visible = false
	AudioManager.play_sfx("seedling_bloom")

	var colors := [
		Color(1.0, 0.82, 0.25),
		Color(1.0, 0.52, 0.62),
		Color(0.45, 0.85, 0.45),
		Color(0.55, 0.86, 1.0),
	]
	for i in range(18):
		var angle := randf_range(-PI * 0.92, -PI * 0.08)
		var speed := randf_range(90.0, 220.0)
		_confetti.append({
			"pos": Vector2(randf_range(-10, 10), -26.0),
			"vel": Vector2.from_angle(angle) * speed,
			"life": randf_range(0.8, 1.4),
			"max_life": 1.4,
			"size": randf_range(4.0, 7.5),
			"color": colors[i % colors.size()],
		})
	watered.emit()


func _process(delta: float) -> void:
	_time += delta
	if is_bloomed:
		_bloom_t = minf(1.0, _bloom_t + delta * 2.6)
	if _shiver_timer > 0.0:
		_shiver_timer = maxf(0.0, _shiver_timer - delta)
	if _shiver_hint_timer > 0.0:
		_shiver_hint_timer = maxf(0.0, _shiver_hint_timer - delta)

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

	queue_redraw()


func _draw() -> void:
	var shiver_x := sin(_time * 48.0) * 4.0 * (_shiver_timer / 0.55) if _shiver_timer > 0.0 else 0.0
	var base_x := shiver_x

	# Soft floor shadow under terracotta pot
	draw_circle(Vector2(0, 44), 38.0, Color(0.14, 0.24, 0.16, 0.18))

	# Terracotta pot body
	var pot := PackedVector2Array([
		Vector2(-35 + base_x, 4),
		Vector2(35 + base_x, 4),
		Vector2(27 + base_x, 44),
		Vector2(-27 + base_x, 44),
	])
	draw_colored_polygon(pot, Color(0.80, 0.43, 0.27))
	# Pot side shading
	var pot_shade := PackedVector2Array([
		Vector2(14 + base_x, 4),
		Vector2(35 + base_x, 4),
		Vector2(27 + base_x, 44),
		Vector2(12 + base_x, 44),
	])
	draw_colored_polygon(pot_shade, Color(0.66, 0.32, 0.19, 0.55))

	# Rich soil
	draw_rect(Rect2(-34 + base_x, 1, 68, 9), Color(0.32, 0.22, 0.15))

	# Pot rim
	var rim := Rect2(-40 + base_x, -2, 80, 12)
	draw_rect(rim, Color(0.87, 0.50, 0.33))
	draw_rect(Rect2(-40 + base_x, -2, 80, 4), Color(0.95, 0.64, 0.48, 0.65))
	draw_rect(rim, Color(0.55, 0.26, 0.16), false, 2.0)

	# Cute seedling stem & leaves
	var droop := 1.0 - _bloom_t
	var sway := sin(_time * (4.2 if is_bloomed else 2.2)) * (3.5 if is_bloomed else 2.5)
	var head_pos := Vector2(
		base_x + droop * 10.0 + sway,
		lerpf(-28.0, -48.0, _bloom_t)
	)
	var stem_mid := Vector2(base_x + droop * 12.0 + sway * 0.5, lerpf(-12.0, -24.0, _bloom_t))

	# Stem curve
	var stem_pts := PackedVector2Array([
		Vector2(base_x, 2.0),
		stem_mid,
		head_pos,
	])
	draw_polyline(stem_pts, Color(0.28, 0.66, 0.30), 6.5, true)
	draw_polyline(stem_pts, Color(0.42, 0.80, 0.38), 3.0, true)

	# Two leafy sprouts
	var leaf_angle_l := lerpf(-2.2, -2.65, _bloom_t)
	var leaf_angle_r := lerpf(-0.45, -0.5, _bloom_t)
	_draw_leaf(stem_mid + Vector2(-2, 2), leaf_angle_l, 16.0 + _bloom_t * 5.0)
	_draw_leaf(stem_mid + Vector2(2, 2), leaf_angle_r, 16.0 + _bloom_t * 5.0)

	# Flower petals when bloomed
	if _bloom_t > 0.05:
		var petal_r := 11.0 * _bloom_t
		var petal_dist := 16.0 * _bloom_t
		for i in range(6):
			var a := TAU * float(i) / 6.0 + _time * 0.5
			var ppos := head_pos + Vector2.from_angle(a) * petal_dist
			draw_circle(ppos, petal_r, Color(1.0, 0.82, 0.28))
			draw_circle(ppos, petal_r * 0.55, Color(1.0, 0.94, 0.62))

	# Cute sprout head
	var head_r := lerpf(15.0, 17.0, _bloom_t)
	var head_col := Color(0.56, 0.82, 0.42).lerp(Color(0.40, 0.84, 0.38), _bloom_t)
	draw_circle(head_pos, head_r, head_col)
	draw_arc(head_pos, head_r, 0.0, TAU, 24, Color(0.22, 0.52, 0.24), 2.0, true)

	# Seedling face
	var ink := Color(0.12, 0.28, 0.14)
	if is_bloomed:
		# Joyful blooming face!
		draw_arc(head_pos + Vector2(-5.5, -1.0), 3.2, PI + 0.3, TAU - 0.3, 8, ink, 2.0, true)
		draw_arc(head_pos + Vector2(5.5, -1.0), 3.2, PI + 0.3, TAU - 0.3, 8, ink, 2.0, true)
		draw_arc(head_pos + Vector2(0.0, 2.5), 4.8, 0.15, PI - 0.15, 10, ink, 2.0, true)
		draw_circle(head_pos + Vector2(-9.0, 3.0), 2.8, Color(1.0, 0.56, 0.60, 0.6))
		draw_circle(head_pos + Vector2(9.0, 3.0), 2.8, Color(1.0, 0.56, 0.60, 0.6))
	elif _shiver_timer > 0.0:
		# Shivering from Ice!
		draw_line(head_pos + Vector2(-7, -3), head_pos + Vector2(-3, 0), ink, 2.0)
		draw_line(head_pos + Vector2(-7, 2), head_pos + Vector2(-3, 0), ink, 2.0)
		draw_line(head_pos + Vector2(7, -3), head_pos + Vector2(3, 0), ink, 2.0)
		draw_line(head_pos + Vector2(7, 2), head_pos + Vector2(3, 0), ink, 2.0)
		draw_circle(head_pos + Vector2(0, 5.5), 2.8, ink)
	else:
		# Thirsty drooping puppy eyes
		draw_circle(head_pos + Vector2(-5.0, -1.0), 2.5, ink)
		draw_circle(head_pos + Vector2(5.0, -1.0), 2.5, ink)
		draw_circle(head_pos + Vector2(-5.8, -1.8), 0.9, Color.WHITE)
		draw_circle(head_pos + Vector2(4.2, -1.8), 0.9, Color.WHITE)
		draw_arc(head_pos + Vector2(0.0, 7.5), 3.6, PI + 0.4, TAU - 0.4, 8, ink, 1.8, true)

		# Little floating water-drop thought bubble when thirsty
		var bob := sin(_time * 3.0) * 3.0
		var bpos := head_pos + Vector2(24.0, -24.0 + bob)
		draw_circle(bpos, 11.5, Color(1.0, 1.0, 1.0, 0.82))
		draw_circle(bpos + Vector2(-10.0, 11.0), 3.2, Color(1.0, 1.0, 1.0, 0.72))
		draw_circle(bpos + Vector2(0.0, 2.0), 4.5, Color(0.24, 0.74, 0.96))
		draw_colored_polygon(PackedVector2Array([
			bpos + Vector2(0.0, -6.0),
			bpos + Vector2(4.2, 1.0),
			bpos + Vector2(-4.2, 1.0),
		]), Color(0.24, 0.74, 0.96))

	# Confetti burst
	for c in _confetti:
		var a: float = clampf(float(c["life"]) / float(c["max_life"]), 0.0, 1.0)
		var col: Color = c["color"]
		col.a = a
		draw_circle(c["pos"], float(c["size"]) * (0.4 + 0.6 * a), col)


func _draw_leaf(origin: Vector2, angle: float, length: float) -> void:
	var dir := Vector2.from_angle(angle)
	var perp := dir.orthogonal()
	var tip := origin + dir * length
	var mid := origin + dir * (length * 0.52)
	var pts := PackedVector2Array([
		origin,
		mid + perp * (length * 0.34),
		tip,
		mid - perp * (length * 0.34),
	])
	draw_colored_polygon(pts, Color(0.34, 0.74, 0.34))
	draw_line(origin, tip, Color(0.22, 0.54, 0.24), 1.6, true)
