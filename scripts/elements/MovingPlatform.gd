class_name MovingPlatform
extends Node2D

var point_a: Vector2 = Vector2(200, 600)
var point_b: Vector2 = Vector2(520, 600)
var length: float = 144.0
var thickness: float = 20.0
var cycle_speed: float = 0.30
var phase: float = 0.0
var theme_name: String = "kitchen"

var _body: AnimatableBody2D
var _carry_area: Area2D
var _visual: Node2D
var _time: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _riders: Array[Droplet] = []


class TrayVisual extends Node2D:
	var length: float = 144.0
	var thickness: float = 20.0
	var theme_name: String = "kitchen"

	func _draw() -> void:
		var half := Vector2(length * 0.5, thickness * 0.5)
		var rect := Rect2(-half, Vector2(length, thickness))
		draw_rect(Rect2(-half + Vector2(3, 6), Vector2(length, thickness)), Color(0.12, 0.16, 0.12, 0.20))

		var base := Color(0.84, 0.62, 0.36) if theme_name == "kitchen" else Color(0.68, 0.52, 0.32)
		draw_rect(rect, base)
		draw_rect(Rect2(-half, Vector2(length, thickness * 0.36)), Color(0.96, 0.82, 0.58, 0.72))
		draw_rect(Rect2(-half.x, half.y - thickness * 0.25, length, thickness * 0.25), Color(0.56, 0.38, 0.18, 0.55))
		draw_rect(rect, Color(0.44, 0.28, 0.14), false, 2.4)

		draw_circle(Vector2(-half.x + 16.0, 0.0), 4.5, Color(0.86, 0.66, 0.34))
		draw_circle(Vector2(half.x - 16.0, 0.0), 4.5, Color(0.86, 0.66, 0.34))
		draw_circle(Vector2(0.0, 0.0), 4.2, Color(0.28, 0.68, 0.60))


func configure(cfg: Dictionary, p_theme: String = "kitchen") -> void:
	theme_name = p_theme
	var a_arr: Array = cfg.get("from", [220, 600])
	var b_arr: Array = cfg.get("to", [500, 600])
	point_a = Vector2(float(a_arr[0]), float(a_arr[1]))
	point_b = Vector2(float(b_arr[0]), float(b_arr[1]))
	length = float(cfg.get("length", 144.0))
	thickness = float(cfg.get("thickness", 20.0))
	cycle_speed = float(cfg.get("speed", 0.30))
	phase = float(cfg.get("phase", 0.0))

	_body = AnimatableBody2D.new()
	_body.sync_to_physics = true
	_body.collision_layer = 1
	_body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.25
	mat.bounce = 0.06
	_body.physics_material_override = mat

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	col.shape = rect
	_body.add_child(col)

	# Carry zone gently imparts tray motion so low-friction Water & Ice ride effortlessly!
	_carry_area = Area2D.new()
	_carry_area.collision_layer = 16
	_carry_area.collision_mask = 8
	var c_col := CollisionShape2D.new()
	var c_rect := RectangleShape2D.new()
	c_rect.size = Vector2(length + 6.0, thickness + 28.0)
	c_col.shape = c_rect
	c_col.position = Vector2(0.0, -14.0)
	_carry_area.add_child(c_col)
	_body.add_child(_carry_area)
	_carry_area.body_entered.connect(func(b: Node):
		if b is Droplet and not _riders.has(b):
			_riders.append(b as Droplet)
	)
	_carry_area.body_exited.connect(func(b: Node):
		if b is Droplet:
			_riders.erase(b as Droplet)
	)

	_visual = TrayVisual.new()
	_visual.length = length
	_visual.thickness = thickness
	_visual.theme_name = theme_name
	_body.add_child(_visual)

	add_child(_body)
	_update_position(0.0)
	_prev_pos = _body.position
	queue_redraw()


func get_platform_position() -> Vector2:
	return _body.global_position if _body != null else point_a


func get_platform_velocity() -> Vector2:
	return _velocity


func _physics_process(delta: float) -> void:
	_time += delta
	_update_position(_time)
	if delta > 0.0:
		_velocity = (_body.position - _prev_pos) / delta
	_prev_pos = _body.position

	for d in _riders:
		if is_instance_valid(d) and d.active and not d.soaked and not d.is_steam():
			# Smoothly carry droplet along with the moving kitchen tray
			d.linear_velocity.x = lerpf(d.linear_velocity.x, _velocity.x * 1.05, clampf(delta * 16.0, 0.0, 1.0))


func _update_position(t: float) -> void:
	if _body == null:
		return
	var u := 0.5 - 0.5 * cos((t * cycle_speed + phase) * TAU)
	_body.position = point_a.lerp(point_b, u)


func _draw() -> void:
	var diff := point_b - point_a
	var dist := diff.length()
	if dist > 4.0:
		var dir := diff / dist
		draw_line(point_a, point_b, Color(0.42, 0.34, 0.26, 0.26), 5.0, true)
		var d := 8.0
		while d < dist - 8.0:
			var p1 := point_a + dir * d
			var p2 := point_a + dir * minf(d + 10.0, dist - 8.0)
			draw_line(p1, p2, Color(0.86, 0.72, 0.44, 0.65), 2.2, true)
			d += 20.0
	draw_circle(point_a, 6.0, Color(0.68, 0.50, 0.30, 0.75))
	draw_circle(point_b, 6.0, Color(0.68, 0.50, 0.30, 0.75))
