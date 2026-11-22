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
	# Subtle translucent slot shadow so players see gaps between bars
	draw_rect(Rect2(-half, Vector2(length, thickness)), Color(0.22, 0.30, 0.28, 0.16))

	# Outer iron/bronze rails (top and bottom thin rims)
	var rail_col := Color(0.36, 0.44, 0.46)
	draw_line(Vector2(-half.x, -half.y + 2.0), Vector2(half.x, -half.y + 2.0), rail_col, 3.0, true)
	draw_line(Vector2(-half.x, half.y - 2.0), Vector2(half.x, half.y - 2.0), rail_col, 3.0, true)

	# Vertical grate bars with clear open slots
	var spacing := 14.0
	var x := -half.x + 7.0
	while x <= half.x - 5.0:
		draw_line(Vector2(x, -half.y + 1.0), Vector2(x, half.y - 1.0), Color(0.46, 0.56, 0.58), 4.0, true)
		draw_line(Vector2(x - 1.0, -half.y + 1.0), Vector2(x - 1.0, half.y - 1.0), Color(0.75, 0.84, 0.86, 0.65), 1.2, true)
		x += spacing

	# End brackets
	draw_rect(Rect2(-half.x, -half.y, 6.0, thickness), Color(0.32, 0.40, 0.42))
	draw_rect(Rect2(half.x - 6.0, -half.y, 6.0, thickness), Color(0.32, 0.40, 0.42))
