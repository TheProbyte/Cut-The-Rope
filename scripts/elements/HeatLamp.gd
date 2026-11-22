class_name HeatLamp
extends Area2D

const HEAT_SHIMMER_SHADER := preload("res://assets/shaders/heat_shimmer.gdshader")

var zone_size: Vector2 = Vector2(120.0, 180.0)
var _time: float = 0.0
var _motes: Array[Vector2] = []


func configure(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("pos", [360, 400])
	var size_arr: Array = cfg.get("size", [120, 180])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	zone_size = Vector2(float(size_arr[0]), float(size_arr[1]))

	collision_layer = 16
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = zone_size
	shape.shape = rect
	add_child(shape)

	var shimmer := ColorRect.new()
	shimmer.position = -zone_size * 0.5
	shimmer.size = zone_size
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = HEAT_SHIMMER_SHADER
	mat.set_shader_parameter("glow_color", Color(1.0, 0.62, 0.20, 0.28))
	shimmer.material = mat
	add_child(shimmer)

	for i in range(8):
		_motes.append(Vector2(randf_range(-0.4, 0.4), randf_range(-0.45, 0.45)))

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Droplet:
		(body as Droplet).enter_heat_zone()


func _on_body_exited(body: Node) -> void:
	if body is Droplet:
		(body as Droplet).exit_heat_zone()


func _process(delta: float) -> void:
	_time += delta
	for i in range(_motes.size()):
		var m := _motes[i]
		m.y -= delta * 0.28
		if m.y < -0.46:
			m.y = 0.46
			m.x = randf_range(-0.4, 0.4)
		_motes[i] = m
	queue_redraw()


func _draw() -> void:
	var half := zone_size * 0.5
	var pulse := 0.85 + sin(_time * 3.5) * 0.15

	# Soft warm glow beam trapezoid
	var top_w := minf(half.x * 0.58, 42.0)
	var beam := PackedVector2Array([
		Vector2(-top_w, -half.y),
		Vector2(top_w, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	draw_colored_polygon(beam, Color(1.0, 0.62, 0.20, 0.20 * pulse))
	draw_rect(Rect2(-half, zone_size), Color(1.0, 0.56, 0.18, 0.10 * pulse))
	draw_rect(Rect2(-half, zone_size), Color(0.95, 0.54, 0.18, 0.40), false, 2.0)

	# Rising heat wave motes
	for m in _motes:
		var mp := Vector2(m.x * zone_size.x + sin(_time * 4.0 + m.y * 8.0) * 5.0, m.y * zone_size.y)
		draw_circle(mp, 3.2, Color(1.0, 0.78, 0.35, 0.55))

	# Brass hanging lamp fixture at top edge
	var lamp_y := -half.y
	var hood := PackedVector2Array([
		Vector2(-top_w * 0.55, lamp_y - 16.0),
		Vector2(top_w * 0.55, lamp_y - 16.0),
		Vector2(top_w + 6.0, lamp_y + 4.0),
		Vector2(-top_w - 6.0, lamp_y + 4.0),
	])
	draw_colored_polygon(hood, Color(0.76, 0.54, 0.24))
	draw_polyline(hood, Color(0.45, 0.30, 0.12), 2.0, true)
	# Glowing bulb underneath hood
	draw_circle(Vector2(0.0, lamp_y + 4.0), 10.0, Color(1.0, 0.90, 0.52, 0.95))
	draw_circle(Vector2(0.0, lamp_y + 4.0), 16.0, Color(1.0, 0.72, 0.24, 0.35 * pulse))
