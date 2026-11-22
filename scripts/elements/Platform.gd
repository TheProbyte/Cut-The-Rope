class_name Platform
extends StaticBody2D

var length: float = 200.0
var thickness: float = 22.0
var style: String = "wood"


func configure(cfg: Dictionary) -> void:
	thickness = float(cfg.get("thickness", 22.0))
	style = String(cfg.get("style", "wood"))
	if cfg.has("from") and cfg.has("to"):
		var a := Vector2(float(cfg["from"][0]), float(cfg["from"][1]))
		var b := Vector2(float(cfg["to"][0]), float(cfg["to"][1]))
		position = (a + b) * 0.5
		var diff := b - a
		length = maxf(16.0, diff.length())
		rotation = diff.angle()
	else:
		var pos_arr: Array = cfg.get("pos", [360, 640])
		var size_arr: Array = cfg.get("size", [200, 22])
		position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		length = float(size_arr[0])
		thickness = float(size_arr[1])
		rotation = deg_to_rad(float(cfg.get("rotation", 0.0)))

	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.04
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
	var body_rect := Rect2(-half, Vector2(length, thickness))
	var shadow_rect := Rect2(-half + Vector2(3.0, 5.0), Vector2(length, thickness))

	draw_rect(shadow_rect, Color(0.10, 0.18, 0.12, 0.18))

	match style:
		"roof":
			# Greenhouse framed sunlit glass roof beam
			draw_rect(body_rect, Color(0.76, 0.90, 0.87, 0.85))
			draw_rect(Rect2(-half, Vector2(length, thickness * 0.35)), Color(1.0, 1.0, 1.0, 0.45))
			draw_rect(body_rect, Color(0.32, 0.52, 0.46), false, 2.5)
			var step := 48.0
			var x := -half.x + step
			while x < half.x - 10.0:
				draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(0.38, 0.58, 0.52, 0.7), 2.0)
				x += step
		"stone":
			# Mossy slate greenhouse wall
			draw_rect(body_rect, Color(0.56, 0.60, 0.58))
			draw_rect(Rect2(-half, Vector2(length, thickness * 0.3)), Color(0.70, 0.75, 0.72, 0.5))
			draw_rect(body_rect, Color(0.35, 0.40, 0.37), false, 2.2)
		_:
			# Cozy warm cedar wood plank
			draw_rect(body_rect, Color(0.68, 0.48, 0.30))
			draw_rect(Rect2(-half, Vector2(length, thickness * 0.32)), Color(0.80, 0.62, 0.42, 0.65))
			draw_rect(Rect2(Vector2(-half.x, half.y - thickness * 0.24), Vector2(length, thickness * 0.24)), Color(0.50, 0.33, 0.19, 0.55))
			# Subtle wood grain lines
			var gx := -half.x + 28.0
			while gx < half.x - 20.0:
				draw_line(Vector2(gx, -half.y * 0.2), Vector2(gx + 18.0, -half.y * 0.2), Color(0.48, 0.31, 0.18, 0.35), 1.5)
				gx += 46.0
			draw_rect(body_rect, Color(0.42, 0.27, 0.15), false, 2.2)
			# Brass rivets at ends
			if length >= 50.0:
				draw_circle(Vector2(-half.x + 10.0, 0.0), 3.0, Color(0.86, 0.72, 0.42))
				draw_circle(Vector2(half.x - 10.0, 0.0), 3.0, Color(0.86, 0.72, 0.42))
