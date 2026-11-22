class_name Droplet
extends RigidBody2D

enum State { WATER, ICE, STEAM }

signal state_changed(new_state: int, forced: bool)
signal lost(reason: String)

const LAYER_TERRAIN := 1
const LAYER_GRATE := 2
const LAYER_GLASS := 4
const LAYER_DROPLET := 8

var state: State = State.WATER
var active: bool = true
var soaked: bool = false

var _heat_zones: int = 0
var _freezer_zones: int = 0
var _time: float = 0.0
var _squish: float = 0.0
var _squish_vel: float = 0.0
var _pop_scale: float = 1.0
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _trail_timer: float = 0.0
var _ice_sparkle_timer: float = 0.0
var _blink_timer: float = 2.4
var _blinking: bool = false
var _water_shape: CollisionShape2D
var _ice_shape: CollisionShape2D
var _steam_shape: CollisionShape2D
var _phys_mat: PhysicsMaterial


func _ready() -> void:
	collision_layer = LAYER_DROPLET
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	can_sleep = false

	_phys_mat = PhysicsMaterial.new()
	physics_material_override = _phys_mat

	_build_shapes()
	body_entered.connect(_on_body_entered)
	set_state(state, false, true)
	# Cute bouncy entrance pop
	_pop_scale = 0.35
	_squish = -0.25


func _build_shapes() -> void:
	_water_shape = CollisionShape2D.new()
	var w_circle := CircleShape2D.new()
	w_circle.radius = 21.0
	_water_shape.shape = w_circle
	add_child(_water_shape)

	_ice_shape = CollisionShape2D.new()
	var bevel := ConvexPolygonShape2D.new()
	var r := 21.0
	var c := 6.0
	bevel.points = PackedVector2Array([
		Vector2(-r + c, -r), Vector2(r - c, -r),
		Vector2(r, -r + c), Vector2(r, r - c),
		Vector2(r - c, r), Vector2(-r + c, r),
		Vector2(-r, r - c), Vector2(-r, -r + c),
	])
	_ice_shape.shape = bevel
	add_child(_ice_shape)

	_steam_shape = CollisionShape2D.new()
	var s_circle := CircleShape2D.new()
	s_circle.radius = 23.0
	_steam_shape.shape = s_circle
	add_child(_steam_shape)


func cycle_state() -> bool:
	if not active or soaked:
		return false
	if _heat_zones > 0:
		_pop_scale = 1.18
		AudioManager.play_sfx("steam", 1.15, -7.0)
		return false
	if _freezer_zones > 0:
		_pop_scale = 1.18
		AudioManager.play_sfx("ice", 1.15, -7.0)
		return false
	var next_state: State = ((int(state) + 1) % 3) as State
	set_state(next_state, false, false)
	return true


func set_state(new_state: State, forced: bool = false, silent: bool = false) -> void:
	var changed := (state != new_state) or silent
	state = new_state

	match state:
		State.WATER:
			gravity_scale = 1.0
			mass = 1.0
			linear_damp = 0.20
			angular_damp = 2.0
			set_deferred("lock_rotation", true)
			angular_velocity = 0.0
			_phys_mat.friction = 0.02
			_phys_mat.bounce = 0.12
			collision_mask = LAYER_TERRAIN | LAYER_GLASS
			_set_active_shape(_water_shape)
			if not silent and changed:
				AudioManager.play_sfx("water")
				_spawn_state_burst(Color(0.32, 0.80, 0.99), 10)
				_rings.append({"r": 12.0, "max_r": 46.0, "life": 0.26, "max_life": 0.26, "col": Color(0.35, 0.84, 1.0)})
		State.ICE:
			gravity_scale = 1.32
			mass = 2.4
			linear_damp = 0.06
			angular_damp = 2.4
			set_deferred("lock_rotation", false)
			_phys_mat.friction = 0.02
			_phys_mat.bounce = 0.24
			collision_mask = LAYER_TERRAIN | LAYER_GRATE | LAYER_GLASS
			_set_active_shape(_ice_shape)
			if not silent and changed:
				AudioManager.play_sfx("ice")
				_spawn_state_burst(Color(0.78, 0.96, 1.0), 12)
				_rings.append({"r": 14.0, "max_r": 48.0, "life": 0.24, "max_life": 0.24, "col": Color(0.84, 0.98, 1.0)})
		State.STEAM:
			gravity_scale = -0.46
			mass = 0.35
			linear_damp = 1.15
			angular_damp = 4.0
			set_deferred("lock_rotation", true)
			angular_velocity = 0.0
			_phys_mat.friction = 0.0
			_phys_mat.bounce = 0.12
			collision_mask = LAYER_TERRAIN | LAYER_GLASS
			_set_active_shape(_steam_shape)
			if linear_velocity.y > 140.0:
				linear_velocity.y *= 0.45
			if not silent and changed:
				AudioManager.play_sfx("steam")
				_spawn_state_burst(Color(0.97, 0.99, 1.0), 11)
				_rings.append({"r": 16.0, "max_r": 52.0, "life": 0.30, "max_life": 0.30, "col": Color(1.0, 1.0, 1.0)})

	if not silent:
		_pop_scale = 1.34
		_squish = 0.26
		state_changed.emit(int(state), forced)
	queue_redraw()


func _set_active_shape(active_shape: CollisionShape2D) -> void:
	if _water_shape == null:
		return
	_water_shape.set_deferred("disabled", active_shape != _water_shape)
	_ice_shape.set_deferred("disabled", active_shape != _ice_shape)
	_steam_shape.set_deferred("disabled", active_shape != _steam_shape)


func is_water() -> bool:
	return state == State.WATER


func is_ice() -> bool:
	return state == State.ICE


func is_steam() -> bool:
	return state == State.STEAM


func soak_into_sponge(sponge_pos: Vector2) -> void:
	soaked = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)
	visible = false
	global_position = sponge_pos


func release_from_sponge(release_pos: Vector2, launch_vel: Vector2) -> void:
	soaked = false
	global_position = release_pos
	visible = true
	set_deferred("freeze", false)
	set_state(State.WATER, false, true)
	linear_velocity = launch_vel
	_pop_scale = 1.32
	_squish = -0.24
	_spawn_state_burst(Color(0.36, 0.84, 1.0), 10)
	state_changed.emit(int(state), false)


func enter_heat_zone() -> void:
	_heat_zones += 1
	if active and not soaked and state != State.STEAM:
		set_state(State.STEAM, true, false)


func exit_heat_zone() -> void:
	_heat_zones = maxi(0, _heat_zones - 1)


func enter_freezer_zone() -> void:
	_freezer_zones += 1
	if active and not soaked and state != State.ICE:
		set_state(State.ICE, true, false)


func exit_freezer_zone() -> void:
	_freezer_zones = maxi(0, _freezer_zones - 1)


func condense_to_water() -> void:
	if not active or soaked or state != State.STEAM:
		return
	if _heat_zones > 0:
		return
	linear_velocity.y = maxf(linear_velocity.y, 45.0)
	linear_velocity.x *= 0.35
	AudioManager.play_sfx("condense")
	set_state(State.WATER, true, true)
	_pop_scale = 1.30
	_spawn_state_burst(Color(0.45, 0.85, 1.0), 10)
	state_changed.emit(int(state), true)


func apply_wind_force(wind_vector: Vector2) -> void:
	if not active or soaked:
		return
	var mult := 1.0
	match state:
		State.STEAM:
			mult = 1.0
		State.WATER:
			mult = 0.24
		State.ICE:
			mult = 0.04
	apply_central_force(wind_vector * mult)


func freeze_for_end() -> void:
	active = false
	soaked = false
	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _on_body_entered(_body: Node) -> void:
	if not active or soaked:
		return
	var speed := linear_velocity.length()
	if speed > 85.0:
		_squish = clampf(speed / 500.0, 0.10, 0.34)
		if state == State.WATER and speed > 160.0:
			_spawn_state_burst(Color(0.45, 0.88, 1.0, 0.85), 5)
		elif state == State.ICE and speed > 180.0:
			_spawn_state_burst(Color(0.86, 0.97, 1.0, 0.9), 5)


func _physics_process(delta: float) -> void:
	if not active or soaked:
		return
	if _heat_zones > 0 and state != State.STEAM:
		set_state(State.STEAM, true, false)
	elif _freezer_zones > 0 and state != State.ICE:
		set_state(State.ICE, true, false)

	if state != State.ICE and absf(rotation) > 0.001:
		rotation = lerpf(rotation, 0.0, delta * 14.0)

	if state == State.STEAM:
		if linear_velocity.y < -155.0:
			linear_velocity.y = lerpf(linear_velocity.y, -155.0, delta * 8.0)
		if absf(linear_velocity.x) > 250.0:
			linear_velocity.x = lerpf(linear_velocity.x, signf(linear_velocity.x) * 250.0, delta * 5.0)

	# Out-of-bounds checks
	if global_position.y < 76.0 and state == State.STEAM:
		active = false
		lost.emit("evaporated")
	elif global_position.y < -30.0:
		active = false
		lost.emit("evaporated")
	elif global_position.y > 1320.0 or global_position.x < -45.0 or global_position.x > 765.0:
		active = false
		lost.emit("fell")


func _process(delta: float) -> void:
	_time += delta

	_pop_scale = lerpf(_pop_scale, 1.0, clampf(delta * 10.0, 0.0, 1.0))
	var spring_acc := -135.0 * _squish - 12.0 * _squish_vel
	_squish_vel += spring_acc * delta
	_squish += _squish_vel * delta

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		if _blinking:
			_blinking = false
			_blink_timer = randf_range(2.2, 4.4)
		else:
			_blinking = true
			_blink_timer = 0.13

	if active and not soaked:
		if state == State.STEAM:
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = 0.09
				_particles.append({
					"pos": Vector2(randf_range(-13, 13), randf_range(4, 15)),
					"vel": Vector2(randf_range(-18, 18), randf_range(-26, -8)),
					"life": 0.60,
					"max_life": 0.60,
					"radius": randf_range(5.5, 10.5),
					"color": Color(0.98, 0.99, 1.0, 0.62),
					"star": false,
				})
		elif state == State.WATER and linear_velocity.length() > 140.0:
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = 0.075
				var back := -linear_velocity.normalized() * 14.0
				_particles.append({
					"pos": back + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
					"vel": back * 1.4 + Vector2(randf_range(-16, 16), randf_range(-16, 16)),
					"life": 0.30,
					"max_life": 0.30,
					"radius": randf_range(2.8, 4.8),
					"color": Color(0.42, 0.86, 1.0, 0.72),
					"star": false,
				})
		elif state == State.ICE:
			_ice_sparkle_timer -= delta
			if _ice_sparkle_timer <= 0.0:
				_ice_sparkle_timer = 0.18
				_particles.append({
					"pos": Vector2(randf_range(-20, 20), randf_range(-20, 20)),
					"vel": Vector2(randf_range(-14, 14), randf_range(-22, 8)),
					"life": 0.45,
					"max_life": 0.45,
					"radius": randf_range(3.2, 5.2),
					"color": Color(0.92, 0.99, 1.0, 0.95),
					"star": true,
				})

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		else:
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta

	for i in range(_rings.size() - 1, -1, -1):
		var rg: Dictionary = _rings[i]
		rg["life"] = float(rg["life"]) - delta
		if float(rg["life"]) <= 0.0:
			_rings.remove_at(i)
		else:
			var prog := 1.0 - float(rg["life"]) / float(rg["max_life"])
			rg["r"] = lerpf(12.0, float(rg["max_r"]), prog)

	queue_redraw()


func _spawn_state_burst(base_color: Color, count: int) -> void:
	for i in range(count):
		var angle := (TAU * float(i) / float(count)) + randf_range(-0.28, 0.28)
		var spd := randf_range(50.0, 125.0)
		_particles.append({
			"pos": Vector2.from_angle(angle) * 10.0,
			"vel": Vector2.from_angle(angle) * spd,
			"life": randf_range(0.30, 0.50),
			"max_life": 0.50,
			"radius": randf_range(3.5, 6.8),
			"color": base_color,
			"star": state == State.ICE,
		})


func _draw() -> void:
	if soaked:
		return

	# Expanding state-morph ripple rings
	for rg in _rings:
		var a: float = clampf(float(rg["life"]) / float(rg["max_life"]), 0.0, 1.0)
		var col: Color = rg["col"]
		col.a = a * 0.55
		draw_arc(Vector2.ZERO, float(rg["r"]), 0.0, TAU, 28, col, 2.8, true)

	# Ambient & burst particles
	for p in _particles:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= alpha
		var r: float = float(p["radius"]) * (0.45 + 0.55 * alpha)
		var pos: Vector2 = p["pos"]
		if bool(p.get("star", false)):
			draw_line(pos + Vector2(-r, 0), pos + Vector2(r, 0), col, 1.8, true)
			draw_line(pos + Vector2(0, -r), pos + Vector2(0, r), col, 1.8, true)
		else:
			draw_circle(pos, r, col)

	match state:
		State.WATER:
			_draw_water()
		State.ICE:
			_draw_ice()
		State.STEAM:
			_draw_steam()


func _draw_water() -> void:
	var wobble_x := sin(_time * 6.8) * 0.048 + _squish * 0.62
	var wobble_y := -wobble_x
	var vel_stretch := clampf(linear_velocity.length() / 850.0, 0.0, 0.16)
	var sx := _pop_scale * (1.0 + wobble_x - vel_stretch * 0.34)
	var sy := _pop_scale * (1.0 + wobble_y + vel_stretch * 0.46)

	var pts := PackedVector2Array()
	var shadow_pts := PackedVector2Array()
	var steps := 32
	var r := 22.0
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		var ca := cos(a)
		var sa := sin(a)
		var top_taper := 1.0 - maxf(0.0, -sa) * 0.19
		var top_lift := maxf(0.0, -sa) * 5.2
		var px := ca * r * top_taper * sx
		var py := (sa * r - top_lift) * sy
		pts.append(Vector2(px, py))
		shadow_pts.append(Vector2(px + 3.5, py + 6.0))

	# Soft luminous aqua halo + drop shadow
	draw_circle(Vector2(0, -1), 28.0 * _pop_scale, Color(0.32, 0.84, 1.0, 0.16))
	draw_colored_polygon(shadow_pts, Color(0.06, 0.22, 0.34, 0.22))

	# Deep azure outer droplet
	draw_colored_polygon(pts, Color(0.11, 0.60, 0.89, 0.94))

	# Bright translucent mid-body
	var mid_pts := PackedVector2Array()
	for pt in pts:
		mid_pts.append(pt * 0.86 + Vector2(-0.8, -1.6))
	draw_colored_polygon(mid_pts, Color(0.30, 0.80, 0.98, 0.72))

	# Animated bottom internal caustic light pool (refracted sunlight!)
	var caustic_shift := sin(_time * 4.2) * 2.2
	draw_circle(Vector2(caustic_shift, 9.5 * sy), 9.2 * _pop_scale, Color(0.76, 0.96, 1.0, 0.44))

	# Crisp specular gloss highlights
	draw_circle(Vector2(-7.5 * sx, -9.0 * sy), 5.0 * _pop_scale, Color(1.0, 1.0, 1.0, 0.78))
	draw_circle(Vector2(-3.2 * sx, -14.8 * sy), 2.3 * _pop_scale, Color(1.0, 1.0, 1.0, 0.65))
	draw_circle(Vector2(8.5 * sx, 9.0 * sy), 2.2 * _pop_scale, Color(1.0, 1.0, 1.0, 0.42))

	# Soft Fresnel rim outline
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.08, 0.44, 0.70, 0.90), 2.4, true)

	_draw_face(Vector2(0, 2.0), Color(0.06, 0.20, 0.32), false, false)


func _draw_ice() -> void:
	var s := 21.5 * _pop_scale
	var c := 6.5 * _pop_scale
	var cube := PackedVector2Array([
		Vector2(-s + c, -s), Vector2(s - c, -s),
		Vector2(s, -s + c), Vector2(s, s - c),
		Vector2(s - c, s), Vector2(-s + c, s),
		Vector2(-s, s - c), Vector2(-s, -s + c),
	])
	var shadow := PackedVector2Array()
	for pt in cube:
		shadow.append(pt + Vector2(3.5, 6.0))

	# Frosty outer aura + drop shadow
	draw_circle(Vector2.ZERO, 29.0 * _pop_scale, Color(0.72, 0.94, 1.0, 0.18))
	draw_colored_polygon(shadow, Color(0.08, 0.22, 0.36, 0.24))
	draw_colored_polygon(cube, Color(0.68, 0.92, 1.0, 0.94))

	# Inner refractive cube core
	var inner := PackedVector2Array()
	for pt in cube:
		inner.append(pt * 0.72)
	draw_colored_polygon(inner, Color(0.84, 0.97, 1.0, 0.55))

	# Animated diagonal crystalline sheen sweep
	var sweep := fmod(_time * 1.1, 2.4) - 0.7
	if sweep >= -0.6 and sweep <= 0.6:
		var sx := sweep * s * 1.4
		draw_line(
			Vector2(clampf(sx - 9.0, -s + 3, s - 3), -s + 4),
			Vector2(clampf(sx + 9.0, -s + 3, s - 3), s - 4),
			Color(1.0, 1.0, 1.0, 0.55),
			5.0,
			true
		)

	# Upper bright ice facet & lower cool facet
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s + c, -s), Vector2(s * 0.45, -s),
		Vector2(-s, s * 0.45), Vector2(-s, -s + c),
	]), Color(1.0, 1.0, 1.0, 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2(s, -s * 0.1), Vector2(s, s - c),
		Vector2(s - c, s), Vector2(-s * 0.25, s),
	]), Color(0.38, 0.76, 0.95, 0.45))

	# Crisp icy rim
	var border := cube.duplicate()
	border.append(cube[0])
	draw_polyline(border, Color(0.28, 0.64, 0.86, 0.96), 2.8, true)

	_draw_face(Vector2(0, 1.0), Color(0.08, 0.26, 0.40), true, false)


func _draw_steam() -> void:
	var pulse := 1.0 + sin(_time * 4.5) * 0.055
	var sc := _pop_scale * pulse
	var puffs := [
		[Vector2(-14, 3), 14.5],
		[Vector2(14, 3), 14.5],
		[Vector2(-8, -9), 15.5],
		[Vector2(8, -8), 14.5],
		[Vector2(0, 5), 16.0],
	]
	# Soft outer mist glow
	draw_circle(Vector2.ZERO, 33.0 * sc, Color(1.0, 0.99, 0.96, 0.16))
	# Soft drop shadow
	for pf in puffs:
		draw_circle((pf[0] as Vector2) * sc + Vector2(2.5, 5.0), float(pf[1]) * sc, Color(0.42, 0.56, 0.62, 0.15))
	# Warm cream-tinted cloud base
	for pf in puffs:
		draw_circle((pf[0] as Vector2) * sc, float(pf[1]) * sc, Color(0.94, 0.97, 0.99, 0.90))
	# Sunlit pure white top highlights
	for pf in [[Vector2(-8, -11), 11.0], [Vector2(7, -10), 10.0], [Vector2(0, -2), 14.5]]:
		draw_circle((pf[0] as Vector2) * sc, float(pf[1]) * sc, Color(1.0, 1.0, 1.0, 0.92))

	_draw_face(Vector2(0, 1.0), Color(0.26, 0.40, 0.48), false, true)


func _draw_face(offset: Vector2, ink: Color, determined: bool, sleepy: bool) -> void:
	var look := linear_velocity.limit_length(220.0) / 220.0 * 2.4
	if state == State.ICE:
		look = look.rotated(-rotation)
	var left_eye := offset + Vector2(-6.5, -1.5) + look
	var right_eye := offset + Vector2(6.5, -1.5) + look

	draw_circle(offset + Vector2(-10.8, 3.6), 3.3, Color(1.0, 0.56, 0.62, 0.48))
	draw_circle(offset + Vector2(10.8, 3.6), 3.3, Color(1.0, 0.56, 0.62, 0.48))

	if sleepy:
		draw_arc(left_eye + Vector2(0, 1.5), 3.7, PI + 0.35, TAU - 0.35, 8, ink, 2.1, true)
		draw_arc(right_eye + Vector2(0, 1.5), 3.7, PI + 0.35, TAU - 0.35, 8, ink, 2.1, true)
		draw_arc(offset + Vector2(0, 3.5), 3.4, 0.2, PI - 0.2, 8, ink, 1.9, true)
		return

	if _blinking:
		draw_line(left_eye + Vector2(-3.2, 0), left_eye + Vector2(3.2, 0), ink, 2.1, true)
		draw_line(right_eye + Vector2(-3.2, 0), right_eye + Vector2(3.2, 0), ink, 2.1, true)
	else:
		draw_circle(left_eye, 3.0, ink)
		draw_circle(right_eye, 3.0, ink)
		draw_circle(left_eye + Vector2(-1.0, -1.0), 1.1, Color.WHITE)
		draw_circle(right_eye + Vector2(-1.0, -1.0), 1.1, Color.WHITE)

	if determined:
		draw_line(left_eye + Vector2(-3.6, -4.6), left_eye + Vector2(2.8, -2.5), ink, 1.9, true)
		draw_line(right_eye + Vector2(3.6, -4.6), right_eye + Vector2(-2.8, -2.5), ink, 1.9, true)
		draw_line(offset + Vector2(-3.2, 5.2), offset + Vector2(3.2, 5.2), ink, 1.9, true)
	else:
		draw_arc(offset + Vector2(0, 3.2), 4.0, 0.22, PI - 0.22, 10, ink, 2.0, true)
