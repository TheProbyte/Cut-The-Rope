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

var _heat_zones: int = 0
var _freezer_zones: int = 0
var _time: float = 0.0
var _squish: float = 0.0
var _squish_vel: float = 0.0
var _pop_scale: float = 1.0
var _particles: Array[Dictionary] = []
var _steam_trail_timer: float = 0.0
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
	if not active:
		return false
	if _heat_zones > 0:
		# Held in steam by heat lamp; subtle feedback
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
				_spawn_state_burst(Color(0.32, 0.78, 0.98), 8)
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
				_spawn_state_burst(Color(0.76, 0.94, 1.0), 10)
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
			# Dampen strong downward velocity slightly so steam floats gently
			if linear_velocity.y > 140.0:
				linear_velocity.y *= 0.45
			if not silent and changed:
				AudioManager.play_sfx("steam")
				_spawn_state_burst(Color(0.96, 0.98, 1.0), 9)

	if not silent:
		_pop_scale = 1.32
		_squish = 0.24
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


func enter_heat_zone() -> void:
	_heat_zones += 1
	if active and state != State.STEAM:
		set_state(State.STEAM, true, false)


func exit_heat_zone() -> void:
	_heat_zones = maxi(0, _heat_zones - 1)


func enter_freezer_zone() -> void:
	_freezer_zones += 1
	if active and state != State.ICE:
		set_state(State.ICE, true, false)


func exit_freezer_zone() -> void:
	_freezer_zones = maxi(0, _freezer_zones - 1)


func condense_to_water() -> void:
	if not active or state != State.STEAM:
		return
	if _heat_zones > 0:
		return
	linear_velocity.y = maxf(linear_velocity.y, 45.0)
	linear_velocity.x *= 0.35
	AudioManager.play_sfx("condense")
	set_state(State.WATER, true, true)
	_pop_scale = 1.28
	_spawn_state_burst(Color(0.45, 0.85, 1.0), 8)
	state_changed.emit(int(state), true)


func apply_wind_force(wind_vector: Vector2) -> void:
	if not active:
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
	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _on_body_entered(_body: Node) -> void:
	if not active:
		return
	var speed := linear_velocity.length()
	if speed > 90.0:
		_squish = clampf(speed / 550.0, 0.08, 0.32)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if _heat_zones > 0 and state != State.STEAM:
		set_state(State.STEAM, true, false)
	elif _freezer_zones > 0 and state != State.ICE:
		set_state(State.ICE, true, false)

	if state != State.ICE and absf(rotation) > 0.001:
		rotation = lerpf(rotation, 0.0, delta * 14.0)

	# Keep steam speed gentle & controllable
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

	# Spring squish & pop animation
	_pop_scale = lerpf(_pop_scale, 1.0, clampf(delta * 10.0, 0.0, 1.0))
	var spring_acc := -120.0 * _squish - 12.0 * _squish_vel
	_squish_vel += spring_acc * delta
	_squish += _squish_vel * delta

	# Blinking eyes
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		if _blinking:
			_blinking = false
			_blink_timer = randf_range(2.2, 4.4)
		else:
			_blinking = true
			_blink_timer = 0.13

	# Ambient particles
	if active and state == State.STEAM:
		_steam_trail_timer -= delta
		if _steam_trail_timer <= 0.0:
			_steam_trail_timer = 0.11
			_particles.append({
				"pos": Vector2(randf_range(-12, 12), randf_range(4, 14)),
				"vel": Vector2(randf_range(-16, 16), randf_range(-24, -8)),
				"life": 0.55,
				"max_life": 0.55,
				"radius": randf_range(5.0, 9.0),
				"color": Color(0.97, 0.99, 1.0, 0.65),
			})
	elif active and state == State.ICE:
		_ice_sparkle_timer -= delta
		if _ice_sparkle_timer <= 0.0:
			_ice_sparkle_timer = 0.24
			_particles.append({
				"pos": Vector2(randf_range(-18, 18), randf_range(-18, 18)),
				"vel": Vector2(randf_range(-12, 12), randf_range(-18, 8)),
				"life": 0.4,
				"max_life": 0.4,
				"radius": randf_range(2.2, 3.8),
				"color": Color(0.88, 0.98, 1.0, 0.95),
			})

	# Update local particles
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		else:
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta

	queue_redraw()


func _spawn_state_burst(base_color: Color, count: int) -> void:
	for i in range(count):
		var angle := (TAU * float(i) / float(count)) + randf_range(-0.25, 0.25)
		var spd := randf_range(45.0, 115.0)
		_particles.append({
			"pos": Vector2.from_angle(angle) * 10.0,
			"vel": Vector2.from_angle(angle) * spd,
			"life": randf_range(0.28, 0.48),
			"max_life": 0.48,
			"radius": randf_range(3.5, 6.5),
			"color": base_color,
		})


func _draw() -> void:
	# Draw ambient & burst particles behind/around droplet
	for p in _particles:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= alpha
		draw_circle(p["pos"], float(p["radius"]) * (0.5 + 0.5 * alpha), col)

	match state:
		State.WATER:
			_draw_water()
		State.ICE:
			_draw_ice()
		State.STEAM:
			_draw_steam()


func _draw_water() -> void:
	var wobble_x := sin(_time * 6.5) * 0.045 + _squish * 0.6
	var wobble_y := -wobble_x
	var vel_stretch := clampf(linear_velocity.length() / 900.0, 0.0, 0.14)
	var sx := _pop_scale * (1.0 + wobble_x - vel_stretch * 0.35)
	var sy := _pop_scale * (1.0 + wobble_y + vel_stretch * 0.45)

	var pts := PackedVector2Array()
	var shadow_pts := PackedVector2Array()
	var steps := 28
	var r := 21.5
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		var ca := cos(a)
		var sa := sin(a)
		# Gentle teardrop taper on top
		var top_taper := 1.0 - maxf(0.0, -sa) * 0.16
		var top_lift := maxf(0.0, -sa) * 4.5
		var px := ca * r * top_taper * sx
		var py := (sa * r - top_lift) * sy
		pts.append(Vector2(px, py))
		shadow_pts.append(Vector2(px + 3.0, py + 5.0))

	# Soft drop shadow
	draw_colored_polygon(shadow_pts, Color(0.08, 0.24, 0.34, 0.20))
	# Outer body
	draw_colored_polygon(pts, Color(0.16, 0.67, 0.92, 0.94))
	# Inner luminous core
	var inner_pts := PackedVector2Array()
	for pt in pts:
		inner_pts.append(pt * 0.80 + Vector2(-1.5, -2.5))
	draw_colored_polygon(inner_pts, Color(0.42, 0.86, 1.0, 0.58))
	# Soft outline
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.10, 0.46, 0.72, 0.85), 2.2, true)
	# Gloss highlight
	draw_circle(Vector2(-7.0 * sx, -8.5 * sy), 4.6 * _pop_scale, Color(1.0, 1.0, 1.0, 0.68))
	draw_circle(Vector2(-3.0 * sx, -13.5 * sy), 2.0 * _pop_scale, Color(1.0, 1.0, 1.0, 0.52))

	_draw_face(Vector2(0, 2.0), Color(0.07, 0.22, 0.34), false, false)


func _draw_ice() -> void:
	var s := 21.0 * _pop_scale
	var c := 6.0 * _pop_scale
	var cube := PackedVector2Array([
		Vector2(-s + c, -s), Vector2(s - c, -s),
		Vector2(s, -s + c), Vector2(s, s - c),
		Vector2(s - c, s), Vector2(-s + c, s),
		Vector2(-s, s - c), Vector2(-s, -s + c),
	])
	var shadow := PackedVector2Array()
	for pt in cube:
		shadow.append(pt + Vector2(3.0, 5.0))

	draw_colored_polygon(shadow, Color(0.08, 0.24, 0.36, 0.22))
	draw_colored_polygon(cube, Color(0.70, 0.93, 1.0, 0.93))

	# Facet sheen diagonal
	var facet := PackedVector2Array([
		Vector2(-s + c, -s), Vector2(s * 0.35, -s),
		Vector2(-s, s * 0.35), Vector2(-s, -s + c),
	])
	draw_colored_polygon(facet, Color(1.0, 1.0, 1.0, 0.48))

	# Lower cool facet
	var low_facet := PackedVector2Array([
		Vector2(s, -s * 0.1), Vector2(s, s - c),
		Vector2(s - c, s), Vector2(-s * 0.2, s),
	])
	draw_colored_polygon(low_facet, Color(0.45, 0.80, 0.96, 0.45))

	# Crisp crystalline border
	var border := cube.duplicate()
	border.append(cube[0])
	draw_polyline(border, Color(0.32, 0.68, 0.88, 0.95), 2.6, true)

	# Tiny internal frost glints
	draw_line(Vector2(-10, -8), Vector2(-4, -14), Color(1, 1, 1, 0.75), 2.0, true)
	draw_line(Vector2(6, 11), Vector2(13, 5), Color(1, 1, 1, 0.65), 1.8, true)

	_draw_face(Vector2(0, 1.0), Color(0.09, 0.28, 0.42), true, false)


func _draw_steam() -> void:
	var pulse := 1.0 + sin(_time * 4.5) * 0.05
	var sc := _pop_scale * pulse
	var puffs := [
		[Vector2(-13, 3), 13.5],
		[Vector2(13, 3), 13.5],
		[Vector2(-7, -8), 14.5],
		[Vector2(8, -7), 13.5],
		[Vector2(0, 5), 15.0],
	]
	# Soft shadow
	for pf in puffs:
		draw_circle((pf[0] as Vector2) * sc + Vector2(2.5, 4.5), float(pf[1]) * sc, Color(0.42, 0.56, 0.62, 0.14))
	# Fluffy outer cloud
	for pf in puffs:
		draw_circle((pf[0] as Vector2) * sc, float(pf[1]) * sc, Color(0.95, 0.98, 1.0, 0.90))
	# Warm bright center
	draw_circle(Vector2(0, -1) * sc, 15.0 * sc, Color(1.0, 1.0, 1.0, 0.92))

	_draw_face(Vector2(0, 1.0), Color(0.26, 0.40, 0.48), false, true)


func _draw_face(offset: Vector2, ink: Color, determined: bool, sleepy: bool) -> void:
	var look := linear_velocity.limit_length(220.0) / 220.0 * 2.2
	if state == State.ICE:
		look = look.rotated(-rotation)
	var left_eye := offset + Vector2(-6.5, -1.5) + look
	var right_eye := offset + Vector2(6.5, -1.5) + look

	# Rosy cheeks
	draw_circle(offset + Vector2(-10.5, 3.5), 3.0, Color(1.0, 0.58, 0.62, 0.45))
	draw_circle(offset + Vector2(10.5, 3.5), 3.0, Color(1.0, 0.58, 0.62, 0.45))

	if sleepy:
		# Happy floating curved eyes ^ ^
		draw_arc(left_eye + Vector2(0, 1.5), 3.6, PI + 0.35, TAU - 0.35, 8, ink, 2.0, true)
		draw_arc(right_eye + Vector2(0, 1.5), 3.6, PI + 0.35, TAU - 0.35, 8, ink, 2.0, true)
		draw_arc(offset + Vector2(0, 3.5), 3.2, 0.2, PI - 0.2, 8, ink, 1.8, true)
		return

	if _blinking:
		draw_line(left_eye + Vector2(-3, 0), left_eye + Vector2(3, 0), ink, 2.0, true)
		draw_line(right_eye + Vector2(-3, 0), right_eye + Vector2(3, 0), ink, 2.0, true)
	else:
		draw_circle(left_eye, 2.8, ink)
		draw_circle(right_eye, 2.8, ink)
		draw_circle(left_eye + Vector2(-0.9, -0.9), 1.0, Color.WHITE)
		draw_circle(right_eye + Vector2(-0.9, -0.9), 1.0, Color.WHITE)

	if determined:
		# Cute resolute eyebrows for Ice
		draw_line(left_eye + Vector2(-3.5, -4.5), left_eye + Vector2(2.8, -2.5), ink, 1.8, true)
		draw_line(right_eye + Vector2(3.5, -4.5), right_eye + Vector2(-2.8, -2.5), ink, 1.8, true)
		draw_line(offset + Vector2(-3.0, 5.0), offset + Vector2(3.0, 5.0), ink, 1.8, true)
	else:
		draw_arc(offset + Vector2(0, 3.2), 3.8, 0.25, PI - 0.25, 10, ink, 1.9, true)
