class_name FreezerZone
extends Area2D

var zone_size: Vector2 = Vector2(130.0, 140.0)
var _time: float = 0.0
var _flakes: Array[Vector2] = []


func configure(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("pos", [360, 400])
	var size_arr: Array = cfg.get("size", [130, 140])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	zone_size = Vector2(float(size_arr[0]), float(size_arr[1]))

	collision_layer = 16
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = zone_size
	shape.shape = rect
	add_child(shape)

	for i in range(9):
		_flakes.append(Vector2(randf_range(-0.42, 0.42), randf_range(-0.44, 0.44)))

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Droplet:
		(body as Droplet).enter_freezer_zone()


func _on_body_exited(body: Node) -> void:
	if body is Droplet:
		(body as Droplet).exit_freezer_zone()


func _process(delta: float) -> void:
	_time += delta
	for i in range(_flakes.size()):
		var f := _flakes[i]
		f.y += delta * 0.22
		if f.y > 0.45:
			f.y = -0.45
			f.x = randf_range(-0.42, 0.42)
		_flakes[i] = f
	queue_redraw()


func _draw() -> void:
	var half := zone_size * 0.5
	var rect := Rect2(-half, zone_size)
	var pulse := 0.88 + sin(_time * 2.8) * 0.12

	# Frosty ice-blue zone fill
	draw_rect(rect, Color(0.55, 0.88, 1.0, 0.20 * pulse))
	draw_rect(rect, Color(0.45, 0.82, 0.98, 0.65), false, 2.2)

	# Frosty corner brackets
	var b := 16.0
	var bcol := Color(0.86, 0.98, 1.0, 0.95)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * half.x, sy * half.y)
			draw_line(corner, corner + Vector2(-sx * b, 0.0), bcol, 3.0, true)
			draw_line(corner, corner + Vector2(0.0, -sy * b), bcol, 3.0, true)

	# Floating crisp mini-snowflakes
	for f in _flakes:
		var fp := Vector2(f.x * zone_size.x + sin(_time * 2.5 + f.y * 9.0) * 4.0, f.y * zone_size.y)
		var r := 4.5
		for k in range(3):
			var a := float(k) * PI / 3.0 + _time * 0.6
			var d := Vector2.from_angle(a) * r
			draw_line(fp - d, fp + d, Color(0.92, 0.99, 1.0, 0.8), 1.5, true)
