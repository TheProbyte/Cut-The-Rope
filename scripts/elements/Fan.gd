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
	var half_w := wind_width * 0.5
	var x0 := 24.0
	var x1 := 24.0 + wind_range
	var on_t := clampf(_blade_speed / 15.0, 0.0, 1.0)
	# wind tunnel
	if on_t > 0.02:
		draw_polygon(PackedVector2Array([Vector2(x0, -half_w), Vector2(x1, -half_w), Vector2(x1, half_w), Vector2(x0, half_w)]),
			PackedColorArray([Color(0.84, 0.97, 1.0, 0.22 * on_t), Color(0.84, 0.97, 1.0, 0.0), Color(0.84, 0.97, 1.0, 0.0), Color(0.84, 0.97, 1.0, 0.22 * on_t)]))
		for row in range(4):
			var y := lerpf(-half_w * 0.7, half_w * 0.7, float(row) / 3.0)
			for rep in range(2):
				var head := x0 + fmod(_time * 230.0 + float(row) * 77.0 + float(rep) * wind_range * 0.5, wind_range)
				var seg := 60.0
				var pts := PackedVector2Array()
				for i in range(7):
					var px := head - seg + seg * float(i) / 6.0
					if px < x0:
						continue
					pts.append(Vector2(px, y + sin(px * 0.045 + _time * 6.0 + float(row)) * 5.0))
				if pts.size() >= 2:
					var fade := 1.0 - (head - x0) / wind_range
					draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.75 * fade * on_t), 2.6, true)
					draw_circle(pts[pts.size() - 1], 2.0, Color(1, 1, 1, 0.8 * fade * on_t))
	if on_t < 0.98:
		var off_a := 1.0 - on_t
		var dx := x0 + 10.0
		while dx < x1 - 12.0:
			draw_line(Vector2(dx, -half_w), Vector2(minf(dx + 12.0, x1), -half_w), Color(0.40, 0.54, 0.50, 0.32 * off_a), 2.0, true)
			draw_line(Vector2(dx, half_w), Vector2(minf(dx + 12.0, x1), half_w), Color(0.40, 0.54, 0.50, 0.32 * off_a), 2.0, true)
			dx += 24.0
		# direction preview chevrons
		for i in range(3):
			var cx := x0 + 36.0 + float(i) * 22.0
			draw_polyline(PackedVector2Array([Vector2(cx - 6, -9), Vector2(cx + 3, 0), Vector2(cx - 6, 9)]), Color(0.40, 0.54, 0.50, 0.38 * off_a), 3.0, true)

	# tap ring
	var ring_col := Color(0.32, 0.82, 0.62, 0.55) if is_on else Color(1.0, 1.0, 1.0, 0.65)
	var ring_r := (36.0 + sin(_time * 3.2) * 2.5) * _pop
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 36, ring_col, 3.0, true)

	var p := _pop
	Art.draw_ellipse(self, Vector2(3.0, 6.0).rotated(-rotation), 28.0 * p, 28.0 * p, Color(0.10, 0.18, 0.14, 0.20))
	# nozzle
	var nozzle := PackedVector2Array([Vector2(6, -22) * p, Vector2(30, -31) * p, Vector2(30, 31) * p, Vector2(6, 22) * p])
	draw_polygon(nozzle, Art.vgrad_colors(nozzle, Color(0.62, 0.72, 0.70), Color(0.36, 0.46, 0.44)))
	draw_polyline(Art.closed(nozzle), Color(0.20, 0.30, 0.28), 2.2, true)
	# housing
	var housing := Color(0.30, 0.70, 0.58) if is_on else Color(0.58, 0.64, 0.62)
	var hpts := Art.ellipse_points(Vector2.ZERO, 27.0 * p, 27.0 * p, 32)
	draw_polygon(hpts, Art.vgrad_colors(hpts, housing.lightened(0.18), housing.darkened(0.15)))
	draw_circle(Vector2.ZERO, 20.5 * p, Color(0.90, 0.96, 0.94))
	if on_t > 0.5:
		draw_circle(Vector2.ZERO, 18.0 * p, Color(0.62, 0.80, 0.76, 0.35 * on_t))
	for i in range(4):
		var a := _blade_angle + float(i) * (PI * 0.5)
		var tip := Vector2.from_angle(a) * (17.0 * p)
		var perp := Vector2.from_angle(a + PI * 0.5) * (5.5 * p)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, tip * 0.5 + perp, tip, tip * 0.55 - perp * 0.4]),
			Color(0.24, 0.54, 0.50, 1.0 - on_t * 0.5) if is_on else Color(0.50, 0.56, 0.54))
	draw_circle(Vector2.ZERO, 7.0 * p, Color(0.86, 0.70, 0.38))
	draw_circle(Vector2(-1.5, -1.5) * p, 2.4 * p, Color(1.0, 0.92, 0.70))
	draw_polyline(Art.closed(hpts), Color(0.18, 0.30, 0.26), 2.4, true)
	# status LED
	var led := Vector2(-16.0, -16.0) * p
	draw_circle(led, 4.2 * p, Color(0.20, 0.26, 0.24))
	draw_circle(led, 3.0 * p, Color(0.42, 0.98, 0.62) if is_on else Color(0.96, 0.44, 0.38))
	if is_on:
		Art.draw_glow(self, led, 10.0, Color(0.42, 0.98, 0.62, 0.6))
