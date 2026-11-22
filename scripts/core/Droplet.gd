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
var _particles: Array[Dictionary] = []  # global-space
var _rings: Array[Dictionary] = []      # global-space
var _trail_timer: float = 0.0
var _ice_sparkle_timer: float = 0.0
var _blink_timer: float = 2.4
var _blinking: bool = false
var _art := DropletArt.new()
var _drawn_state: int = -1
var _end_anim: String = ""
var _end_t: float = 0.0
var _end_target: Vector2 = Vector2.ZERO
var _hidden_for_intro: bool = false
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
	_art.state = int(state)
	_art.prev_state = int(state)
	_drawn_state = int(state)
	_art.time = randf() * 10.0
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


## Hide until the level intro "drips" the droplet out of its spout.
func hold_for_intro() -> void:
	_hidden_for_intro = true
	freeze = true


func release_from_intro() -> void:
	_hidden_for_intro = false
	freeze = false
	_pop_scale = 0.2
	_squish = -0.35
	_spawn_state_burst(Art.state_color(int(state)).lightened(0.3), 8)


func is_held_for_intro() -> bool:
	return _hidden_for_intro


## End-of-level animations. kind: "absorb" (win), "drain", "sizzle", "evaporated".
func play_end_anim(kind: String, target_global: Vector2 = Vector2.ZERO) -> void:
	_end_anim = kind
	_end_t = 0.0
	_end_target = target_global
	match kind:
		"sizzle", "evaporated":
			for i in range(10):
				var ang := randf_range(-PI, 0.0)
				_particles.append(_make_particle(global_position + Vector2(randf_range(-12, 12), randf_range(-6, 8)),
					Vector2.from_angle(ang) * randf_range(30, 90) + Vector2(0, -60), randf_range(0.6, 1.0), randf_range(7, 13),
					Color(1, 1, 1, 0.75), "puff"))
		"absorb":
			_spawn_state_burst(Color(0.45, 0.86, 1.0), 10)


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
			_spawn_state_burst(Color(0.45, 0.88, 1.0, 0.85), 5, false)
		elif state == State.ICE and speed > 180.0:
			_spawn_state_burst(Color(0.86, 0.97, 1.0, 0.9), 5, false)


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


func _make_particle(pos: Vector2, vel: Vector2, life: float, radius: float, color: Color, kind: String = "dot", grav: float = 0.0) -> Dictionary:
	return {"pos": pos, "vel": vel, "life": life, "max_life": life, "radius": radius, "color": color, "kind": kind, "grav": grav}


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

	if _end_anim != "":
		_end_t += delta

	var gp := global_position
	if active and not soaked and not _hidden_for_intro:
		var spd := linear_velocity.length()
		if state == State.STEAM:
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = 0.08
				_particles.append(_make_particle(gp + Vector2(randf_range(-13, 13), randf_range(6, 16)),
					Vector2(randf_range(-14, 14), randf_range(-18, -4)) - linear_velocity * 0.15,
					0.7, randf_range(5.0, 9.5), Color(1, 1, 1, 0.5), "puff"))
		elif state == State.WATER and spd > 150.0:
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = 0.05
				var back := -linear_velocity.normalized()
				_particles.append(_make_particle(gp + back * 16.0 + Vector2(randf_range(-5, 5), randf_range(-5, 5)),
					back * 40.0 + Vector2(randf_range(-20, 20), randf_range(-30, 0)),
					0.42, randf_range(2.4, 4.4), Color(0.40, 0.84, 1.0, 0.85), "drop", 420.0))
		elif state == State.ICE:
			_ice_sparkle_timer -= delta
			if _ice_sparkle_timer <= 0.0:
				_ice_sparkle_timer = 0.16 if spd < 200.0 else 0.07
				_particles.append(_make_particle(gp + Vector2(randf_range(-22, 22), randf_range(-22, 22)),
					Vector2(randf_range(-10, 10), randf_range(-18, 6)),
					0.5, randf_range(3.0, 5.5), Color(1.0, 1.0, 1.0, 0.95), "spark"))

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		else:
			var v: Vector2 = p["vel"]
			v.y += float(p["grav"]) * delta
			p["vel"] = v
			p["pos"] = (p["pos"] as Vector2) + v * delta

	for i in range(_rings.size() - 1, -1, -1):
		var rg: Dictionary = _rings[i]
		rg["life"] = float(rg["life"]) - delta
		if float(rg["life"]) <= 0.0:
			_rings.remove_at(i)
		else:
			var prog := 1.0 - float(rg["life"]) / float(rg["max_life"])
			rg["r"] = lerpf(12.0, float(rg["max_r"]), 1.0 - pow(1.0 - prog, 2.0))

	# Feed the renderer
	if int(state) != _drawn_state:
		_art.start_morph(_drawn_state, int(state))
		_drawn_state = int(state)
	_art.advance(delta)
	_art.squish = _squish
	_art.pop = _pop_scale
	_art.blink = _blinking
	_art.velocity = linear_velocity.rotated(-rotation) if active else Vector2.ZERO
	_art.mood = ""
	_art.alpha = 1.0
	match _end_anim:
		"absorb":
			_art.mood = "joy"
			var t := clampf(_end_t / 0.42, 0.0, 1.0)
			_art.pop = _pop_scale * (1.0 - t * t)
		"drain":
			_art.mood = "scared"
			var t := clampf(_end_t / 0.5, 0.0, 1.0)
			_art.pop = _pop_scale * (1.0 - t)
		"sizzle", "evaporated":
			_art.mood = "wince"
			var t := clampf(_end_t / 0.45, 0.0, 1.0)
			_art.alpha = 1.0 - t
			_art.pop = _pop_scale * (1.0 + t * 0.4)
		"fell":
			_art.mood = "scared"
	queue_redraw()


func _spawn_state_burst(base_color: Color, count: int, ring: bool = true) -> void:
	var gp := global_position
	for i in range(count):
		var angle := (TAU * float(i) / float(count)) + randf_range(-0.28, 0.28)
		var spd := randf_range(60.0, 140.0)
		var kind := "spark" if state == State.ICE else ("puff" if state == State.STEAM else "drop")
		_particles.append(_make_particle(gp + Vector2.from_angle(angle) * 12.0, Vector2.from_angle(angle) * spd,
			randf_range(0.30, 0.50), randf_range(3.0, 6.0), base_color, kind, 160.0 if kind == "drop" else 0.0))
	if ring:
		_rings.append({"pos": gp, "r": 12.0, "max_r": 56.0, "life": 0.32, "max_life": 0.32, "col": base_color})


func _draw() -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for rg in _rings:
		var a: float = clampf(float(rg["life"]) / float(rg["max_life"]), 0.0, 1.0)
		var col: Color = rg["col"]
		col.a = a * 0.6
		draw_arc(rg["pos"], float(rg["r"]), 0.0, TAU, 32, col, 3.0 * a + 0.5, true)
	for p in _particles:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= alpha
		var r: float = float(p["radius"]) * (0.45 + 0.55 * alpha)
		var pos: Vector2 = p["pos"]
		match String(p["kind"]):
			"spark":
				Art.draw_sparkle(self, pos, r * 1.3, col)
			"puff":
				draw_circle(pos, r * (1.6 - 0.6 * alpha), Color(col.r, col.g, col.b, col.a * 0.8))
			"drop":
				Art.draw_ellipse(self, pos, r * 0.85, r * 1.15, col, 12)
				draw_circle(pos + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 1, 1, col.a * 0.8))
			_:
				draw_circle(pos, r, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	if soaked or _hidden_for_intro:
		return
	var origin := Vector2.ZERO
	if _end_anim == "absorb":
		origin = to_local(_end_target) * clampf(_end_t / 0.42, 0.0, 1.0)
	elif _end_anim == "drain":
		origin = Vector2(0, clampf(_end_t / 0.5, 0.0, 1.0) * 14.0)
	elif _end_anim in ["sizzle", "evaporated"]:
		origin = Vector2(0, -clampf(_end_t / 0.45, 0.0, 1.0) * 26.0)
	_art.draw(self, origin)
