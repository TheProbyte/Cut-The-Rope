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
		var rad := minf(thickness * 0.45, 9.0)
		Art.draw_rrect(self, Rect2(rect.position + Vector2(3, 7), rect.size), rad, Color(0.12, 0.16, 0.12, 0.2))
		var top := Color(0.95, 0.76, 0.50) if theme_name == "kitchen" else Color(0.82, 0.64, 0.42)
		var bot := Color(0.76, 0.52, 0.30) if theme_name == "kitchen" else Color(0.60, 0.44, 0.26)
		Art.draw_rrect_grad(self, rect, rad, top, bot)
		Art.draw_rrect(self, Rect2(rect.position + Vector2(4, 2), Vector2(length - 8, thickness * 0.3)), rad * 0.6, Color(1, 0.94, 0.78, 0.5))
		# tray lip handles
		for sx: float in [-1.0, 1.0]:
			var hx := sx * (half.x - 14.0)
			Art.draw_ellipse(self, Vector2(hx, 1.0), 7.0, 3.0, Color(0.46, 0.28, 0.14, 0.55), 12)
		Art.draw_rrect_outline(self, rect, rad, Color(0.44, 0.26, 0.12), 2.4)
		# little wheels
		for sx: float in [-1.0, 1.0]:
			var wp := Vector2(sx * (half.x - 22.0), half.y + 3.0)
			draw_circle(wp, 5.0, Color(0.36, 0.36, 0.40))
			draw_circle(wp, 2.0, Color(0.80, 0.80, 0.84))


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
		var off := Vector2(0, thickness * 0.5 + 9.0)
		draw_line(point_a + off, point_b + off, Color(0.30, 0.26, 0.22, 0.22), 8.0, true)
		draw_line(point_a + off, point_b + off, Color(0.62, 0.52, 0.40, 0.45), 4.0, true)
		var d := 10.0
		while d < dist - 10.0:
			draw_circle(point_a + off + dir * d, 1.8, Color(1.0, 0.94, 0.80, 0.7))
			d += 18.0
		for p in [point_a + off, point_b + off]:
			draw_circle(p, 7.0, Color(0.46, 0.36, 0.26, 0.85))
			draw_circle(p, 3.0, Color(0.92, 0.82, 0.62))
