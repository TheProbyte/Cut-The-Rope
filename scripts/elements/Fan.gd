class_name Fan
extends Node2D

const TAP_RADIUS := 54.0

var is_on: bool = false
var wind_dir: Vector2 = Vector2.RIGHT
var wind_range: float = 280.0
var wind_width: float = 92.0
var wind_strength: float = 460.0

var _wind_area: Area2D
var _droplets_in_wind: Array[Droplet] = []
var _blade_angle: float = 0.0
var _blade_speed: float = 0.0
var _pop: float = 1.0
var _time: float = 0.0


func configure(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("pos", [200, 500])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	is_on = bool(cfg.get("initially_on", false))
	wind_range = float(cfg.get("range", 280.0))
	wind_width = float(cfg.get("width", 92.0))
	wind_strength = float(cfg.get("strength", 460.0))

	var dir_val: Variant = cfg.get("direction", "right")
	if typeof(dir_val) == TYPE_STRING:
		match String(dir_val).to_lower():
			"right":
				wind_dir = Vector2.RIGHT
			"left":
				wind_dir = Vector2.LEFT
			"up":
				wind_dir = Vector2.UP
			"down":
				wind_dir = Vector2.DOWN
			_:
				wind_dir = Vector2.RIGHT
	else:
		wind_dir = Vector2.from_angle(deg_to_rad(float(dir_val)))
	rotation = wind_dir.angle()
	_blade_speed = 14.0 if is_on else 0.0

	_wind_area = Area2D.new()
	_wind_area.collision_layer = 16
	_wind_area.collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(wind_range, wind_width)
	shape.shape = rect
	shape.position = Vector2(24.0 + wind_range * 0.5, 0.0)
	_wind_area.add_child(shape)
	add_child(_wind_area)

	_wind_area.body_entered.connect(_on_body_entered)
	_wind_area.body_exited.connect(_on_body_exited)
	queue_redraw()


func contains_point(global_pt: Vector2) -> bool:
	return global_position.distance_to(global_pt) <= TAP_RADIUS


func toggle() -> void:
	is_on = not is_on
	_pop = 1.24
	AudioManager.play_sfx("fan_toggle", 1.08 if is_on else 0.88)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Droplet and not _droplets_in_wind.has(body):
		_droplets_in_wind.append(body as Droplet)


func _on_body_exited(body: Node) -> void:
	if body is Droplet:
		_droplets_in_wind.erase(body as Droplet)


func _physics_process(_delta: float) -> void:
	if not is_on:
		return
	var force_vec := wind_dir.normalized() * wind_strength
	for d in _droplets_in_wind:
		if is_instance_valid(d) and d.active:
			d.apply_wind_force(force_vec)


func _process(delta: float) -> void:
	_time += delta
	_pop = lerpf(_pop, 1.0, clampf(delta * 10.0, 0.0, 1.0))
	var target_speed := 15.0 if is_on else 0.0
	_blade_speed = lerpf(_blade_speed, target_speed, clampf(delta * 5.0, 0.0, 1.0))
	_blade_angle += _blade_speed * delta
	queue_redraw()


func _draw() -> void:
	# Wind tunnel visuals
	var half_w := wind_width * 0.5
	var tunnel := Rect2(24.0, -half_w, wind_range, wind_width)
	if is_on:
		draw_rect(tunnel, Color(0.84, 0.97, 1.0, 0.14))
		# Flowing animated wind ribbons
		for row in range(3):
			var y := lerpf(-half_w * 0.62, half_w * 0.62, float(row) / 2.0)
			var phase := fmod(_time * 210.0 + float(row) * 95.0, wind_range)
			var seg_len := 52.0
			for rep in range(2):
				var sx := 28.0 + fmod(phase + float(rep) * (wind_range * 0.5), wind_range)
				var ex := minf(24.0 + wind_range - 6.0, sx + seg_len)
				if ex > sx + 8.0:
					var fade := 1.0 - ((sx - 24.0) / wind_range) * 0.55
					var wave := sin(_time * 7.0 + float(row) * 2.1) * 4.0
					draw_line(
						Vector2(sx, y + wave),
						Vector2(ex, y - wave),
						Color(0.92, 0.99, 1.0, 0.65 * fade),
						2.6,
						true
					)
	else:
		# Subtle dotted outline so player can preview fan direction even when OFF
		draw_rect(tunnel, Color(0.55, 0.68, 0.66, 0.06))
		var dx := 34.0
		while dx < 24.0 + wind_range - 12.0:
			draw_line(Vector2(dx, -half_w), Vector2(minf(dx + 12.0, 24.0 + wind_range), -half_w), Color(0.45, 0.58, 0.54, 0.28), 1.6)
			draw_line(Vector2(dx, half_w), Vector2(minf(dx + 12.0, 24.0 + wind_range), half_w), Color(0.45, 0.58, 0.54, 0.28), 1.6)
			dx += 24.0

	# Tactile tap indicator ring around fan housing
	var ring_col := Color(0.32, 0.80, 0.68, 0.45) if is_on else Color(0.55, 0.62, 0.58, 0.32)
	var ring_r := (34.0 + sin(_time * 3.5) * 2.0) * _pop
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, ring_col, 2.5, true)

	# Fan shadow
	draw_circle(Vector2(3.0, 4.0), 27.0 * _pop, Color(0.10, 0.18, 0.14, 0.20))

	# Nozzle cone pointing right (local +X)
	var nozzle := PackedVector2Array([
		Vector2(6.0, -24.0) * _pop,
		Vector2(28.0, -30.0) * _pop,
		Vector2(28.0, 30.0) * _pop,
		Vector2(6.0, 24.0) * _pop,
	])
	draw_colored_polygon(nozzle, Color(0.44, 0.54, 0.52))
	draw_polyline(nozzle, Color(0.24, 0.34, 0.32), 2.0, true)

	# Circular brass/sage housing
	var housing_col := Color(0.30, 0.66, 0.58) if is_on else Color(0.56, 0.60, 0.58)
	draw_circle(Vector2.ZERO, 26.0 * _pop, housing_col)
	draw_circle(Vector2.ZERO, 20.0 * _pop, Color(0.88, 0.95, 0.92))

	# Spinning blades inside housing
	for i in range(4):
		var a := _blade_angle + float(i) * (PI * 0.5)
		var tip := Vector2.from_angle(a) * (16.5 * _pop)
		var perp := Vector2.from_angle(a + PI * 0.5) * (4.5 * _pop)
		draw_colored_polygon(PackedVector2Array([
			Vector2.ZERO,
			tip * 0.55 + perp,
			tip,
			tip * 0.55 - perp,
		]), Color(0.28, 0.56, 0.52) if is_on else Color(0.52, 0.58, 0.56))

	# Center brass hub & status dot
	draw_circle(Vector2.ZERO, 7.0 * _pop, Color(0.82, 0.66, 0.34))
	draw_circle(Vector2.ZERO, 3.6 * _pop, Color(0.42, 0.96, 0.62) if is_on else Color(0.84, 0.42, 0.38))
	draw_arc(Vector2.ZERO, 26.0 * _pop, 0.0, TAU, 28, Color(0.22, 0.34, 0.30), 2.4, true)
