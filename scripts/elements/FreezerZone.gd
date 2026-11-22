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
	var pulse := 0.88 + sin(_time * 2.6) * 0.12
	draw_polygon(Art.rrect_points(rect, 14.0), Art.vgrad_colors(Art.rrect_points(rect, 14.0),
		Color(0.70, 0.93, 1.0, 0.34 * pulse), Color(0.50, 0.82, 1.0, 0.16 * pulse)))
	Art.draw_rrect_outline(self, rect, 14.0, Color(0.40, 0.78, 0.98, 0.75), 2.4)
	# frosted top edge with icicles
	Art.draw_rrect(self, Rect2(-half.x + 2.0, -half.y, zone_size.x - 4.0, 9.0), 6.0, Color(0.94, 0.99, 1.0, 0.9))
	var x := -half.x + 12.0
	var k := 0
	while x < half.x - 10.0:
		var ln := 7.0 + float((k * 3) % 4) * 3.0 + sin(_time * 1.5 + float(k)) * 1.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, -half.y + 7), Vector2(x + 4, -half.y + 7), Vector2(x, -half.y + 7 + ln)]), Color(0.90, 0.98, 1.0, 0.92))
		x += 17.0
		k += 1
	# corner frost
	for sx: float in [-1.0, 1.0]:
		Art.draw_ellipse(self, Vector2(sx * (half.x - 10.0), half.y - 6.0), 12.0, 5.0, Color(0.94, 0.99, 1.0, 0.8), 14)
	# drifting snowflakes
	for f in _flakes:
		var fp := Vector2(f.x * zone_size.x + sin(_time * 2.2 + f.y * 9.0) * 5.0, f.y * zone_size.y)
		var r := 5.0
		for kk in range(3):
			var a := float(kk) * PI / 3.0 + _time * 0.7
			var d := Vector2.from_angle(a) * r
			draw_line(fp - d, fp + d, Color(1.0, 1.0, 1.0, 0.9), 1.6, true)
		draw_circle(fp, 1.4, Color(1, 1, 1, 0.95))
	# snowflake badge
	var badge := Vector2(0, -half.y + 22.0)
	draw_circle(badge, 12.0, Color(0.36, 0.72, 0.94, 0.85))
	for kk in range(3):
		var d := Vector2.from_angle(float(kk) * PI / 3.0 + PI * 0.5) * 7.0
		draw_line(badge - d, badge + d, Color.WHITE, 2.0, true)
