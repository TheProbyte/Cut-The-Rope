class_name Sponge
extends Node2D

const TAP_RADIUS := 60.0

var sponge_size: Vector2 = Vector2(92.0, 44.0)
var release_dir: Vector2 = Vector2.DOWN
var launch_speed: float = 85.0
var holding_droplet: Droplet = null

var _sensor: Area2D
var _reabsorb_cooldown: float = 0.0
var _time: float = 0.0
var _squish_x: float = 1.0
var _squish_y: float = 1.0
var _drip_y: float = 0.0
var _splashes: Array[Dictionary] = []
var _pores: Array[Dictionary] = []


func configure(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("pos", [360, 500])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	var sz_arr: Array = cfg.get("size", [92, 44])
	sponge_size = Vector2(float(sz_arr[0]), float(sz_arr[1]))
	rotation = deg_to_rad(float(cfg.get("rotation", 0.0)))
	launch_speed = float(cfg.get("launch_speed", 85.0))

	var dir_val: Variant = cfg.get("release_dir", "down")
	if typeof(dir_val) == TYPE_STRING:
		match String(dir_val).to_lower():
			"down":
				release_dir = Vector2.DOWN
			"up":
				release_dir = Vector2.UP
			"left":
				release_dir = Vector2.LEFT
			"right":
				release_dir = Vector2.RIGHT
			_:
				release_dir = Vector2.DOWN
	else:
		release_dir = Vector2.from_angle(deg_to_rad(float(dir_val)))

	# Layer 2 collider: Ice bounces & slides cleanly over Sponges while Water & Steam pass into sensor!
	var ice_body := StaticBody2D.new()
	ice_body.collision_layer = 2
	ice_body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.04
	mat.bounce = 0.35
	ice_body.physics_material_override = mat
	var ice_col := CollisionShape2D.new()
	var ice_rect := RectangleShape2D.new()
	ice_rect.size = sponge_size
	ice_col.shape = ice_rect
	ice_body.add_child(ice_col)
	add_child(ice_body)

	# Water soak sensor
	_sensor = Area2D.new()
	_sensor.collision_layer = 16
	_sensor.collision_mask = 8
	var s_col := CollisionShape2D.new()
	var s_rect := RectangleShape2D.new()
	s_rect.size = sponge_size + Vector2(8.0, 8.0)
	s_col.shape = s_rect
	_sensor.add_child(s_col)
	add_child(_sensor)

	_sensor.body_entered.connect(_on_body_entered)

	# Deterministic cozy sponge pores
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 17.0 + position.y * 31.0)
	for i in range(11):
		_pores.append({
			"pos": Vector2(
				rng.randf_range(-sponge_size.x * 0.38, sponge_size.x * 0.38),
				rng.randf_range(-sponge_size.y * 0.22, sponge_size.y * 0.30)
			),
			"r": rng.randf_range(2.8, 5.2),
		})
	queue_redraw()


func contains_point(global_pt: Vector2) -> bool:
	return global_position.distance_to(global_pt) <= maxf(TAP_RADIUS, sponge_size.x * 0.62)


func has_water() -> bool:
	return holding_droplet != null and is_instance_valid(holding_droplet)


func squeeze() -> bool:
	if not has_water():
		# Cute dry bounce if tapped while empty
		_squish_x = 1.14
		_squish_y = 0.84
		AudioManager.play_sfx("ui_tap", 0.9, -6.0)
		return false

	var d := holding_droplet
	holding_droplet = null
	_reabsorb_cooldown = 0.55
	var dir := release_dir.normalized()
	var offset_dist := (sponge_size.y * 0.5 + 24.0) if absf(dir.y) >= absf(dir.x) else (sponge_size.x * 0.5 + 24.0)
	var release_pos := global_position + dir * offset_dist
	d.release_from_sponge(release_pos, dir * launch_speed)
	AudioManager.play_sfx("sponge_squeeze")

	_squish_x = 1.32
	_squish_y = 0.68
	for i in range(10):
		var a := dir.angle() + randf_range(-0.85, 0.85)
		_splashes.append({
			"pos": dir * (sponge_size.y * 0.4),
			"vel": Vector2.from_angle(a) * randf_range(75.0, 160.0),
			"life": 0.40,
			"max_life": 0.40,
			"r": randf_range(3.2, 5.8),
		})
	queue_redraw()
	return true


func _on_body_entered(body: Node) -> void:
	if has_water() or _reabsorb_cooldown > 0.0:
		return
	if body is Droplet:
		var d := body as Droplet
		if d.active and not d.soaked and d.is_water():
			holding_droplet = d
			d.soak_into_sponge(global_position)
			AudioManager.play_sfx("sponge_soak")
			_squish_x = 1.24
			_squish_y = 1.22
			queue_redraw()


func _physics_process(delta: float) -> void:
	if _reabsorb_cooldown > 0.0:
		_reabsorb_cooldown = maxf(0.0, _reabsorb_cooldown - delta)
	if has_water():
		holding_droplet.global_position = global_position


func _process(delta: float) -> void:
	_time += delta
	var target_x := (1.10 + sin(_time * 4.5) * 0.03) if has_water() else 1.0
	var target_y := (1.14 - sin(_time * 4.5) * 0.03) if has_water() else 1.0
	_squish_x = lerpf(_squish_x, target_x, clampf(delta * 9.0, 0.0, 1.0))
	_squish_y = lerpf(_squish_y, target_y, clampf(delta * 9.0, 0.0, 1.0))

	if has_water():
		_drip_y = fmod(_drip_y + delta * 36.0, 26.0)
	for i in range(_splashes.size() - 1, -1, -1):
		var s: Dictionary = _splashes[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_splashes.remove_at(i)
		else:
			var vel: Vector2 = s["vel"]
			vel.y += 320.0 * delta
			s["vel"] = vel
			s["pos"] = (s["pos"] as Vector2) + vel * delta
	queue_redraw()


func _draw() -> void:
	var wet := has_water()
	var w := sponge_size.x * _squish_x
	var h := sponge_size.y * _squish_y
	var hw := w * 0.5
	var hh := h * 0.5

	# Tactile tap glow halo when full of water!
	if wet:
		var pulse := 0.55 + 0.35 * sin(_time * 5.0)
		draw_arc(Vector2.ZERO, maxf(hw, hh) + 12.0 + sin(_time * 5.0) * 3.0, 0.0, TAU, 32, Color(0.24, 0.78, 0.98, pulse * 0.65), 3.0, true)

	# Drop shadow
	draw_rect(Rect2(-hw + 3.0, -hh + 6.0, w, h), Color(0.14, 0.16, 0.10, 0.20))

	# Main golden kitchen sponge body (richer wet amber-aqua tint when soaked)
	var base_col := Color(0.76, 0.72, 0.26) if wet else Color(0.98, 0.84, 0.30)
	var hi_col := Color(0.88, 0.88, 0.48, 0.65) if wet else Color(1.0, 0.94, 0.58, 0.75)
	var rim_col := Color(0.46, 0.42, 0.14) if wet else Color(0.68, 0.50, 0.12)
	draw_rect(Rect2(-hw, -hh, w, h), base_col)

	# Scouring green top pad strip (classic cozy kitchen sponge!)
	var pad_h := h * 0.24
	draw_rect(Rect2(-hw, -hh, w, pad_h), Color(0.28, 0.66, 0.34) if wet else Color(0.36, 0.74, 0.38))
	draw_rect(Rect2(-hw + 3.0, -hh + pad_h + 2.0, w - 6.0, h * 0.20), hi_col)

	# Cute sponge pores
	var pore_col := Color(0.22, 0.64, 0.84, 0.55) if wet else Color(0.84, 0.64, 0.16, 0.55)
	for p in _pores:
		var pos := Vector2((p["pos"] as Vector2).x * _squish_x, (p["pos"] as Vector2).y * _squish_y)
		draw_circle(pos, float(p["r"]), pore_col)

	draw_rect(Rect2(-hw, -hh, w, h), rim_col, false, 2.4)

	# Animated water drip bead & downward arrow cue when soaked
	if wet:
		var dir := release_dir.rotated(-rotation).normalized()
		var drip_start := dir * (hh + 3.0)
		var drip_pos := drip_start + dir * _drip_y
		var drip_alpha := 1.0 - (_drip_y / 26.0)
		draw_circle(drip_pos, 4.5, Color(0.24, 0.78, 0.98, drip_alpha))
		# Subtle tap hint chevron
		var tip := dir * (hh + 15.0)
		var perp := dir.orthogonal() * 7.0
		draw_polyline(PackedVector2Array([tip - dir * 6.0 - perp, tip, tip - dir * 6.0 + perp]), Color(0.20, 0.72, 0.94, 0.85), 2.5, true)

	# Release splash particles
	for s in _splashes:
		var a: float = clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		draw_circle(s["pos"], float(s["r"]) * a, Color(0.30, 0.82, 1.0, a))
