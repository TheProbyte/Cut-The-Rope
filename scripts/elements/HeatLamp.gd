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
	var pulse := 0.85 + sin(_time * 3.4) * 0.15
	var top_w := minf(half.x * 0.55, 40.0)
	var beam := PackedVector2Array([Vector2(-top_w, -half.y + 4), Vector2(top_w, -half.y + 4), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	draw_polygon(beam, PackedColorArray([
		Color(1.0, 0.72, 0.30, 0.42 * pulse), Color(1.0, 0.72, 0.30, 0.42 * pulse),
		Color(1.0, 0.56, 0.20, 0.06), Color(1.0, 0.56, 0.20, 0.06)]))
	# zone bounds (dashed warm outline)
	var rect := Rect2(-half, zone_size)
	var pts := Art.closed(Art.rrect_points(rect, 12.0))
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], Color(0.98, 0.58, 0.22, 0.55), 2.2, true)
	# rising heat squiggles
	for i in range(3):
		var hx := lerpf(-half.x * 0.5, half.x * 0.5, float(i) / 2.0)
		var t := fmod(_time * 0.5 + float(i) * 0.33, 1.0)
		var base_y := lerpf(half.y - 10.0, -half.y + 40.0, t)
		var sq := PackedVector2Array()
		for k in range(6):
			sq.append(Vector2(hx + sin(_time * 6.0 + float(k) * 1.2 + float(i)) * 4.0, base_y - float(k) * 7.0))
		draw_polyline(sq, Color(1.0, 0.60, 0.22, 0.55 * sin(t * PI)), 2.4, true)
	for m in _motes:
		var mp := Vector2(m.x * zone_size.x + sin(_time * 4.0 + m.y * 8.0) * 5.0, m.y * zone_size.y)
		Art.draw_glow(self, mp, 8.0, Color(1.0, 0.75, 0.3, 0.7))
	# cord + brass hood + bulb
	var lamp_y := -half.y
	draw_line(Vector2(0, lamp_y - 46.0), Vector2(0, lamp_y - 14.0), Color(0.30, 0.24, 0.18), 3.0, true)
	Art.draw_glow(self, Vector2(0, lamp_y + 6.0), 56.0, Color(1.0, 0.74, 0.30, 0.65 * pulse))
	var hood := PackedVector2Array()
	for i in range(13):
		var a := PI + PI * float(i) / 12.0
		hood.append(Vector2(cos(a) * (top_w + 8.0), lamp_y + 4.0 + sin(a) * 20.0))
	draw_polygon(hood, Art.vgrad_colors(hood, Color(0.92, 0.70, 0.36), Color(0.66, 0.44, 0.18)))
	draw_polyline(Art.closed(hood), Color(0.44, 0.28, 0.10), 2.2, true)
	draw_rect(Rect2(-6, lamp_y - 20.0, 12, 6), Color(0.44, 0.28, 0.10))
	draw_circle(Vector2(0, lamp_y + 6.0), 10.0, Color(1.0, 0.94, 0.66))
	draw_circle(Vector2(-3, lamp_y + 3.0), 3.0, Color(1, 1, 1, 0.9))
