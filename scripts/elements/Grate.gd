class_name Grate
extends StaticBody2D

var length: float = 120.0
var thickness: float = 16.0


func configure(cfg: Dictionary) -> void:
	thickness = float(cfg.get("thickness", 16.0))
	if cfg.has("from") and cfg.has("to"):
		var a := Vector2(float(cfg["from"][0]), float(cfg["from"][1]))
		var b := Vector2(float(cfg["to"][0]), float(cfg["to"][1]))
		position = (a + b) * 0.5
		var diff := b - a
		length = maxf(24.0, diff.length())
		rotation = diff.angle()
	else:
		var pos_arr: Array = cfg.get("pos", [360, 640])
		position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		length = float(cfg.get("length", 120.0))
		rotation = deg_to_rad(float(cfg.get("rotation", 0.0)))

	# Layer 2: blocks Ice only; Water and Steam pass cleanly through!
	collision_layer = 2
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.02
	mat.bounce = 0.1
	physics_material_override = mat

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	shape.shape = rect
	add_child(shape)
	queue_redraw()


func _draw() -> void:
	var half := Vector2(length * 0.5, thickness * 0.5)
	var rect := Rect2(-half, Vector2(length, thickness))
	var sh := rect
	sh.position += Vector2(3.0, 6.0).rotated(-rotation)
	Art.draw_rrect(self, sh, 5.0, Color(0.10, 0.16, 0.12, 0.12))
	# see-through slot backing
	Art.draw_rrect(self, rect, 5.0, Color(0.20, 0.28, 0.27, 0.22))
	# bars
	var spacing := 13.0
	var x := -half.x + 9.0
	while x <= half.x - 8.0:
		Art.draw_rrect(self, Rect2(Vector2(x - 2.4, -half.y + 2.0), Vector2(4.8, thickness - 4.0)), 2.4, Color(0.42, 0.52, 0.54))
		draw_line(Vector2(x - 1.0, -half.y + 3.0), Vector2(x - 1.0, half.y - 3.0), Color(0.82, 0.90, 0.92, 0.7), 1.2)
		x += spacing
	# rails
	for ry: float in [-half.y + 2.0, half.y - 2.0]:
		draw_line(Vector2(-half.x + 4, ry), Vector2(half.x - 4, ry), Color(0.30, 0.38, 0.40), 3.6, true)
	draw_line(Vector2(-half.x + 4, -half.y + 1.0), Vector2(half.x - 4, -half.y + 1.0), Color(0.80, 0.88, 0.90, 0.6), 1.2)
	# end brackets
	for sx: float in [-1.0, 1.0]:
		var br := Rect2(Vector2(sx * half.x - (8.0 if sx > 0 else 0.0), -half.y - 2.0), Vector2(8.0, thickness + 4.0))
		Art.draw_rrect(self, br, 3.0, Color(0.32, 0.40, 0.42))
		draw_circle(br.get_center(), 2.0, Color(0.78, 0.86, 0.88))
